public with sharing class JiraIntegrationSupport {
    public class JiraConfiguration {
        public String namedCredentialApiName;
        public String projectId;
        public String issueTypeId;
        public String projectKey;
        public String browseBaseUrl;
        public String openIssueJqlClause;
    }

    public class JiraUserMapping {
        public String salesforceUsername;
        public String jiraAccountId;
        public String jiraDisplayName;
    }

    public class JiraIntegrationException extends Exception {}

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

    public static JiraConfiguration getConfiguration() {
        if (configOverride != null) {
            return configOverride;
        }

        Map<String, String> configValuesByKey = new Map<String, String>();
        for (Jira_Demo_Setting__mdt record : [
            SELECT SettingKey__c, SettingValue__c
            FROM Jira_Demo_Setting__mdt
            WHERE SettingType__c = 'Config'
        ]) {
            configValuesByKey.put(record.SettingKey__c, record.SettingValue__c);
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

        List<String> missingKeys = new List<String>();
        if (String.isBlank(config.namedCredentialApiName)) {
            missingKeys.add('NamedCredentialApiName');
        }
        if (String.isBlank(config.projectId)) {
            missingKeys.add('ProjectId');
        }
        if (String.isBlank(config.issueTypeId)) {
            missingKeys.add('IssueTypeId');
        }
        if (!missingKeys.isEmpty()) {
            throw new JiraIntegrationException(
                'Missing Jira demo configuration values: ' + String.join(missingKeys, ', ') +
                '. Add matching Jira_Demo_Setting__mdt config records before running the direct Jira actions.'
            );
        }

        return config;
    }

    public static String resolveSalesforceUsername(String overrideUsername) {
        return String.isBlank(overrideUsername) ? UserInfo.getUserName() : overrideUsername.trim();
    }

    public static JiraUserMapping getRequiredUserMapping(String salesforceUsername) {
        String resolvedUsername = resolveSalesforceUsername(salesforceUsername);

        if (mappingOverridesByUsername != null && mappingOverridesByUsername.containsKey(resolvedUsername)) {
            return mappingOverridesByUsername.get(resolvedUsername);
        }

        List<Jira_Demo_Setting__mdt> records = [
            SELECT SettingKey__c, SettingValue__c, AuxValue__c
            FROM Jira_Demo_Setting__mdt
            WHERE SettingType__c = 'UserMapping'
            AND SettingKey__c = :resolvedUsername
            LIMIT 1
        ];

        if (records.isEmpty() || String.isBlank(records[0].SettingValue__c)) {
            throw new JiraIntegrationException(
                'No Jira reporter mapping is configured for Salesforce username "' + resolvedUsername +
                '". Add a Jira_Demo_Setting__mdt record with SettingType__c = UserMapping, ' +
                'SettingKey__c = the Salesforce username, and SettingValue__c = the Jira accountId.'
            );
        }

        JiraUserMapping mapping = new JiraUserMapping();
        mapping.salesforceUsername = resolvedUsername;
        mapping.jiraAccountId = records[0].SettingValue__c;
        mapping.jiraDisplayName = records[0].AuxValue__c;
        return mapping;
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
        JiraConfiguration config = getConfiguration();
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setTimeout(60000);

        String endpoint = 'callout:' + config.namedCredentialApiName + path;
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

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();

        if (statusCode < 200 || statusCode >= 300) {
            throw new JiraIntegrationException(extractErrorMessage(response));
        }

        if (String.isBlank(response.getBody())) {
            return new Map<String, Object>();
        }

        Object parsed = JSON.deserializeUntyped(response.getBody());
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }

        throw new JiraIntegrationException(
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
            fields.put('customfield_10004', new Map<String, Object>{ 'id' => jiraImpactOptionId });
        }
        if (!String.isBlank(jiraUrgencyOptionId)) {
            fields.put('customfield_10043', new Map<String, Object>{ 'id' => jiraUrgencyOptionId });
        }
        if (!String.isBlank(jiraSeverityOptionId)) {
            fields.put('customfield_10048', new Map<String, Object>{ 'id' => jiraSeverityOptionId });
        }

        return sendRequest(
            'POST',
            '/rest/api/3/issue',
            null,
            new Map<String, Object>{ 'fields' => fields }
        );
    }

    public static Map<String, Object> getIssueByKey(String jiraIssueKey) {
        return sendRequest(
            'GET',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(jiraIssueKey, 'UTF-8'),
            new Map<String, String>{
                'fields' => 'summary,status,reporter,assignee,updated,comment,priority,resolution',
                'expand' => 'changelog'
            },
            null
        );
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

        Integer resolvedMaxResults = (maxResults == null || maxResults <= 0) ? 10 : Math.min(maxResults, 25);

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
        String jiraImpactOptionId,
        String jiraUrgencyOptionId,
        String jiraSeverityOptionId
    ) {
        Map<String, Object> fields = new Map<String, Object>();
        if (!String.isBlank(jiraSummary)) {
            fields.put('summary', jiraSummary);
        }
        if (!String.isBlank(jiraImpactOptionId)) {
            fields.put('customfield_10004', new Map<String, Object>{ 'id' => jiraImpactOptionId });
        }
        if (!String.isBlank(jiraUrgencyOptionId)) {
            fields.put('customfield_10043', new Map<String, Object>{ 'id' => jiraUrgencyOptionId });
        }
        if (!String.isBlank(jiraSeverityOptionId)) {
            fields.put('customfield_10048', new Map<String, Object>{ 'id' => jiraSeverityOptionId });
        }

        if (!fields.isEmpty()) {
            sendRequest(
                'PUT',
                '/rest/api/3/issue/' + EncodingUtil.urlEncode(jiraIssueIdOrKey, 'UTF-8'),
                null,
                new Map<String, Object>{ 'fields' => fields }
            );
        }
    }

    public static void addComment(String jiraIssueIdOrKey, String commentText) {
        if (String.isBlank(commentText)) {
            return;
        }

        sendRequest(
            'POST',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(jiraIssueIdOrKey, 'UTF-8') + '/comment',
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
        String summary = stringValue(fields.get('summary'));
        String status = issueStatus(issueData);
        String priority = issuePriority(issueData);
        String reporter = stringValue(mapValue(fields.get('reporter')).get('displayName'));
        String assignee = stringValue(mapValue(fields.get('assignee')).get('displayName'));
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
        }

        return defaultMessage;
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
            return null;
        }
    }

    private static String summarizeCommentEntry(Map<String, Object> commentData) {
        String authorName = stringValue(mapValue(commentData.get('author')).get('displayName'));
        String commentBody = shortenText(adfToPlainText(commentData.get('body')), 220);
        String commentType = determineCommentType(commentData);

        List<String> parts = new List<String>{ commentType };
        if (!String.isBlank(authorName)) {
            parts.add('from ' + authorName);
        }
        String prefix = String.join(parts, ' ');
        return String.isBlank(commentBody) ? prefix : prefix + ': ' + commentBody;
    }

    private static String determineCommentType(Map<String, Object> commentData) {
        String jsdPublicFlag = stringValue(commentData.get('jsdPublic')).toLowerCase();
        if (jsdPublicFlag == 'false') {
            return 'internal note';
        }
        if (jsdPublicFlag == 'true') {
            return 'public comment';
        }

        String publicFlag = stringValue(commentData.get('public')).toLowerCase();
        if (publicFlag == 'false') {
            return 'internal note';
        }
        if (publicFlag == 'true') {
            return 'public comment';
        }
        return 'comment';
    }

    private static String summarizeHistoryEntry(Map<String, Object> historyData) {
        List<Object> items = listValue(historyData.get('items'));
        if (items.isEmpty()) {
            return '';
        }

        List<String> renderedChanges = new List<String>();
        for (Object itemEntry : items) {
            Map<String, Object> itemData = mapValue(itemEntry);
            String fieldName = stringValue(itemData.get('field'));
            if (String.isBlank(fieldName)) {
                continue;
            }

            String fromValue = stringValue(itemData.get('fromString'));
            String toValue = stringValue(itemData.get('toString'));
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

        String authorName = stringValue(mapValue(historyData.get('author')).get('displayName'));
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