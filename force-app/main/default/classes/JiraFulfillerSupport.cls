/**
 * Hardened multi-project runtime for the IT Fulfiller (Jira) agent.
 *
 * Responsibilities:
 *  - Resolve Agentforce-active Jira_Connector_Profile__c records (multi-project),
 *    with a single-project fallback to the legacy Jira_Demo_Setting__mdt config.
 *  - Validate issue keys against the allowed project scope.
 *  - Build safe, structured JQL (no LLM-authored raw JQL) and run paginated,
 *    capped searches per Named Credential.
 *  - Resolve administrator-allowlisted updatable fields and apply typed transforms.
 *  - Manage short-lived, single-use confirmation tokens for the two-phase
 *    field-update contract, persisted in Jira_Integration_Transaction__c.
 *  - Reuse the sanitized error taxonomy and grounded summaries from the direct stack.
 *
 * Configuration objects (profiles/mappings/fields) contain administrator-only
 * integration metadata (no end-user data) and are read in system context; the
 * audit ledger is read/written WITH USER_MODE.
 */
public with sharing class JiraFulfillerSupport {
    public static final String PERMISSION_SEARCH = 'Jira_Fulfiller_Search';
    public static final String PERMISSION_READ = 'Jira_Fulfiller_Read';
    public static final String PERMISSION_CREATE = 'Jira_Fulfiller_Create';
    public static final String PERMISSION_FIELD_UPDATE = 'Jira_Fulfiller_Field_Update';
    public static final String PERMISSION_COMMENT = 'Jira_Fulfiller_Comment';
    public static final String PERMISSION_ASSIGN = 'Jira_Fulfiller_Assign';
    public static final String PERMISSION_TRANSITION = 'Jira_Fulfiller_Transition';

    public static final String CONTENT_TRUST = 'UNTRUSTED_EXTERNAL_DATA';
    private static final Integer MAX_PAGE_SIZE = 50;
    private static final Integer DEFAULT_PAGE_SIZE = 15;
    private static final Integer TOKEN_TTL_MINUTES = 15;

    @TestVisible
    private static List<Jira_Connector_Profile__c> profileOverrides;

    @TestVisible
    private static List<Jira_Field_Mapping__c> mappingOverrides;

    // Test-only: bypass token persistence so apply-path tests can make a callout
    // without pre-inserting a token record (which would trip uncommitted-work rules).
    @TestVisible
    private static Map<String, Map<String, Object>> pendingTokenDetailOverrides;

    public class IssueRef {
        public Jira_Connector_Profile__c profile;
        public String normalizedKey;
    }

    public class SearchFilters {
        public List<String> projectKeys = new List<String>();
        public String statusCategory;
        public List<String> priorityNames = new List<String>();
        public String assigneeFilter;
        public String reporterFilter;
        public String textQuery;
        public Integer updatedWithinDays;
        public Integer startAt = 0;
        public Integer maxResults = DEFAULT_PAGE_SIZE;
        public String nextPageToken;
    }

    public class SearchResult {
        public Integer totalCount = 0;
        public Integer returnedCount = 0;
        public Integer startAt = 0;
        public Integer nextStartAt = 0;
        public Boolean hasMore = false;
        public String nextPageToken = '';
        public String issuesSummary = '';
        public String firstIssueKey = '';
    }

    public class PreparedUpdate {
        public Map<String, Object> fields = new Map<String, Object>();
        public List<String> previewLines = new List<String>();
        public String connectorKey;
    }

    // ---------------------------------------------------------------------
    // Permissions
    // ---------------------------------------------------------------------
    public static void requirePermission(String permissionName) {
        JiraDirectActionSupport.requirePermission(permissionName);
    }

    // ---------------------------------------------------------------------
    // Profile / scope resolution
    // ---------------------------------------------------------------------
    public static List<Jira_Connector_Profile__c> activeProfiles() {
        if (profileOverrides != null) {
            return profileOverrides;
        }
        List<Jira_Connector_Profile__c> profiles = [
            SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Route_Key__c,
                Is_Active_For_Agentforce__c
            FROM Jira_Connector_Profile__c
            WHERE Active__c = true AND Is_Active_For_Agentforce__c = true
            WITH USER_MODE
            ORDER BY Name ASC
        ];
        if (!profiles.isEmpty()) {
            return profiles;
        }
        return new List<Jira_Connector_Profile__c>{ legacyProfile() };
    }

    public static Set<String> allowedProjectKeys() {
        Set<String> keys = new Set<String>();
        for (Jira_Connector_Profile__c profile : activeProfiles()) {
            if (!String.isBlank(profile.Project_Key__c)) {
                keys.add(profile.Project_Key__c.trim().toUpperCase());
            }
        }
        return keys;
    }

    public static Jira_Connector_Profile__c resolveProfileForRoute(String connectorKey, String routeKey) {
        List<Jira_Connector_Profile__c> profiles = activeProfiles();
        if (!String.isBlank(connectorKey)) {
            for (Jira_Connector_Profile__c profile : profiles) {
                if (equalsIgnoreCase(profile.Connector_Key__c, connectorKey)) {
                    return profile;
                }
            }
            throw validation('No active Jira connector profile matches connector key "' + connectorKey + '".');
        }
        if (!String.isBlank(routeKey)) {
            for (Jira_Connector_Profile__c profile : profiles) {
                if (equalsIgnoreCase(profile.Route_Key__c, routeKey)) {
                    return profile;
                }
            }
            throw validation('No active Jira connector profile matches route key "' + routeKey + '".');
        }
        if (profiles.size() == 1) {
            return profiles[0];
        }
        throw validation(
            'Multiple Jira projects are configured. Specify a connector key or route key. Available: ' +
            describeRoutes(profiles) + '.'
        );
    }

    public static String describeRoutes(List<Jira_Connector_Profile__c> profiles) {
        List<String> parts = new List<String>();
        for (Jira_Connector_Profile__c profile : profiles) {
            String routeLabel = String.isBlank(profile.Route_Key__c) ? profile.Connector_Key__c : profile.Route_Key__c;
            parts.add(
                JiraDirectActionSupport.sanitizeExternalText(routeLabel, 60) +
                ' (' + JiraDirectActionSupport.sanitizeExternalText(profile.Project_Key__c, 20) + ')'
            );
        }
        return String.join(parts, ', ');
    }

    public static IssueRef validateAndResolveIssueKey(String issueKey) {
        if (String.isBlank(issueKey)) {
            throw validation('A Jira issue key is required.');
        }
        String normalized = issueKey.trim().toUpperCase();
        if (!Pattern.matches('^[A-Z][A-Z0-9]*-[1-9][0-9]*$', normalized)) {
            throw validation('Jira issue key must use the format PROJECT-123.');
        }
        String projectPrefix = normalized.substring(0, normalized.indexOf('-'));
        for (Jira_Connector_Profile__c profile : activeProfiles()) {
            if (equalsIgnoreCase(profile.Project_Key__c, projectPrefix)) {
                IssueRef ref = new IssueRef();
                ref.profile = profile;
                ref.normalizedKey = normalized;
                return ref;
            }
        }
        throw scope(
            'Jira issue ' + normalized + ' is outside the projects this agent is allowed to work with (' +
            String.join(new List<String>(allowedProjectKeys()), ', ') + ').'
        );
    }

    // ---------------------------------------------------------------------
    // Structured search (safe JQL only)
    // ---------------------------------------------------------------------
    public static SearchResult search(SearchFilters filters) {
        Set<String> allowedKeys = allowedProjectKeys();
        Set<String> targetKeys = new Set<String>();
        if (filters.projectKeys != null && !filters.projectKeys.isEmpty()) {
            for (String requested : filters.projectKeys) {
                if (String.isBlank(requested)) {
                    continue;
                }
                String candidate = requested.trim().toUpperCase();
                if (!allowedKeys.contains(candidate)) {
                    throw scope('Project "' + candidate + '" is not in the allowed Jira project scope.');
                }
                targetKeys.add(candidate);
            }
        }
        if (targetKeys.isEmpty()) {
            targetKeys.addAll(allowedKeys);
        }
        if (targetKeys.isEmpty()) {
            throw configuration('No Agentforce-active Jira projects are configured.');
        }

        Integer pageSize = normalizePageSize(filters.maxResults);
        Integer startAt = (filters.startAt == null || filters.startAt < 0) ? 0 : filters.startAt;

        // Group target projects by Named Credential (Jira site) so one JQL call
        // can span multiple projects that share a site.
        Map<String, List<String>> keysByCredential = new Map<String, List<String>>();
        Map<String, Jira_Connector_Profile__c> profileByCredential = new Map<String, Jira_Connector_Profile__c>();
        for (Jira_Connector_Profile__c profile : activeProfiles()) {
            String key = String.isBlank(profile.Project_Key__c) ? '' : profile.Project_Key__c.trim().toUpperCase();
            if (!targetKeys.contains(key)) {
                continue;
            }
            String credential = profile.Named_Credential_Api_Name__c;
            if (!keysByCredential.containsKey(credential)) {
                keysByCredential.put(credential, new List<String>());
                profileByCredential.put(credential, profile);
            }
            keysByCredential.get(credential).add(key);
        }

        SearchResult result = new SearchResult();
        result.startAt = startAt;
        List<String> renderedRows = new List<String>();
        Boolean singleSite = keysByCredential.size() == 1;

        for (String credential : keysByCredential.keySet()) {
            String jql = buildJql(keysByCredential.get(credential), filters);
            Integer siteStart = singleSite ? startAt : 0;
            Map<String, String> searchParams = new Map<String, String>{
                'jql' => jql,
                'maxResults' => String.valueOf(pageSize),
                'fields' => 'summary,status,priority,assignee,reporter,updated'
            };
            if (singleSite && !String.isBlank(filters.nextPageToken)) {
                searchParams.put('nextPageToken', filters.nextPageToken.trim());
            }
            Map<String, Object> response = JiraIntegrationSupport.sendRequestVia(
                credential,
                'GET',
                '/rest/api/3/search/jql',
                searchParams,
                null
            );
            List<Object> issues = JiraIntegrationSupport.listValue(response.get('issues'));
            Integer minimumTotal = siteStart + issues.size();
            Integer siteTotal = response.containsKey('total')
                ? toInteger(response.get('total'))
                : getApproximateCount(credential, jql, minimumTotal);
            siteTotal = siteTotal < minimumTotal ? minimumTotal : siteTotal;
            result.totalCount += siteTotal;
            for (Object issueEntry : issues) {
                Map<String, Object> issueMap = JiraIntegrationSupport.mapValue(issueEntry);
                if (String.isBlank(result.firstIssueKey)) {
                    result.firstIssueKey = JiraIntegrationSupport.stringValue(issueMap.get('key'));
                }
                renderedRows.add(renderSearchRow(issueMap));
            }
            if (singleSite) {
                result.nextPageToken = JiraIntegrationSupport.stringValue(response.get('nextPageToken'));
                result.hasMore = !String.isBlank(result.nextPageToken);
                result.nextStartAt = siteStart + issues.size();
            } else if (!String.isBlank(JiraIntegrationSupport.stringValue(response.get('nextPageToken')))) {
                result.hasMore = true;
            }
        }

        result.returnedCount = renderedRows.size();
        result.issuesSummary = renderedRows.isEmpty()
            ? 'No Jira issues matched the requested filters.'
            : String.join(renderedRows, '\n\n');
        if (!singleSite) {
            result.nextStartAt = startAt;
        }
        return result;
    }

    private static Integer getApproximateCount(String credential, String jql, Integer minimumTotal) {
        try {
            Map<String, Object> countResponse = JiraIntegrationSupport.sendRequestVia(
                credential,
                'POST',
                '/rest/api/3/search/approximate-count',
                null,
                new Map<String, Object>{ 'jql' => jql }
            );
            return toInteger(countResponse.get('count'));
        } catch (JiraIntegrationSupport.JiraIntegrationException exceptionValue) {
            return minimumTotal;
        }
    }

    private static String buildJql(List<String> projectKeys, SearchFilters filters) {
        List<String> clauses = new List<String>();
        List<String> quotedKeys = new List<String>();
        for (String key : projectKeys) {
            quotedKeys.add('"' + JiraIntegrationSupport.escapeJql(key) + '"');
        }
        clauses.add('project in (' + String.join(quotedKeys, ',') + ')');

        String statusCategory = String.isBlank(filters.statusCategory) ? 'open' : filters.statusCategory.trim().toLowerCase();
        if (statusCategory == 'open') {
            clauses.add('statusCategory != Done');
        } else if (statusCategory == 'done' || statusCategory == 'closed') {
            clauses.add('statusCategory = Done');
        }

        if (filters.priorityNames != null && !filters.priorityNames.isEmpty()) {
            List<String> quotedPriorities = new List<String>();
            for (String priority : filters.priorityNames) {
                if (!String.isBlank(priority)) {
                    quotedPriorities.add('"' + JiraIntegrationSupport.escapeJql(priority.trim()) + '"');
                }
            }
            if (!quotedPriorities.isEmpty()) {
                clauses.add('priority in (' + String.join(quotedPriorities, ',') + ')');
            }
        }

        if (!String.isBlank(filters.assigneeFilter)) {
            String assignee = filters.assigneeFilter.trim();
            if (assignee.equalsIgnoreCase('unassigned') || assignee.equalsIgnoreCase('none')) {
                clauses.add('assignee is EMPTY');
            } else if (assignee.equalsIgnoreCase('me')) {
                clauses.add('assignee = currentUser()');
            } else {
                clauses.add('assignee = "' + JiraIntegrationSupport.escapeJql(assignee) + '"');
            }
        }

        if (!String.isBlank(filters.reporterFilter)) {
            clauses.add('reporter = "' + JiraIntegrationSupport.escapeJql(filters.reporterFilter.trim()) + '"');
        }

        if (!String.isBlank(filters.textQuery)) {
            clauses.add('summary ~ "' + JiraIntegrationSupport.escapeJql(filters.textQuery.trim()) + '"');
        }

        if (filters.updatedWithinDays != null && filters.updatedWithinDays > 0) {
            clauses.add('updated >= -' + filters.updatedWithinDays + 'd');
        }

        return String.join(clauses, ' AND ') + ' ORDER BY updated DESC';
    }

    private static String renderSearchRow(Map<String, Object> issueMap) {
        Map<String, Object> fields = JiraIntegrationSupport.mapValue(issueMap.get('fields'));
        String key = JiraIntegrationSupport.stringValue(issueMap.get('key'));
        String summary = JiraDirectActionSupport.sanitizeExternalText(JiraIntegrationSupport.stringValue(fields.get('summary')), 140);
        String status = JiraDirectActionSupport.sanitizeExternalText(
            JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(fields.get('status')).get('name')), 40
        );
        String priority = JiraDirectActionSupport.sanitizeExternalText(
            JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(fields.get('priority')).get('name')), 40
        );
        String assignee = JiraDirectActionSupport.sanitizeExternalText(
            JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(fields.get('assignee')).get('displayName')), 80
        );
        if (String.isBlank(assignee)) {
            assignee = 'Unassigned';
        }
        String titleLine = '• ' + key;
        if (!String.isBlank(summary)) {
            titleLine += ' — ' + summary;
        }
        List<String> metadata = new List<String>();
        if (!String.isBlank(status)) {
            metadata.add('Status: ' + status);
        }
        if (!String.isBlank(priority)) {
            metadata.add('Priority: ' + priority);
        }
        metadata.add('Assignee: ' + assignee);
        return titleLine + '\n  ' + String.join(metadata, ' · ');
    }

    // ---------------------------------------------------------------------
    // Issue detail
    // ---------------------------------------------------------------------
    public static Map<String, Object> fetchIssue(IssueRef ref, Set<String> extraFieldKeys) {
        Set<String> fieldKeys = new Set<String>{
            'project', 'summary', 'description', 'status', 'reporter', 'assignee',
            'updated', 'comment', 'priority', 'resolution'
        };
        if (extraFieldKeys != null) {
            fieldKeys.addAll(extraFieldKeys);
        }
        return JiraIntegrationSupport.sendRequestVia(
            ref.profile.Named_Credential_Api_Name__c,
            'GET',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(ref.normalizedKey, 'UTF-8'),
            new Map<String, String>{
                'fields' => String.join(new List<String>(fieldKeys), ','),
                'expand' => 'changelog'
            },
            null
        );
    }

    public static String buildIssueUrl(Jira_Connector_Profile__c profile, String issueKey) {
        if (profile == null || String.isBlank(profile.Browse_Base_Url__c) || String.isBlank(issueKey)) {
            return '';
        }
        String base = profile.Browse_Base_Url__c.endsWith('/')
            ? profile.Browse_Base_Url__c.substring(0, profile.Browse_Base_Url__c.length() - 1)
            : profile.Browse_Base_Url__c;
        return base + '/browse/' + issueKey;
    }

    public static String renderMappedFields(String connectorKey, Map<String, Object> fields) {
        List<String> lines = new List<String>();
        for (Jira_Field_Mapping__c mapping : summaryMappings(connectorKey)) {
            if (String.isBlank(mapping.Backend_Field_Key__c)) {
                continue;
            }
            Object rawValue = fields.get(mapping.Backend_Field_Key__c);
            String rendered = renderFieldValue(rawValue);
            if (!String.isBlank(rendered)) {
                String label = String.isBlank(mapping.Backend_Field_Label__c) ? mapping.Backend_Field_Key__c : mapping.Backend_Field_Label__c;
                lines.add(JiraDirectActionSupport.sanitizeExternalText(label, 60) + ': ' + rendered);
            }
        }
        return String.join(lines, '\n');
    }

    private static String renderFieldValue(Object rawValue) {
        if (rawValue == null) {
            return '';
        }
        if (rawValue instanceof Map<String, Object>) {
            Map<String, Object> valueMap = (Map<String, Object>) rawValue;
            for (String candidateKey : new List<String>{ 'displayName', 'name', 'value' }) {
                String candidate = JiraIntegrationSupport.stringValue(valueMap.get(candidateKey));
                if (!String.isBlank(candidate)) {
                    return JiraDirectActionSupport.sanitizeExternalText(candidate, 200);
                }
            }
            return '';
        }
        if (rawValue instanceof List<Object>) {
            List<String> parts = new List<String>();
            for (Object entry : (List<Object>) rawValue) {
                String part = renderFieldValue(entry);
                if (!String.isBlank(part)) {
                    parts.add(part);
                }
            }
            return String.join(parts, ', ');
        }
        return JiraDirectActionSupport.sanitizeExternalText(String.valueOf(rawValue), 200);
    }

    // ---------------------------------------------------------------------
    // Allowlisted field updates
    // ---------------------------------------------------------------------
    public static PreparedUpdate prepareFieldUpdate(IssueRef ref, Map<String, Object> requestedChanges) {
        if (requestedChanges == null || requestedChanges.isEmpty()) {
            throw validation('Provide at least one field to update.');
        }
        PreparedUpdate prepared = new PreparedUpdate();
        prepared.connectorKey = ref.profile.Connector_Key__c;
        Map<String, Jira_Field_Mapping__c> allowlist = updatableMappingsByAlias(ref.profile.Connector_Key__c);

        for (String requestedKey : requestedChanges.keySet()) {
            String alias = requestedKey == null ? '' : requestedKey.trim().toLowerCase();
            Jira_Field_Mapping__c mapping = allowlist.get(alias);
            if (mapping == null) {
                throw validation(
                    'Field "' + requestedKey + '" is not enabled for agent updates. An administrator must allowlist it ' +
                    '(Jira_Field_Mapping__c.Allow_Agent_Update__c) before it can be changed.'
                );
            }
            Object rawValue = requestedChanges.get(requestedKey);
            String stringValue = rawValue == null ? '' : String.valueOf(rawValue);
            if (String.isBlank(stringValue)) {
                throw validation('Provide a value for "' + requestedKey + '".');
            }
            Object jiraValue = transformValue(mapping, stringValue);
            prepared.fields.put(mapping.Backend_Field_Key__c, jiraValue);
            String label = String.isBlank(mapping.Backend_Field_Label__c) ? mapping.Backend_Field_Key__c : mapping.Backend_Field_Label__c;
            prepared.previewLines.add(label + ' -> ' + JiraDirectActionSupport.sanitizeExternalText(stringValue, 200));
        }
        if (prepared.fields.isEmpty()) {
            throw validation('No valid, allowlisted field changes were provided.');
        }
        return prepared;
    }

    public static void applyFieldUpdate(IssueRef ref, Map<String, Object> fields) {
        if (fields == null || fields.isEmpty()) {
            return;
        }
        JiraIntegrationSupport.sendRequestVia(
            ref.profile.Named_Credential_Api_Name__c,
            'PUT',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(ref.normalizedKey, 'UTF-8'),
            null,
            new Map<String, Object>{ 'fields' => fields }
        );
    }

    private static Object transformValue(Jira_Field_Mapping__c mapping, String sourceValue) {
        String transformType = String.isBlank(mapping.Transform_Type__c) ? 'Direct' : mapping.Transform_Type__c;
        if (transformType == 'ADF Document') {
            return JiraIntegrationSupport.buildAdfDocument(new List<String>{ sourceValue });
        }
        if (transformType == 'Option Id') {
            String optionId = optionIdFor(mapping.Transform_Config_JSON__c, sourceValue);
            return new Map<String, Object>{ 'id' => String.isBlank(optionId) ? sourceValue : optionId };
        }
        if (transformType == 'User Mapping') {
            JiraIntegrationSupport.JiraUserMapping userMapping = JiraIntegrationSupport.getRequiredUserMapping(sourceValue);
            return new Map<String, Object>{ 'id' => userMapping.jiraAccountId };
        }
        if (mapping.Backend_Field_Key__c == 'priority') {
            return new Map<String, Object>{ 'name' => sourceValue };
        }
        return sourceValue;
    }

    private static String optionIdFor(String transformConfigJson, String sourceValue) {
        if (String.isBlank(transformConfigJson) || String.isBlank(sourceValue)) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(transformConfigJson);
            if (parsed instanceof Map<String, Object>) {
                Object match = ((Map<String, Object>) parsed).get(sourceValue);
                return match == null ? null : String.valueOf(match);
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }

    private static Map<String, Jira_Field_Mapping__c> updatableMappingsByAlias(String connectorKey) {
        Map<String, Jira_Field_Mapping__c> byAlias = new Map<String, Jira_Field_Mapping__c>();
        List<Jira_Field_Mapping__c> mappings = mappingsForConnector(connectorKey);
        for (Jira_Field_Mapping__c mapping : mappings) {
            if (mapping.Allow_Agent_Update__c != true || mapping.Enabled__c != true) {
                continue;
            }
            if (!String.isBlank(mapping.Canonical_Field__c)) {
                byAlias.put(mapping.Canonical_Field__c.trim().toLowerCase(), mapping);
            }
            if (!String.isBlank(mapping.Backend_Field_Key__c)) {
                byAlias.put(mapping.Backend_Field_Key__c.trim().toLowerCase(), mapping);
            }
        }
        // Built-in safe defaults for the legacy single-project fallback only.
        if (connectorKey == 'legacy-default') {
            addBuiltinLegacyMapping(byAlias, 'summary', 'summary', 'Summary', 'Direct');
            addBuiltinLegacyMapping(byAlias, 'priority', 'priority', 'Priority', 'Name');
        }
        return byAlias;
    }

    private static void addBuiltinLegacyMapping(
        Map<String, Jira_Field_Mapping__c> byAlias,
        String canonical,
        String backendKey,
        String label,
        String transformType
    ) {
        if (byAlias.containsKey(canonical) || byAlias.containsKey(backendKey)) {
            return;
        }
        Jira_Field_Mapping__c mapping = new Jira_Field_Mapping__c(
            Canonical_Field__c = canonical,
            Backend_Field_Key__c = backendKey,
            Backend_Field_Label__c = label,
            Enabled__c = true,
            Allow_Agent_Update__c = true,
            Transform_Type__c = transformType
        );
        byAlias.put(canonical, mapping);
        byAlias.put(backendKey, mapping);
    }

    private static List<Jira_Field_Mapping__c> summaryMappings(String connectorKey) {
        List<Jira_Field_Mapping__c> summary = new List<Jira_Field_Mapping__c>();
        for (Jira_Field_Mapping__c mapping : mappingsForConnector(connectorKey)) {
            if (mapping.Enabled__c == true && mapping.Use_In_Summary__c == true) {
                summary.add(mapping);
            }
        }
        return summary;
    }

    private static List<Jira_Field_Mapping__c> mappingsForConnector(String connectorKey) {
        if (mappingOverrides != null) {
            List<Jira_Field_Mapping__c> filtered = new List<Jira_Field_Mapping__c>();
            for (Jira_Field_Mapping__c mapping : mappingOverrides) {
                if (equalsIgnoreCase(mapping.Connector_Key__c, connectorKey)) {
                    filtered.add(mapping);
                }
            }
            return filtered;
        }
        if (String.isBlank(connectorKey)) {
            return new List<Jira_Field_Mapping__c>();
        }
        return [
            SELECT Id, Connector_Key__c, Canonical_Field__c, Backend_Field_Key__c, Backend_Field_Label__c,
                Enabled__c, Allow_Agent_Update__c, Use_In_Summary__c, Transform_Type__c, Transform_Config_JSON__c
            FROM Jira_Field_Mapping__c
            WHERE Connector_Key__c = :connectorKey AND Enabled__c = true
            WITH USER_MODE
        ];
    }

    // ---------------------------------------------------------------------
    // Two-phase confirmation tokens (persisted in the audit ledger)
    // ---------------------------------------------------------------------
    public static String createPendingToken(String operation, IssueRef ref, Object payload, String previewText) {
        String token = operation + ':' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).toLowerCase();
        Map<String, Object> details = new Map<String, Object>{
            'connectorKey' => ref.profile.Connector_Key__c,
            'issueKey' => ref.normalizedKey,
            'payload' => payload,
            'preview' => JiraDirectActionSupport.sanitizeExternalText(previewText, 2000),
            'expiresAt' => Datetime.now().addMinutes(TOKEN_TTL_MINUTES).getTime(),
            'createdByUserId' => UserInfo.getUserId()
        };
        Database.insert(
            new List<Jira_Integration_Transaction__c>{
                new Jira_Integration_Transaction__c(
                    Correlation_Key__c = token,
                    Operation__c = 'PendingMutation',
                    Jira_Issue_Key__c = ref.normalizedKey,
                    Outcome__c = 'Pending',
                    Details__c = JSON.serialize(details)
                )
            },
            true,
            AccessLevel.USER_MODE
        );
        return token;
    }

    public class PendingToken {
        public Id recordId;
        public Map<String, Object> details;
    }

    // Validates a pending confirmation token WITHOUT touching the callout, and
    // performs no DML on the happy path so the caller can safely make its Jira
    // callout afterward (avoids "uncommitted work pending"). Call markTokenApplied
    // only after the callout succeeds.
    public static PendingToken validatePendingToken(String operation, String token, String issueKey) {
        if (String.isBlank(token) || !token.startsWith(operation + ':')) {
            throw validation('A valid confirmation token from the prepare step is required before applying this change.');
        }
        if (pendingTokenDetailOverrides != null) {
            Map<String, Object> overrideDetails = pendingTokenDetailOverrides.get(token);
            if (overrideDetails == null) {
                throw validation('This confirmation is no longer valid. Re-run the preview and confirm the fresh change.');
            }
            if (!equalsIgnoreCase(JiraIntegrationSupport.stringValue(overrideDetails.get('issueKey')), issueKey)) {
                throw validation('The confirmed Jira issue key does not match the issue being changed.');
            }
            validateTokenOwner(overrideDetails);
            PendingToken overrideResult = new PendingToken();
            overrideResult.details = overrideDetails;
            return overrideResult;
        }
        List<Jira_Integration_Transaction__c> pending = [
            SELECT Id, Correlation_Key__c, Jira_Issue_Key__c, Outcome__c, Details__c
            FROM Jira_Integration_Transaction__c
            WHERE Correlation_Key__c = :token AND Operation__c = 'PendingMutation' AND Outcome__c = 'Pending'
            WITH USER_MODE
            LIMIT 1
        ];
        if (pending.isEmpty()) {
            throw validation('This confirmation is no longer valid. Re-run the preview and confirm the fresh change.');
        }
        Jira_Integration_Transaction__c record = pending[0];
        Map<String, Object> details = (Map<String, Object>) JSON.deserializeUntyped(record.Details__c);
        Long expiresAt = toLongValue(details.get('expiresAt'));
        if (expiresAt != null && Datetime.now().getTime() > expiresAt) {
            record.Outcome__c = 'Expired';
            Database.update(new List<Jira_Integration_Transaction__c>{ record }, true, AccessLevel.USER_MODE);
            throw validation('This confirmation expired. Re-run the preview and confirm the fresh change.');
        }
        if (!equalsIgnoreCase(JiraIntegrationSupport.stringValue(details.get('issueKey')), issueKey)) {
            throw validation('The confirmed Jira issue key does not match the issue being changed.');
        }
        validateTokenOwner(details);
        PendingToken result = new PendingToken();
        result.recordId = record.Id;
        result.details = details;
        return result;
    }

    public static void markTokenApplied(Id recordId) {
        if (pendingTokenDetailOverrides != null || recordId == null) {
            return;
        }
        Database.update(
            new List<Jira_Integration_Transaction__c>{
                new Jira_Integration_Transaction__c(Id = recordId, Outcome__c = 'Applied')
            },
            true,
            AccessLevel.USER_MODE
        );
    }

    private static void validateTokenOwner(Map<String, Object> details) {
        String createdByUserId = JiraIntegrationSupport.stringValue(details.get('createdByUserId'));
        if (String.isBlank(createdByUserId) || createdByUserId != UserInfo.getUserId()) {
            throw validation('This confirmation token belongs to a different user. Re-run the preview and confirm the fresh change.');
        }
    }

    // ---------------------------------------------------------------------
    // Comments / transitions / assignment
    // ---------------------------------------------------------------------
    public static void addComment(IssueRef ref, String commentText) {
        JiraIntegrationSupport.sendRequestVia(
            ref.profile.Named_Credential_Api_Name__c,
            'POST',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(ref.normalizedKey, 'UTF-8') + '/comment',
            null,
            new Map<String, Object>{
                'body' => JiraIntegrationSupport.buildAdfDocument(
                    JiraIntegrationSupport.buildStampedCommentLines(commentText)
                )
            }
        );
    }

    public static List<Map<String, Object>> getTransitions(IssueRef ref) {
        Map<String, Object> response = JiraIntegrationSupport.sendRequestVia(
            ref.profile.Named_Credential_Api_Name__c,
            'GET',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(ref.normalizedKey, 'UTF-8') + '/transitions',
            null,
            null
        );
        List<Map<String, Object>> transitions = new List<Map<String, Object>>();
        for (Object entry : JiraIntegrationSupport.listValue(response.get('transitions'))) {
            Map<String, Object> transition = JiraIntegrationSupport.mapValue(entry);
            String id = JiraIntegrationSupport.stringValue(transition.get('id'));
            String name = JiraIntegrationSupport.stringValue(transition.get('name'));
            String toName = JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(transition.get('to')).get('name'));
            transitions.add(new Map<String, Object>{ 'id' => id, 'name' => name, 'to' => toName });
        }
        return transitions;
    }

    public static void applyTransition(IssueRef ref, String transitionId) {
        JiraIntegrationSupport.sendRequestVia(
            ref.profile.Named_Credential_Api_Name__c,
            'POST',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(ref.normalizedKey, 'UTF-8') + '/transitions',
            null,
            new Map<String, Object>{ 'transition' => new Map<String, Object>{ 'id' => transitionId } }
        );
    }

    public static List<Map<String, Object>> searchAssignableUsers(IssueRef ref, String query) {
        Map<String, String> queryParams = new Map<String, String>{
            'issueKey' => ref.normalizedKey,
            'maxResults' => '10'
        };
        if (!String.isBlank(query)) {
            queryParams.put('query', query.trim());
        }
        Map<String, Object> raw = JiraIntegrationSupport.sendRequestRawVia(
            ref.profile.Named_Credential_Api_Name__c,
            'GET',
            '/rest/api/3/user/assignable/search',
            queryParams,
            null
        );
        // The assignable-search endpoint returns a JSON array at the top level.
        List<Object> entries = raw.containsKey('__list')
            ? JiraIntegrationSupport.listValue(raw.get('__list'))
            : new List<Object>();
        List<Map<String, Object>> candidates = new List<Map<String, Object>>();
        for (Object entry : entries) {
            Map<String, Object> user = JiraIntegrationSupport.mapValue(entry);
            candidates.add(new Map<String, Object>{
                'accountId' => JiraIntegrationSupport.stringValue(user.get('accountId')),
                'displayName' => JiraIntegrationSupport.stringValue(user.get('displayName'))
            });
        }
        return candidates;
    }

    public static void assignIssue(IssueRef ref, String accountId) {
        JiraIntegrationSupport.sendRequestVia(
            ref.profile.Named_Credential_Api_Name__c,
            'PUT',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(ref.normalizedKey, 'UTF-8') + '/assignee',
            null,
            new Map<String, Object>{ 'accountId' => accountId }
        );
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------
    private static Jira_Connector_Profile__c legacyProfile() {
        JiraIntegrationSupport.JiraConfiguration config = JiraIntegrationSupport.getConfiguration();
        return new Jira_Connector_Profile__c(
            Connector_Key__c = 'legacy-default',
            Named_Credential_Api_Name__c = config.namedCredentialApiName,
            Project_Id__c = config.projectId,
            Project_Key__c = config.projectKey,
            Issue_Type_Id__c = config.issueTypeId,
            Browse_Base_Url__c = config.browseBaseUrl,
            Open_Issue_Jql_Clause__c = config.openIssueJqlClause,
            Active__c = true,
            Is_Active_For_Agentforce__c = true
        );
    }

    private static Integer normalizePageSize(Integer requested) {
        if (requested == null || requested <= 0) {
            return DEFAULT_PAGE_SIZE;
        }
        return requested > MAX_PAGE_SIZE ? MAX_PAGE_SIZE : requested;
    }

    private static Integer toInteger(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        try {
            return Integer.valueOf(String.valueOf(value));
        } catch (Exception ignored) {
            return 0;
        }
    }

    private static Long toLongValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Long) {
            return (Long) value;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).longValue();
        }
        try {
            return Long.valueOf(String.valueOf(value));
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Boolean equalsIgnoreCase(String first, String second) {
        return !String.isBlank(first) && !String.isBlank(second) && first.trim().equalsIgnoreCase(second.trim());
    }

    private static JiraIntegrationSupport.JiraIntegrationException validation(String message) {
        return JiraIntegrationSupport.newException('VALIDATION', null, false, message);
    }

    private static JiraIntegrationSupport.JiraIntegrationException scope(String message) {
        return JiraIntegrationSupport.newException('SCOPE', null, false, message);
    }

    private static JiraIntegrationSupport.JiraIntegrationException configuration(String message) {
        return JiraIntegrationSupport.newException('CONFIGURATION', null, false, message);
    }
}