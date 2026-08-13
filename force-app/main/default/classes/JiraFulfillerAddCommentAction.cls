public with sharing class JiraFulfillerAddCommentAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;

        @InvocableVariable(label='Comment Text' required=true)
        public String commentText;

        @InvocableVariable(label='Confirmed By Employee' required=true)
        public Boolean confirmedByEmployee;

        @InvocableVariable(label='Confirmed Jira Issue Key')
        public String confirmedJiraIssueKey;

        @InvocableVariable(label='Confirmed Comment Text' required=true)
        public String confirmedCommentText;
    }

    public class Response {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;

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
        label='Add Jira Comment (Fulfiller)'
        description='Adds an employee-confirmed public Jira comment to a scoped issue in any allowed project.'
        callout=true
    )
    public static List<Response> addComment(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            Long startedAt = Datetime.now().getTime();
            String correlationId;
            try {
                JiraFulfillerSupport.requirePermission(JiraFulfillerSupport.PERMISSION_COMMENT);
                JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(requestItem.jiraIssueKey);
                JiraDirectActionSupport.validateComment(requestItem.commentText);
                correlationId = JiraDirectActionSupport.buildCommentCorrelationKey(ref.normalizedKey, requestItem.commentText);
                responseItem.correlationId = correlationId;

                Jira_Integration_Transaction__c existing = JiraDirectActionSupport.findSuccessfulTransaction(correlationId);
                if (existing != null) {
                    responseItem.isSuccess = true;
                    responseItem.isDuplicate = true;
                    responseItem.jiraIssueKey = ref.normalizedKey;
                    responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(ref.profile, ref.normalizedKey);
                    responseItem.message = 'This confirmed comment was already added to Jira issue ' + ref.normalizedKey + '.';
                    responses.add(responseItem);
                    continue;
                }

                JiraIntegrationSupport.validateWriteConfirmation(
                    ref.normalizedKey, requestItem.confirmedByEmployee, requestItem.confirmedJiraIssueKey,
                    requestItem.commentText, requestItem.confirmedCommentText
                );
                JiraFulfillerSupport.addComment(ref, requestItem.commentText);

                responseItem.isSuccess = true;
                responseItem.isDuplicate = false;
                responseItem.jiraIssueKey = ref.normalizedKey;
                responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(ref.profile, ref.normalizedKey);
                responseItem.message = 'Comment added to Jira issue ' + ref.normalizedKey + ' successfully.';
                JiraDirectActionSupport.recordTransaction(
                    correlationId, 'FulfillerComment', ref.normalizedKey, 'Success', startedAt, null
                );
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.isDuplicate = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.message = 'Jira comment failed: ' + errorInfo.safeMessage;
                JiraDirectActionSupport.recordTransaction(
                    String.isBlank(correlationId) ? JiraDirectActionSupport.newAuditCorrelation('FulfillerComment', requestItem.jiraIssueKey) : correlationId,
                    'FulfillerComment', requestItem == null ? null : requestItem.jiraIssueKey, 'Failure', startedAt, errorInfo
                );
            }
            responses.add(responseItem);
        }
        return responses;
    }
}