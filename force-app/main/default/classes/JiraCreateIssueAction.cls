public with sharing class JiraCreateIssueAction {
    public class Request {
        @InvocableVariable(label='Jira Summary' required=true)
        public String jiraSummary;

        @InvocableVariable(label='Jira Description' required=true)
        public String jiraDescription;

        @InvocableVariable(label='Jira Priority')
        public String jiraPriority;

        @InvocableVariable(label='Jira Urgency Option Id')
        public String jiraUrgencyOptionId;

        @InvocableVariable(label='Jira Impact Option Id')
        public String jiraImpactOptionId;

        @InvocableVariable(label='Jira Severity Option Id')
        public String jiraSeverityOptionId;

        @InvocableVariable(label='Requester Email')
        public String requesterEmail;

        @InvocableVariable(label='Channel')
        public String channel;

        @InvocableVariable(label='Source Reference')
        public String sourceReference;

        @InvocableVariable(label='Reporter Salesforce Username')
        public String reporterSalesforceUsername;
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

        @InvocableVariable(label='Jira Issue Url')
        public String jiraIssueUrl;

        @InvocableVariable(label='Correlation Id')
        public String correlationId;

        @InvocableVariable(label='Is Duplicate')
        public Boolean isDuplicate;

        @InvocableVariable(label='Error Type')
        public String errorType;

        @InvocableVariable(label='HTTP Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Is Retryable')
        public Boolean isRetryable;
    }

    @InvocableMethod(
        label='Create Jira Issue Direct'
        description='Creates a Jira issue directly through Jira REST using the configured named credential.'
    )
    public static List<Response> createIssue(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            Long startedAt = Datetime.now().getTime();
            String correlationId;
            try {
                JiraDirectActionSupport.requirePermission(JiraDirectActionSupport.PERMISSION_CREATE);
                JiraDirectActionSupport.validateCreateInputs(
                    requestItem.jiraSummary,
                    requestItem.jiraDescription,
                    requestItem.jiraPriority,
                    requestItem.requesterEmail,
                    requestItem.channel,
                    requestItem.sourceReference
                );
                correlationId = JiraDirectActionSupport.buildCreateCorrelationKey(
                    requestItem.sourceReference,
                    requestItem.jiraSummary,
                    requestItem.jiraDescription,
                    requestItem.requesterEmail
                );
                responseItem.correlationId = correlationId;
                Jira_Integration_Transaction__c existingTransaction =
                    JiraDirectActionSupport.findSuccessfulTransaction(correlationId);
                if (existingTransaction != null) {
                    responseItem.isSuccess = true;
                    responseItem.isDuplicate = true;
                    responseItem.jiraIssueKey = existingTransaction.Jira_Issue_Key__c;
                    responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(responseItem.jiraIssueKey);
                    responseItem.message = 'This request was already submitted as Jira issue ' +
                        responseItem.jiraIssueKey + '.';
                    responses.add(responseItem);
                    continue;
                }
                Map<String, Object> createResult = JiraIntegrationSupport.createIssue(
                    requestItem.jiraSummary,
                    requestItem.jiraDescription,
                    requestItem.jiraPriority,
                    requestItem.jiraUrgencyOptionId,
                    requestItem.jiraImpactOptionId,
                    requestItem.jiraSeverityOptionId,
                    requestItem.requesterEmail,
                    requestItem.channel,
                    requestItem.sourceReference,
                    requestItem.reporterSalesforceUsername
                );

                responseItem.isSuccess = true;
                responseItem.isDuplicate = false;
                responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(createResult.get('key'));
                responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(createResult.get('id'));
                responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(responseItem.jiraIssueKey);
                responseItem.message = String.isBlank(responseItem.jiraIssueKey)
                    ? 'Jira issue created successfully.'
                    : 'Jira issue ' + responseItem.jiraIssueKey + ' created successfully.';
                JiraDirectActionSupport.recordTransaction(
                    correlationId,
                    'Create',
                    responseItem.jiraIssueKey,
                    'Success',
                    startedAt,
                    null
                );
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.isDuplicate = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.message = 'Jira issue creation failed: ' + errorInfo.safeMessage;
                responseItem.jiraIssueKey = '';
                responseItem.jiraIssueId = '';
                responseItem.jiraIssueUrl = '';
                JiraDirectActionSupport.recordTransaction(
                    String.isBlank(correlationId)
                        ? JiraDirectActionSupport.newAuditCorrelation('Create', null)
                        : correlationId,
                    'Create',
                    null,
                    'Failure',
                    startedAt,
                    errorInfo
                );
            }
            responses.add(responseItem);
        }
        return responses;
    }
}