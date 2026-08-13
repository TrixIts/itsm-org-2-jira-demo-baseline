public with sharing class JiraIntegrationSupport {
    private static final Integer MAX_OPEN_ISSUES = 5;

    public class JiraConfiguration {
        public String namedCredentialApiName;
        public String projectId;
        public String issueTypeId;
        public String projectKey;
        public String browseBaseUrl;
        public String openIssueJqlClause;
        public String impactFieldKey;
        public String urgencyFieldKey;
        public String severityFieldKey;
        public Set<String> allowedImpactOptionIds;
        public Set<String> allowedUrgencyOptionIds;
        public Set<String> allowedSeverityOptionIds;
        public Boolean enforceProjectScope;
        public Boolean requireReporterMatchForRead;
        public Boolean requireReporterMatchForWrite;
        public Boolean exposeInternalComments;
        public String sharedReporterAccountId;
        public String sharedReporterDisplayName;
    }

    public class JiraUserMapping {
        public String salesforceUsername;
        public String jiraAccountId;
        public String jiraDisplayName;
    }

    public class JiraIntegrationException extends Exception {
        public String errorType;
        public Integer statusCode;
        public Boolean isRetryable;
    }

    private class JiraActivityEvent {
        public Datetime occurredAt;
        public String summary;
    }

    @TestVisible
    private static JiraConfiguration configOverride;

    @TestVisible
    private static Map<String, JiraUserMapping> mappingOverridesByUsername;

    @TestVisible
    private static String commentAuthorSalesforceUsernameOverride;

    public static JiraIntegrationException newException(
        String errorType,
        Integer statusCode,
        Boolean isRetryable,
        String safeMessage
    ) {
        JiraIntegrationException exceptionValue = new JiraIntegrationException(safeMessage);
        exceptionValue.errorType = errorType;
        exceptionValue.statusCode = statusCode;
        exceptionValue.isRetryable = isRetryable;
        return exceptionValue;
    }

    public static JiraConfiguration getConfiguration() {
        if (configOverride != null) {
            return normalizeConfiguration(configOverride);
        }

        List<Jira_Connector_Profile__c> employeeProfiles = [
            SELECT Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c, Issue_Type_Id__c,
                Browse_Base_Url__c, Open_Issue_Jql_Clause__c, Shared_Reporter_Account_Id__c,
                Shared_Reporter_Display_Name__c
            FROM Jira_Connector_Profile__c
            WHERE Active__c = true AND Is_Active_For_Agentforce__c = true AND Employee_Default__c = true
            LIMIT 2
        ];
        if (employeeProfiles.size() > 1) {
            throw newException(
                'CONFIGURATION',
                null,
                false,
                'Multiple active Jira connector profiles are marked Employee Default. Keep exactly one employee default.'
            );
        }
        if (employeeProfiles.size() == 1) {
            Jira_Connector_Profile__c profile = employeeProfiles[0];
            JiraConfiguration profileConfig = new JiraConfiguration();
            profileConfig.namedCredentialApiName = profile.Named_Credential_Api_Name__c;
            profileConfig.projectId = profile.Project_Id__c;
            profileConfig.issueTypeId = profile.Issue_Type_Id__c;
            profileConfig.projectKey = profile.Project_Key__c;
            profileConfig.browseBaseUrl = profile.Browse_Base_Url__c;
            profileConfig.openIssueJqlClause = String.isBlank(profile.Open_Issue_Jql_Clause__c)
                ? 'statusCategory != Done ORDER BY updated DESC'
                : profile.Open_Issue_Jql_Clause__c;
            profileConfig.enforceProjectScope = true;
            profileConfig.requireReporterMatchForRead = true;
            profileConfig.requireReporterMatchForWrite = true;
            profileConfig.exposeInternalComments = false;
            profileConfig.sharedReporterAccountId = profile.Shared_Reporter_Account_Id__c;
            profileConfig.sharedReporterDisplayName = profile.Shared_Reporter_Display_Name__c;
            validateRequiredConfiguration(profileConfig, 'employee-default Jira connector profile');
            return normalizeConfiguration(profileConfig);
        }

        Map<String, String> configValuesByKey = new Map<String, String>();
        for (Jira_Demo_Setting__mdt record : Jira_Demo_Setting__mdt.getAll().values()) {
            if (record.SettingType__c == 'Config') {
                configValuesByKey.put(record.SettingKey__c, record.SettingValue__c);
            }
        }

        JiraConfiguration config = new JiraConfiguration();
        config.namedCredentialApiName = configValuesByKey.get('NamedCredentialApiName');
        config.projectId = configValuesByKey.get('ProjectId');
        config.issueTypeId = configValuesByKey.get('IssueTypeId');
        config.projectKey = configValuesByKey.get('ProjectKey');
        config.browseBaseUrl = configValuesByKey.get('BrowseBaseUrl');
        config.openIssueJqlClause = String.isBlank(configValuesByKey.get('OpenIssueJqlClause'))
            ? 'statusCategory != Done ORDER BY updated DESC'
            : configValuesByKey.get('OpenIssueJqlClause');
        config.impactFieldKey = configValuesByKey.get('ImpactFieldKey');
        config.urgencyFieldKey = configValuesByKey.get('UrgencyFieldKey');
        config.severityFieldKey = configValuesByKey.get('SeverityFieldKey');
        config.allowedImpactOptionIds = parseCsvValues(configValuesByKey.get('AllowedImpactOptionIds'));
        config.allowedUrgencyOptionIds = parseCsvValues(configValuesByKey.get('AllowedUrgencyOptionIds'));
        config.allowedSeverityOptionIds = parseCsvValues(configValuesByKey.get('AllowedSeverityOptionIds'));
        config.enforceProjectScope = parseBoolean(configValuesByKey.get('EnforceProjectScope'), true);
        config.requireReporterMatchForRead = parseBoolean(configValuesByKey.get('RequireReporterMatchForRead'), false);
        config.requireReporterMatchForWrite = parseBoolean(configValuesByKey.get('RequireReporterMatchForWrite'), false);
        config.exposeInternalComments = parseBoolean(configValuesByKey.get('ExposeInternalComments'), false);
        config.sharedReporterAccountId = configValuesByKey.get('SharedReporterAccountId');
        config.sharedReporterDisplayName = configValuesByKey.get('SharedReporterDisplayName');

        validateRequiredConfiguration(config, 'legacy Jira_Demo_Setting__mdt configuration');
        return normalizeConfiguration(config);
    }

    private static JiraConfiguration normalizeConfiguration(JiraConfiguration config) {
        if (config.allowedImpactOptionIds == null) {
            config.allowedImpactOptionIds = new Set<String>();
        }
        if (config.allowedUrgencyOptionIds == null) {
            config.allowedUrgencyOptionIds = new Set<String>();
        }
        if (config.allowedSeverityOptionIds == null) {
            config.allowedSeverityOptionIds = new Set<String>();
        }
        config.enforceProjectScope = config.enforceProjectScope == null ? true : config.enforceProjectScope;
        config.requireReporterMatchForRead = config.requireReporterMatchForRead == null ? false : config.requireReporterMatchForRead;
        config.requireReporterMatchForWrite = config.requireReporterMatchForWrite == null ? false : config.requireReporterMatchForWrite;
        config.exposeInternalComments = config.exposeInternalComments == null ? false : config.exposeInternalComments;
        return config;
    }

    private static void validateRequiredConfiguration(JiraConfiguration config, String sourceLabel) {
        List<String> missingValues = new List<String>();
        if (String.isBlank(config.namedCredentialApiName)) {
            missingValues.add('Named Credential API name');
        }
        if (String.isBlank(config.projectId)) {
            missingValues.add('project ID');
        }
        if (String.isBlank(config.issueTypeId)) {
            missingValues.add('issue type ID');
        }
        if (!missingValues.isEmpty()) {
            throw newException(
                'CONFIGURATION',
                null,
                false,
                'The ' + sourceLabel + ' is missing ' + String.join(missingValues, ', ') +
                '. Configure the Jira Connector Mapping workspace before running employee Jira actions.'
            );
        }
    }

    public static List<String> validateConfigurationReadiness(JiraConfiguration config) {
        List<String> issues = new List<String>();
        addMissingOrPlaceholderIssue(issues, 'NamedCredentialApiName', config.namedCredentialApiName);
        addMissingOrPlaceholderIssue(issues, 'ProjectId', config.projectId);
        addMissingOrPlaceholderIssue(issues, 'IssueTypeId', config.issueTypeId);
        addMissingOrPlaceholderIssue(issues, 'ProjectKey', config.projectKey);
        addMissingOrPlaceholderIssue(issues, 'BrowseBaseUrl', config.browseBaseUrl);
        if (!String.isBlank(config.projectKey) &&
            !Pattern.matches('^[A-Za-z][A-Za-z0-9_]*$', config.projectKey.trim())) {
            issues.add('ProjectKey has an invalid Jira key format.');
        }
        if (!String.isBlank(config.browseBaseUrl) &&
            !config.browseBaseUrl.trim().toLowerCase().startsWith('https://')) {
            issues.add('BrowseBaseUrl must use HTTPS.');
        }
        if (!String.isBlank(config.impactFieldKey)) {
            validateConfiguredFieldKey(issues, 'ImpactFieldKey', config.impactFieldKey);
        }
        if (!String.isBlank(config.urgencyFieldKey)) {
            validateConfiguredFieldKey(issues, 'UrgencyFieldKey', config.urgencyFieldKey);
        }
        if (!String.isBlank(config.severityFieldKey)) {
            validateConfiguredFieldKey(issues, 'SeverityFieldKey', config.severityFieldKey);
        }
        return issues;
    }

    public static String resolveSalesforceUsername(String overrideUsername) {
        return String.isBlank(overrideUsername) ? UserInfo.getUserName() : overrideUsername.trim();
    }

    public static JiraUserMapping getRequiredUserMapping(String salesforceUsername) {
        String resolvedUsername = resolveSalesforceUsername(salesforceUsername);

        if (mappingOverridesByUsername != null && mappingOverridesByUsername.containsKey(resolvedUsername)) {
            return mappingOverridesByUsername.get(resolvedUsername);
        }

        Jira_Demo_Setting__mdt mappingRecord;
        for (Jira_Demo_Setting__mdt record : Jira_Demo_Setting__mdt.getAll().values()) {
            if (record.SettingType__c == 'UserMapping' && record.SettingKey__c == resolvedUsername) {
                mappingRecord = record;
                break;
            }
        }

        if (mappingRecord != null && !String.isBlank(mappingRecord.SettingValue__c)) {
            JiraUserMapping explicitMapping = new JiraUserMapping();
            explicitMapping.salesforceUsername = resolvedUsername;
            explicitMapping.jiraAccountId = mappingRecord.SettingValue__c;
            explicitMapping.jiraDisplayName = mappingRecord.AuxValue__c;
            return explicitMapping;
        }

        JiraConfiguration config = getConfiguration();
        if (!String.isBlank(config.sharedReporterAccountId)) {
            JiraUserMapping sharedMapping = new JiraUserMapping();
            sharedMapping.salesforceUsername = 'Shared Jira reporter';
            sharedMapping.jiraAccountId = config.sharedReporterAccountId.trim();
            sharedMapping.jiraDisplayName = String.isBlank(config.sharedReporterDisplayName)
                ? 'Shared Jira reporter'
                : config.sharedReporterDisplayName.trim();
            return sharedMapping;
        }

        Map<String, Object> currentUser = sendRequestVia(
            config.namedCredentialApiName,
            'GET',
            '/rest/api/3/myself',
            null,
            null
        );
        JiraUserMapping principalMapping = new JiraUserMapping();
        principalMapping.salesforceUsername = resolvedUsername;
        principalMapping.jiraAccountId = stringValue(currentUser.get('accountId'));
        principalMapping.jiraDisplayName = stringValue(currentUser.get('displayName'));
        if (String.isBlank(principalMapping.jiraAccountId)) {
            throw newException(
                'CONFIGURATION',
                null,
                false,
                'Jira did not return an accountId for the Named Credential principal. Configure a shared reporter on the employee-default profile.'
            );
        }
        return principalMapping;
    }

    public static List<String> buildIssueDescriptionLines(
        String jiraDescription,
        String requesterEmail,
        String channel,
        String sourceReference
    ) {
        List<String> lines = new List<String>();
        if (!String.isBlank(jiraDescription)) {
            lines.add(jiraDescription.trim());
        }
        if (!String.isBlank(requesterEmail)) {
            lines.add('Requester email: ' + requesterEmail.trim());
        }
        if (!String.isBlank(channel)) {
            lines.add('Channel: ' + channel.trim());
        }
        if (!String.isBlank(sourceReference)) {
            lines.add('Source reference: ' + sourceReference.trim());
        }
        return lines;
    }

    public static Map<String, Object> buildAdfDocument(List<String> lines) {
        List<Object> paragraphs = new List<Object>();
        for (String line : lines) {
            if (!String.isBlank(line)) {
                paragraphs.add(new Map<String, Object>{
                    'type' => 'paragraph',
                    'content' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'text',
                            'text' => line
                        }
                    }
                });
            }
        }

        if (paragraphs.isEmpty()) {
            paragraphs.add(new Map<String, Object>{
                'type' => 'paragraph',
                'content' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'text',
                        'text' => 'No additional details provided.'
                    }
                }
            });
        }

        return new Map<String, Object>{
            'type' => 'doc',
            'version' => 1,
            'content' => paragraphs
        };
    }

    public static Map<String, Object> sendRequest(
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        return sendRequestVia(getConfiguration().namedCredentialApiName, method, path, queryParams, body);
    }

    // Multi-project variant: callers pass an explicit Named Credential so a single
    // fulfiller runtime can reach several Jira_Connector_Profile__c projects while
    // reusing the same hardened error taxonomy and response parsing.
    public static Map<String, Object> sendRequestVia(
        String namedCredentialApiName,
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        Object parsed = sendRequestRawVia(namedCredentialApiName, method, path, queryParams, body);
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }
        throw newException(
            'MALFORMED_RESPONSE',
            null,
            true,
            'Jira returned an unexpected response shape for ' + method + ' ' + path + '.'
        );
    }

    // Raw variant that tolerates Jira endpoints returning a top-level JSON array
    // (e.g. assignable user search). Top-level arrays are wrapped as {'__list': [...]}.
    public static Map<String, Object> sendRequestRawVia(
        String namedCredentialApiName,
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        if (String.isBlank(namedCredentialApiName)) {
            throw newException(
                'CONFIGURATION',
                null,
                false,
                'A Named Credential must be configured before calling Jira.'
            );
        }
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setTimeout(60000);

        String endpoint = 'callout:' + namedCredentialApiName + path;
        if (queryParams != null && !queryParams.isEmpty()) {
            List<String> encodedPairs = new List<String>();
            for (String key : queryParams.keySet()) {
                String value = queryParams.get(key);
                if (value != null) {
                    encodedPairs.add(
                        EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(value, 'UTF-8')
                    );
                }
            }
            if (!encodedPairs.isEmpty()) {
                endpoint += '?' + String.join(encodedPairs, '&');
            }
        }
        request.setEndpoint(endpoint);

        if (body != null) {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(body));
        }

        HttpResponse response;
        try {
            response = new Http().send(request);
            if (method == 'GET' && response.getStatusCode() >= 500) {
                response = new Http().send(request);
            }
        } catch (CalloutException calloutException) {
            throw newException(
                'AVAILABILITY',
                null,
                true,
                'Jira is temporarily unavailable. Try the action again later.'
            );
        }
        Integer statusCode = response.getStatusCode();

        if (statusCode < 200 || statusCode >= 300) {
            throw buildHttpException(statusCode);
        }

        if (String.isBlank(response.getBody())) {
            return new Map<String, Object>();
        }

        Object parsed = JSON.deserializeUntyped(response.getBody());
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }
        if (parsed instanceof List<Object>) {
            return new Map<String, Object>{ '__list' => parsed };
        }

        throw newException(
            'MALFORMED_RESPONSE',
            statusCode,
            true,
            'Jira returned an unexpected response shape for ' + method + ' ' + path + '.'
        );
    }

    public static Map<String, Object> createIssue(
        String jiraSummary,
        String jiraDescription,
        String jiraPriority,
        String jiraUrgencyOptionId,
        String jiraImpactOptionId,
        String jiraSeverityOptionId,
        String requesterEmail,
        String channel,
        String sourceReference,
        String reporterSalesforceUsername
    ) {
        JiraDirectActionSupport.validateCreateInputs(
            jiraSummary,
            jiraDescription,
            jiraPriority,
            requesterEmail,
            channel,
            sourceReference
        );
        JiraConfiguration config = getConfiguration();
        JiraUserMapping reporter = getRequiredUserMapping(reporterSalesforceUsername);

        Map<String, Object> fields = new Map<String, Object>{
            'project' => new Map<String, Object>{ 'id' => config.projectId },
            'issuetype' => new Map<String, Object>{ 'id' => config.issueTypeId },
            'summary' => jiraSummary,
            'description' => buildAdfDocument(
                buildIssueDescriptionLines(jiraDescription, requesterEmail, channel, sourceReference)
            ),
            'reporter' => new Map<String, Object>{ 'id' => reporter.jiraAccountId }
        };

        if (!String.isBlank(jiraPriority)) {
            fields.put('priority', new Map<String, Object>{ 'name' => jiraPriority });
        }
        if (!String.isBlank(jiraImpactOptionId)) {
            validateOptionId('impact', config.impactFieldKey, jiraImpactOptionId, config.allowedImpactOptionIds);
            fields.put(config.impactFieldKey, new Map<String, Object>{ 'id' => jiraImpactOptionId });
        }
        if (!String.isBlank(jiraUrgencyOptionId)) {
            validateOptionId('urgency', config.urgencyFieldKey, jiraUrgencyOptionId, config.allowedUrgencyOptionIds);
            fields.put(config.urgencyFieldKey, new Map<String, Object>{ 'id' => jiraUrgencyOptionId });
        }
        if (!String.isBlank(jiraSeverityOptionId)) {
            validateOptionId('severity', config.severityFieldKey, jiraSeverityOptionId, config.allowedSeverityOptionIds);
            fields.put(config.severityFieldKey, new Map<String, Object>{ 'id' => jiraSeverityOptionId });
        }

        return sendRequest(
            'POST',
            '/rest/api/3/issue',
            null,
            new Map<String, Object>{ 'fields' => fields }
        );
    }

    public static Map<String, Object> getIssueByKey(String jiraIssueKey) {
        String validatedIssueKey = JiraDirectActionSupport.validateIssueKey(jiraIssueKey);
        Map<String, Object> issueData = sendRequest(
            'GET',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(validatedIssueKey, 'UTF-8'),
            new Map<String, String>{
                'fields' => 'project,summary,status,reporter,assignee,updated,comment,priority,resolution',
                'expand' => 'changelog'
            },
            null
        );
        validateIssueAccess(issueData, false);
        return issueData;
    }

    public static Map<String, Object> searchIssuesForReporter(String reporterSalesforceUsername, Integer maxResults) {
        JiraConfiguration config = getConfiguration();
        JiraUserMapping reporter = getRequiredUserMapping(reporterSalesforceUsername);

        List<String> jqlSegments = new List<String>();
        if (!String.isBlank(config.projectKey)) {
            jqlSegments.add('project = "' + escapeJqlLiteral(config.projectKey) + '"');
        }
        jqlSegments.add('reporter = "' + escapeJqlLiteral(reporter.jiraAccountId) + '"');
        if (!String.isBlank(config.openIssueJqlClause)) {
            jqlSegments.add(config.openIssueJqlClause);
        }

        Integer resolvedMaxResults = (maxResults == null || maxResults <= 0) ? MAX_OPEN_ISSUES : Math.min(maxResults, MAX_OPEN_ISSUES);

        return sendRequest(
            'GET',
            '/rest/api/3/search/jql',
            new Map<String, String>{
                'jql' => String.join(jqlSegments, ' AND '),
                'maxResults' => String.valueOf(resolvedMaxResults),
                'fields' => 'summary,status,reporter,assignee,updated,priority'
            },
            null
        );
    }

    public static void updateIssue(
        String jiraIssueIdOrKey,
        String jiraSummary,
        String jiraPriority,
        String jiraImpactOptionId,
        String jiraUrgencyOptionId,
        String jiraSeverityOptionId
    ) {
        String validatedIssueKey = JiraDirectActionSupport.validateIssueKey(jiraIssueIdOrKey);
        JiraDirectActionSupport.validateSummary(jiraSummary);
        JiraDirectActionSupport.validatePriority(jiraPriority);
        Map<String, Object> issueData = getIssueByKey(validatedIssueKey);
        validateIssueAccess(issueData, true);
        if (isClosedIssue(issueData)) {
            throw newException(
                'VALIDATION',
                null,
                false,
                'Jira issue ' + jiraIssueIdOrKey + ' is closed. Create a new request or add a follow-up comment instead of changing triage fields.'
            );
        }

        JiraConfiguration config = getConfiguration();
        Map<String, Object> fields = new Map<String, Object>();
        if (!String.isBlank(jiraSummary)) {
            fields.put('summary', jiraSummary);
        }
        if (!String.isBlank(jiraPriority)) {
            fields.put('priority', new Map<String, Object>{ 'name' => jiraPriority });
        }
        if (!String.isBlank(jiraImpactOptionId)) {
            validateOptionId('impact', config.impactFieldKey, jiraImpactOptionId, config.allowedImpactOptionIds);
            fields.put(config.impactFieldKey, new Map<String, Object>{ 'id' => jiraImpactOptionId });
        }
        if (!String.isBlank(jiraUrgencyOptionId)) {
            validateOptionId('urgency', config.urgencyFieldKey, jiraUrgencyOptionId, config.allowedUrgencyOptionIds);
            fields.put(config.urgencyFieldKey, new Map<String, Object>{ 'id' => jiraUrgencyOptionId });
        }
        if (!String.isBlank(jiraSeverityOptionId)) {
            validateOptionId('severity', config.severityFieldKey, jiraSeverityOptionId, config.allowedSeverityOptionIds);
            fields.put(config.severityFieldKey, new Map<String, Object>{ 'id' => jiraSeverityOptionId });
        }

        if (!fields.isEmpty()) {
            sendRequest(
                'PUT',
                '/rest/api/3/issue/' + EncodingUtil.urlEncode(validatedIssueKey, 'UTF-8'),
                null,
                new Map<String, Object>{ 'fields' => fields }
            );
        }
    }

    public static void addComment(String jiraIssueIdOrKey, String commentText) {
        String validatedIssueKey = JiraDirectActionSupport.validateIssueKey(jiraIssueIdOrKey);
        JiraDirectActionSupport.validateComment(commentText);

        validateIssueAccess(getIssueByKey(validatedIssueKey), true);
        sendRequest(
            'POST',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(validatedIssueKey, 'UTF-8') + '/comment',
            null,
            new Map<String, Object>{
                'body' => buildAdfDocument(buildStampedCommentLines(commentText))
            }
        );
    }

    public static List<String> buildStampedCommentLines(String commentText) {
        List<String> lines = new List<String>();
        if (String.isBlank(commentText)) {
            return lines;
        }

        String resolvedUsername = resolveSalesforceUsername(commentAuthorSalesforceUsernameOverride);
        String commenterLabel = resolvedUsername;
        try {
            JiraUserMapping mapping = getRequiredUserMapping(resolvedUsername);
            if (!String.isBlank(mapping.jiraDisplayName)) {
                commenterLabel = mapping.jiraDisplayName;
            }
        } catch (Exception ignoredException) {
            // Fall back to the Salesforce username if a friendly mapping is unavailable.
            commenterLabel = String.isBlank(commenterLabel) ? ignoredException.getTypeName() : commenterLabel;
        }

        lines.add('Customer update from ' + commenterLabel + ' via Agentforce:');
        lines.add(commentText);
        return lines;
    }

    public static String buildIssueUrl(String jiraIssueKey) {
        JiraConfiguration config = getConfiguration();
        if (String.isBlank(config.browseBaseUrl) || String.isBlank(jiraIssueKey)) {
            return '';
        }

        String normalizedBaseUrl = config.browseBaseUrl.endsWith('/')
            ? config.browseBaseUrl.substring(0, config.browseBaseUrl.length() - 1)
            : config.browseBaseUrl;
        return normalizedBaseUrl + '/browse/' + jiraIssueKey;
    }

    public static String summarizeIssue(Map<String, Object> issueData) {
        String issueKey = stringValue(issueData.get('key'));
        Map<String, Object> fields = mapValue(issueData.get('fields'));
        String summary = JiraDirectActionSupport.sanitizeExternalText(stringValue(fields.get('summary')), 255);
        String status = issueStatus(issueData);
        String priority = issuePriority(issueData);
        String reporter = JiraDirectActionSupport.sanitizeExternalText(
            stringValue(mapValue(fields.get('reporter')).get('displayName')),
            120
        );
        String assignee = JiraDirectActionSupport.sanitizeExternalText(
            stringValue(mapValue(fields.get('assignee')).get('displayName')),
            120
        );
        String resolution = issueResolution(issueData);

        List<String> metadataParts = new List<String>();
        if (!String.isBlank(status)) {
            metadataParts.add('status ' + status);
        }
        if (!String.isBlank(priority)) {
            metadataParts.add('priority ' + priority);
        }
        if (!String.isBlank(assignee)) {
            metadataParts.add('assigned to ' + assignee);
        }
        if (!String.isBlank(resolution)) {
            metadataParts.add('resolution ' + resolution);
        }

        List<String> sentences = new List<String>();
        String leadIn = String.isBlank(issueKey) ? 'This Jira issue' : 'Jira issue ' + issueKey;
        if (metadataParts.isEmpty()) {
            sentences.add(leadIn + '.');
        } else {
            sentences.add(leadIn + ' has ' + String.join(metadataParts, ', ') + '.');
        }
        if (!String.isBlank(summary)) {
            sentences.add('Summary: ' + summary + '.');
        }
        if (!String.isBlank(reporter)) {
            sentences.add('Reporter: ' + reporter + '.');
        }

        return String.join(sentences, ' ');
    }

    public static String buildIssueResponseMessage(Map<String, Object> issueData) {
        String summary = summarizeIssueWithLatestUpdate(issueData);
        String followupGuidance = buildClosedIssueGuidance(issueData);
        return String.isBlank(followupGuidance) ? summary : summary + ' ' + followupGuidance;
    }

    public static String summarizeIssueWithLatestUpdate(Map<String, Object> issueData) {
        String issueSummary = summarizeIssue(issueData);
        String latestUpdate = describeLatestUpdate(issueData);
        if (String.isBlank(latestUpdate)) {
            return issueSummary;
        }

        return String.isBlank(issueSummary)
            ? 'Latest update: ' + latestUpdate + '.'
            : issueSummary + ' Latest update: ' + latestUpdate + '.';
    }

    public static String summarizeIssueForList(Map<String, Object> issueData) {
        Map<String, Object> fields = mapValue(issueData.get('fields'));
        String issueKey = JiraDirectActionSupport.sanitizeExternalText(stringValue(issueData.get('key')), 40);
        String status = JiraDirectActionSupport.sanitizeExternalText(issueStatus(issueData), 80);
        String priority = JiraDirectActionSupport.sanitizeExternalText(issuePriority(issueData), 80);
        String summary = JiraDirectActionSupport.sanitizeExternalText(stringValue(fields.get('summary')), 180);
        String latestUpdate = JiraDirectActionSupport.sanitizeExternalText(describeLatestUpdate(issueData), 220);

        List<String> headingParts = new List<String>();
        if (!String.isBlank(status)) {
            headingParts.add(status);
        }
        if (!String.isBlank(priority)) {
            headingParts.add(priority);
        }

        String heading = '• ' + (String.isBlank(issueKey) ? 'Jira issue' : issueKey);
        if (!headingParts.isEmpty()) {
            heading += ' — ' + String.join(headingParts, ' · ');
        }

        List<String> lines = new List<String>{ heading };
        if (!String.isBlank(summary)) {
            lines.add('  ' + summary);
        }
        if (!String.isBlank(latestUpdate)) {
            lines.add('  Latest: ' + latestUpdate);
        }
        return String.join(lines, '\n');
    }

    public static String describeLatestUpdate(Map<String, Object> issueData) {
        JiraActivityEvent latestEvent = chooseNewerEvent(
            newestCommentEvent(issueData),
            newestHistoryEvent(issueData)
        );
        if (latestEvent != null && !String.isBlank(latestEvent.summary)) {
            return latestEvent.summary;
        }

        String updatedValue = stringValue(mapValue(issueData.get('fields')).get('updated'));
        return String.isBlank(updatedValue)
            ? ''
            : 'issue metadata was updated in Jira at ' + updatedValue;
    }

    public static String issueStatus(Map<String, Object> issueData) {
        return stringValue(mapValue(mapValue(issueData.get('fields')).get('status')).get('name'));
    }

    public static String issuePriority(Map<String, Object> issueData) {
        return stringValue(mapValue(mapValue(issueData.get('fields')).get('priority')).get('name'));
    }

    public static String issueResolution(Map<String, Object> issueData) {
        return stringValue(mapValue(mapValue(issueData.get('fields')).get('resolution')).get('name'));
    }

    public static Boolean isClosedIssue(Map<String, Object> issueData) {
        String statusCategoryKey = stringValue(
            mapValue(mapValue(mapValue(issueData.get('fields')).get('status')).get('statusCategory')).get('key')
        ).toLowerCase();
        return statusCategoryKey == 'done' || !String.isBlank(issueResolution(issueData));
    }

    public static String buildClosedIssueGuidance(Map<String, Object> issueData) {
        if (!isClosedIssue(issueData)) {
            return '';
        }

        return 'This Jira issue appears closed. If the problem returned, offer to add a follow-up comment or create a new request.';
    }

    public static String summarizeRecentComments(Map<String, Object> issueData, Integer maxCount) {
        List<Object> comments = listValue(mapValue(mapValue(issueData.get('fields')).get('comment')).get('comments'));
        Integer resolvedMaxCount = (maxCount == null || maxCount <= 0) ? 3 : maxCount;
        List<String> renderedComments = new List<String>();

        for (Integer i = comments.size() - 1; i >= 0 && renderedComments.size() < resolvedMaxCount; i--) {
            String renderedComment = summarizeCommentEntry(mapValue(comments[i]));
            if (!String.isBlank(renderedComment)) {
                renderedComments.add(renderedComment);
            }
        }

        return String.join(renderedComments, '\n');
    }

    public static void validateWriteConfirmation(
        String jiraIssueIdOrKey,
        Boolean confirmedByEmployee,
        String confirmedJiraIssueKey,
        String commentText,
        String confirmedCommentText
    ) {
        if (confirmedByEmployee != true) {
            throw newException('VALIDATION', null, false, 'The employee must explicitly confirm the Jira write before it can be sent.');
        }
        if (!String.isBlank(confirmedJiraIssueKey) && !equalsIgnoreCaseTrimmed(jiraIssueIdOrKey, confirmedJiraIssueKey)) {
            throw newException('VALIDATION', null, false, 'The confirmed Jira issue key does not match the requested Jira issue key.');
        }
        if (!String.isBlank(commentText) && !equalsTrimmed(commentText, confirmedCommentText)) {
            throw newException('VALIDATION', null, false, 'The confirmed Jira comment text must exactly match the comment that will be sent.');
        }
    }

    public static void validateIssueAccess(Map<String, Object> issueData, Boolean forWrite) {
        JiraConfiguration config = getConfiguration();
        if (config.enforceProjectScope == true) {
            validateProjectScope(issueData, config);
        }
        if ((forWrite == true && config.requireReporterMatchForWrite == true) ||
            (forWrite != true && config.requireReporterMatchForRead == true)) {
            validateReporterScope(issueData);
        }
    }

    public static String summarizeRecentHistory(Map<String, Object> issueData, Integer maxCount) {
        List<Object> histories = listValue(mapValue(issueData.get('changelog')).get('histories'));
        Integer resolvedMaxCount = (maxCount == null || maxCount <= 0) ? 3 : maxCount;
        List<String> renderedHistory = new List<String>();

        for (Integer i = histories.size() - 1; i >= 0 && renderedHistory.size() < resolvedMaxCount; i--) {
            String renderedEntry = summarizeHistoryEntry(mapValue(histories[i]));
            if (!String.isBlank(renderedEntry)) {
                renderedHistory.add(renderedEntry);
            }
        }

        return String.join(renderedHistory, '\n');
    }

    public static Map<String, Object> mapValue(Object candidate) {
        return candidate instanceof Map<String, Object>
            ? (Map<String, Object>) candidate
            : new Map<String, Object>();
    }

    public static List<Object> listValue(Object candidate) {
        return candidate instanceof List<Object>
            ? (List<Object>) candidate
            : new List<Object>();
    }

    public static String stringValue(Object candidate) {
        return candidate == null ? '' : String.valueOf(candidate);
    }

    private static void validateProjectScope(Map<String, Object> issueData, JiraConfiguration config) {
        Map<String, Object> project = mapValue(mapValue(issueData.get('fields')).get('project'));
        String returnedProjectId = stringValue(project.get('id'));
        String returnedProjectKey = stringValue(project.get('key'));
        if (String.isBlank(returnedProjectId) && String.isBlank(returnedProjectKey)) {
            throw newException('SCOPE', null, false, 'Jira issue response did not include project information for scope validation.');
        }
        if (!String.isBlank(config.projectId) && returnedProjectId != config.projectId) {
            throw newException('SCOPE', null, false, 'Jira issue is outside the configured demo project.');
        }
        if (!String.isBlank(config.projectKey) && returnedProjectKey != config.projectKey) {
            throw newException('SCOPE', null, false, 'Jira issue is outside the configured demo project.');
        }
    }

    private static void validateReporterScope(Map<String, Object> issueData) {
        JiraUserMapping mapping = getRequiredUserMapping(null);
        String reporterAccountId = stringValue(mapValue(mapValue(issueData.get('fields')).get('reporter')).get('accountId'));
        if (String.isBlank(reporterAccountId)) {
            throw newException('SCOPE', null, false, 'Jira issue response did not include reporter accountId for access validation.');
        }
        if (reporterAccountId != mapping.jiraAccountId) {
            throw newException('SCOPE', null, false, 'Jira issue is not reported by the mapped Jira account for the current Salesforce user.');
        }
    }

    private static void validateOptionId(
        String label,
        String fieldKey,
        String optionId,
        Set<String> allowedOptionIds
    ) {
        if (String.isBlank(optionId)) {
            return;
        }
        if (String.isBlank(fieldKey)) {
            throw newException(
                'CONFIGURATION',
                null,
                false,
                'The Jira ' + label + ' field is not configured for the employee-default connector profile.'
            );
        }
        if (allowedOptionIds == null || allowedOptionIds.isEmpty()) {
            throw newException('CONFIGURATION', null, false, 'The Jira ' + label + ' option allowlist is not configured.');
        }
        if (!allowedOptionIds.contains(optionId.trim())) {
            throw newException('VALIDATION', null, false, 'Jira ' + label + ' option id is not in the configured allowlist.');
        }
    }

    private static String valueOrDefault(String candidate, String defaultValue) {
        return String.isBlank(candidate) ? defaultValue : candidate.trim();
    }

    private static Boolean parseBoolean(String rawValue, Boolean defaultValue) {
        if (String.isBlank(rawValue)) {
            return defaultValue;
        }
        String normalized = rawValue.trim().toLowerCase();
        if (normalized == 'true') {
            return true;
        }
        if (normalized == 'false') {
            return false;
        }
        return defaultValue;
    }

    private static Set<String> parseCsvValues(String rawValue) {
        Set<String> values = new Set<String>();
        if (String.isBlank(rawValue)) {
            return values;
        }
        for (String value : rawValue.split(',')) {
            if (!String.isBlank(value)) {
                values.add(value.trim());
            }
        }
        return values;
    }

    private static void addMissingOrPlaceholderIssue(List<String> issues, String label, String value) {
        if (String.isBlank(value)) {
            issues.add(label + ' is missing.');
            return;
        }
        String normalized = value.trim().toUpperCase();
        if (normalized.startsWith('YOUR_') || normalized.contains('PLACEHOLDER') || normalized == 'TBD') {
            issues.add(label + ' still contains a placeholder value.');
        }
    }

    private static void validateConfiguredFieldKey(List<String> issues, String label, String value) {
        if (String.isBlank(value) || !Pattern.matches('^[A-Za-z][A-Za-z0-9_]*$', value.trim())) {
            issues.add(label + ' is missing or malformed.');
        }
    }

    private static Boolean equalsIgnoreCaseTrimmed(String firstValue, String secondValue) {
        return String.isBlank(firstValue) || String.isBlank(secondValue)
            ? false
            : firstValue.trim().toLowerCase() == secondValue.trim().toLowerCase();
    }

    private static Boolean equalsTrimmed(String firstValue, String secondValue) {
        return String.isBlank(firstValue) || String.isBlank(secondValue)
            ? false
            : firstValue.trim() == secondValue.trim();
    }

    @TestVisible
    private static String extractErrorMessage(HttpResponse response) {
        String defaultMessage = 'Jira callout failed with status ' + response.getStatusCode() + '.';
        if (String.isBlank(response.getBody())) {
            return defaultMessage;
        }

        try {
            Object parsed = JSON.deserializeUntyped(response.getBody());
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> errorMap = (Map<String, Object>) parsed;
                if (errorMap.containsKey('errorMessages')) {
                    List<Object> errorMessages = listValue(errorMap.get('errorMessages'));
                    if (!errorMessages.isEmpty()) {
                        List<String> renderedMessages = new List<String>();
                        for (Object messagePart : errorMessages) {
                            renderedMessages.add(stringValue(messagePart));
                        }
                        return String.join(renderedMessages, ' | ');
                    }
                }
                if (errorMap.containsKey('message')) {
                    return stringValue(errorMap.get('message'));
                }
                if (errorMap.containsKey('errors')) {
                    Map<String, Object> nestedErrors = mapValue(errorMap.get('errors'));
                    if (!nestedErrors.isEmpty()) {
                        List<String> renderedEntries = new List<String>();
                        for (String errorKey : nestedErrors.keySet()) {
                            renderedEntries.add(errorKey + ': ' + stringValue(nestedErrors.get(errorKey)));
                        }
                        return String.join(renderedEntries, ' | ');
                    }
                }
            }
        } catch (Exception ignoredException) {
            // Fall back to the HTTP status-based message below.
            defaultMessage = String.isBlank(defaultMessage)
                ? 'Jira callout failed: ' + ignoredException.getTypeName() + '.'
                : defaultMessage;
        }

        return defaultMessage;
    }

    private static JiraIntegrationException buildHttpException(Integer statusCode) {
        if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
            return newException(
                'VALIDATION',
                statusCode,
                false,
                'Jira rejected the request. Review the issue key and configured field values.'
            );
        }
        if (statusCode == 401) {
            return newException(
                'AUTHENTICATION',
                statusCode,
                false,
                'Jira authentication failed. Ask an administrator to verify the Named Credential.'
            );
        }
        if (statusCode == 403) {
            return newException(
                'AUTHORIZATION',
                statusCode,
                false,
                'The Jira integration user is not allowed to perform this action.'
            );
        }
        if (statusCode == 404) {
            return newException(
                'NOT_FOUND',
                statusCode,
                false,
                'The requested Jira resource was not found in the configured project.'
            );
        }
        if (statusCode == 408 || statusCode == 429) {
            return newException(
                statusCode == 429 ? 'RATE_LIMIT' : 'TIMEOUT',
                statusCode,
                true,
                statusCode == 429
                    ? 'Jira is rate limiting requests. Try the action again later.'
                    : 'The Jira request timed out. Try the action again.'
            );
        }
        if (statusCode >= 500) {
            return newException(
                'AVAILABILITY',
                statusCode,
                true,
                'Jira is temporarily unavailable. Try the action again later.'
            );
        }
        return newException(
            'INTEGRATION',
            statusCode,
            false,
            'The Jira action failed with HTTP status ' + statusCode + '.'
        );
    }

    public static String escapeJql(String rawValue) {
        return escapeJqlLiteral(rawValue);
    }

    public static String adfToText(Object candidate) {
        return adfToPlainText(candidate);
    }

    @TestVisible
    private static String escapeJqlLiteral(String rawValue) {
        return String.isBlank(rawValue) ? '' : rawValue.replace('\\', '\\\\').replace('"', '\\"');
    }

    @TestVisible
    private static String adfToPlainText(Object candidate) {
        List<String> textParts = new List<String>();
        collectAdfText(candidate, textParts);
        return String.join(textParts, ' ').replaceAll('\\s+', ' ').trim();
    }

    private static void collectAdfText(Object candidate, List<String> textParts) {
        if (candidate == null) {
            return;
        }
        if (candidate instanceof List<Object>) {
            for (Object entry : (List<Object>) candidate) {
                collectAdfText(entry, textParts);
            }
            return;
        }
        if (candidate instanceof Map<String, Object>) {
            Map<String, Object> node = (Map<String, Object>) candidate;
            String nodeType = stringValue(node.get('type'));
            if (nodeType == 'text') {
                String textValue = stringValue(node.get('text'));
                if (!String.isBlank(textValue)) {
                    textParts.add(textValue);
                }
            } else if (nodeType == 'hardBreak') {
                textParts.add(' ');
            }

            if (node.containsKey('content')) {
                collectAdfText(node.get('content'), textParts);
            }
        }
    }

    private static JiraActivityEvent newestCommentEvent(Map<String, Object> issueData) {
        JiraActivityEvent newestEvent;
        List<Object> comments = listValue(mapValue(mapValue(issueData.get('fields')).get('comment')).get('comments'));
        for (Object commentEntry : comments) {
            Map<String, Object> commentData = mapValue(commentEntry);
            String summary = summarizeCommentEntry(commentData);
            if (String.isBlank(summary)) {
                continue;
            }

            JiraActivityEvent candidate = new JiraActivityEvent();
            candidate.occurredAt = parseJiraDateTime(stringValue(commentData.get('updated')));
            if (candidate.occurredAt == null) {
                candidate.occurredAt = parseJiraDateTime(stringValue(commentData.get('created')));
            }
            candidate.summary = summary;
            newestEvent = chooseNewerEvent(newestEvent, candidate);
        }
        return newestEvent;
    }

    private static JiraActivityEvent newestHistoryEvent(Map<String, Object> issueData) {
        JiraActivityEvent newestEvent;
        List<Object> histories = listValue(mapValue(issueData.get('changelog')).get('histories'));
        for (Object historyEntry : histories) {
            Map<String, Object> historyData = mapValue(historyEntry);
            String summary = summarizeHistoryEntry(historyData);
            if (String.isBlank(summary)) {
                continue;
            }

            JiraActivityEvent candidate = new JiraActivityEvent();
            candidate.occurredAt = parseJiraDateTime(stringValue(historyData.get('created')));
            candidate.summary = summary;
            newestEvent = chooseNewerEvent(newestEvent, candidate);
        }
        return newestEvent;
    }

    private static JiraActivityEvent chooseNewerEvent(JiraActivityEvent currentEvent, JiraActivityEvent candidateEvent) {
        if (candidateEvent == null || String.isBlank(candidateEvent.summary)) {
            return currentEvent;
        }
        if (currentEvent == null) {
            return candidateEvent;
        }
        if (candidateEvent.occurredAt == null) {
            return currentEvent;
        }
        if (currentEvent.occurredAt == null || candidateEvent.occurredAt.getTime() >= currentEvent.occurredAt.getTime()) {
            return candidateEvent;
        }
        return currentEvent;
    }

    private static Datetime parseJiraDateTime(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            String escapedValue = rawValue.replace('\\', '\\\\').replace('"', '\\"');
            return (Datetime) JSON.deserialize('"' + escapedValue + '"', Datetime.class);
        } catch (Exception ignoredException) {
            String ignoredMessage = ignoredException.getMessage();
            if (!String.isBlank(ignoredMessage)) {
                return null;
            }
            return null;
        }
    }

    private static String summarizeCommentEntry(Map<String, Object> commentData) {
        if (isInternalComment(commentData)) {
            return '';
        }
        String authorName = JiraDirectActionSupport.sanitizeExternalText(
            stringValue(mapValue(commentData.get('author')).get('displayName')),
            120
        );
        String commentBody = JiraDirectActionSupport.sanitizeExternalText(
            adfToPlainText(commentData.get('body')),
            220
        );
        String commentType = determineCommentType(commentData);

        List<String> parts = new List<String>{ commentType };
        if (!String.isBlank(authorName)) {
            parts.add('from ' + authorName);
        }
        String prefix = String.join(parts, ' ');
        return String.isBlank(commentBody) ? prefix : prefix + ': ' + commentBody;
    }

    private static String determineCommentType(Map<String, Object> commentData) {
        if (isInternalComment(commentData)) {
            return 'internal note';
        }
        return 'public comment';
    }

    private static Boolean isInternalComment(Map<String, Object> commentData) {
        String jsdPublicFlag = stringValue(commentData.get('jsdPublic')).toLowerCase();
        if (jsdPublicFlag == 'false') {
            return true;
        }
        if (jsdPublicFlag == 'true') {
            return false;
        }

        String publicFlag = stringValue(commentData.get('public')).toLowerCase();
        if (publicFlag == 'false') {
            return true;
        }
        if (publicFlag == 'true') {
            return false;
        }
        return false;
    }

    private static String summarizeHistoryEntry(Map<String, Object> historyData) {
        List<Object> items = listValue(historyData.get('items'));
        if (items.isEmpty()) {
            return '';
        }

        List<String> renderedChanges = new List<String>();
        for (Object itemEntry : items) {
            Map<String, Object> itemData = mapValue(itemEntry);
            String fieldName = JiraDirectActionSupport.sanitizeExternalText(stringValue(itemData.get('field')), 80);
            if (String.isBlank(fieldName)) {
                continue;
            }

            String fromValue = JiraDirectActionSupport.sanitizeExternalText(stringValue(itemData.get('fromString')), 120);
            String toValue = JiraDirectActionSupport.sanitizeExternalText(stringValue(itemData.get('toString')), 120);
            if (!String.isBlank(fromValue) && !String.isBlank(toValue)) {
                renderedChanges.add(fieldName + ' changed from ' + fromValue + ' to ' + toValue);
            } else if (!String.isBlank(toValue)) {
                renderedChanges.add(fieldName + ' changed to ' + toValue);
            } else if (!String.isBlank(fromValue)) {
                renderedChanges.add(fieldName + ' cleared from ' + fromValue);
            } else {
                renderedChanges.add(fieldName + ' changed');
            }

            if (renderedChanges.size() == 3) {
                break;
            }
        }

        if (renderedChanges.isEmpty()) {
            return '';
        }

        String authorName = JiraDirectActionSupport.sanitizeExternalText(
            stringValue(mapValue(historyData.get('author')).get('displayName')),
            120
        );
        String prefix = String.isBlank(authorName) ? 'field update' : 'field update by ' + authorName;
        return prefix + ': ' + String.join(renderedChanges, '; ');
    }

    private static String shortenText(String rawValue, Integer maxLength) {
        if (String.isBlank(rawValue) || maxLength == null || maxLength <= 0 || rawValue.length() <= maxLength) {
            return rawValue;
        }
        return rawValue.substring(0, maxLength - 3) + '...';
    }
}