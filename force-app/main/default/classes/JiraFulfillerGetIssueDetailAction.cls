public with sharing class JiraFulfillerGetIssueDetailAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;
    }

    public class Response {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;

        @InvocableVariable(label='Jira Issue Id')
        public String jiraIssueId;

        @InvocableVariable(label='Jira Summary')
        public String jiraSummary;

        @InvocableVariable(label='Jira Status')
        public String jiraStatus;

        @InvocableVariable(label='Jira Priority')
        public String jiraPriority;

        @InvocableVariable(label='Jira Resolution')
        public String jiraResolution;

        @InvocableVariable(label='Is Closed')
        public Boolean isClosed;

        @InvocableVariable(label='Jira Reporter Display Name')
        public String jiraReporterDisplayName;

        @InvocableVariable(label='Jira Assignee Display Name')
        public String jiraAssigneeDisplayName;

        @InvocableVariable(label='Jira Description')
        public String jiraDescription;

        @InvocableVariable(label='Mapped Fields Summary')
        public String mappedFieldsSummary;

        @InvocableVariable(label='Recent Comments Summary')
        public String recentCommentsSummary;

        @InvocableVariable(label='Recent History Summary')
        public String recentHistorySummary;

        @InvocableVariable(label='Jira Issue Url')
        public String jiraIssueUrl;

        @InvocableVariable(label='Content Trust')
        public String contentTrust;

        @InvocableVariable(label='Correlation Id')
        public String correlationId;

        @InvocableVariable(label='Error Type')
        public String errorType;

        @InvocableVariable(label='HTTP Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Is Retryable')
        public Boolean isRetryable;
    }

    @InvocableMethod(
        label='Get Jira Issue Detail (Fulfiller)'
        description='Retrieves full, scope-enforced Jira issue detail including description, mapped fields, comments, and history.'
        callout=true
    )
    public static List<Response> getDetail(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            responseItem.contentTrust = JiraFulfillerSupport.CONTENT_TRUST;
            Long startedAt = Datetime.now().getTime();
            String correlationId = JiraDirectActionSupport.newAuditCorrelation(
                'FulfillerReadIssue',
                requestItem == null ? null : requestItem.jiraIssueKey
            );
            responseItem.correlationId = correlationId;
            try {
                JiraFulfillerSupport.requirePermission(JiraFulfillerSupport.PERMISSION_READ);
                JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(requestItem.jiraIssueKey);
                Map<String, Object> issueData = JiraFulfillerSupport.fetchIssue(ref, null);
                Map<String, Object> fields = JiraIntegrationSupport.mapValue(issueData.get('fields'));

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(issueData.get('key'));
                responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(issueData.get('id'));
                responseItem.jiraSummary = JiraDirectActionSupport.sanitizeExternalText(
                    JiraIntegrationSupport.stringValue(fields.get('summary')), 255
                );
                responseItem.jiraStatus = JiraIntegrationSupport.issueStatus(issueData);
                responseItem.jiraPriority = JiraIntegrationSupport.issuePriority(issueData);
                responseItem.jiraResolution = JiraIntegrationSupport.issueResolution(issueData);
                responseItem.isClosed = JiraIntegrationSupport.isClosedIssue(issueData);
                responseItem.jiraReporterDisplayName = JiraDirectActionSupport.sanitizeExternalText(
                    JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(fields.get('reporter')).get('displayName')), 120
                );
                responseItem.jiraAssigneeDisplayName = JiraDirectActionSupport.sanitizeExternalText(
                    JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(fields.get('assignee')).get('displayName')), 120
                );
                responseItem.jiraDescription = JiraDirectActionSupport.sanitizeExternalText(
                    JiraIntegrationSupport.adfToText(fields.get('description')), 4000
                );
                responseItem.mappedFieldsSummary = JiraFulfillerSupport.renderMappedFields(ref.profile.Connector_Key__c, fields);
                responseItem.recentCommentsSummary = JiraIntegrationSupport.summarizeRecentComments(issueData, 5);
                responseItem.recentHistorySummary = JiraIntegrationSupport.summarizeRecentHistory(issueData, 5);
                responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(ref.profile, responseItem.jiraIssueKey);
                responseItem.message = JiraIntegrationSupport.buildIssueResponseMessage(issueData);
                JiraDirectActionSupport.recordTransaction(
                    correlationId, 'FulfillerReadIssue', responseItem.jiraIssueKey, 'Success', startedAt, null
                );
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.message = 'Jira issue lookup failed: ' + errorInfo.safeMessage;
                JiraDirectActionSupport.recordTransaction(
                    correlationId, 'FulfillerReadIssue', requestItem == null ? null : requestItem.jiraIssueKey, 'Failure', startedAt, errorInfo
                );
            }
            responses.add(responseItem);
        }
        return responses;
    }
}