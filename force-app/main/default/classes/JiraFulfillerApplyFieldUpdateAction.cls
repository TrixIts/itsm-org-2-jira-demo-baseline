public with sharing class JiraFulfillerApplyFieldUpdateAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;

        @InvocableVariable(label='Confirmation Token' required=true)
        public String confirmationToken;

        @InvocableVariable(label='Confirmed By Employee' required=true)
        public Boolean confirmedByEmployee;
    }

    public class Response {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;

        @InvocableVariable(label='Jira Status')
        public String jiraStatus;

        @InvocableVariable(label='Jira Issue Url')
        public String jiraIssueUrl;

        @InvocableVariable(label='Did Update Fields')
        public Boolean didUpdateFields;

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
        label='Apply Jira Field Update (Fulfiller)'
        description='Applies a previously prepared Jira field update only when a matching, unexpired confirmation token is provided.'
        callout=true
    )
    public static List<Response> apply(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            Long startedAt = Datetime.now().getTime();
            String correlationId = JiraDirectActionSupport.newAuditCorrelation(
                'FulfillerFieldUpdate', requestItem == null ? null : requestItem.jiraIssueKey
            );
            responseItem.correlationId = correlationId;
            try {
                JiraFulfillerSupport.requirePermission(JiraFulfillerSupport.PERMISSION_FIELD_UPDATE);
                if (requestItem.confirmedByEmployee != true) {
                    throw JiraIntegrationSupport.newException(
                        'VALIDATION', null, false, 'The employee must confirm before the Jira field update is applied.'
                    );
                }
                JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(requestItem.jiraIssueKey);
                JiraFulfillerSupport.PendingToken pending = JiraFulfillerSupport.validatePendingToken(
                    'FieldUpdate', requestItem.confirmationToken, ref.normalizedKey
                );
                Map<String, Object> fields = JiraIntegrationSupport.mapValue(pending.details.get('payload'));

                JiraFulfillerSupport.applyFieldUpdate(ref, fields);
                Map<String, Object> refreshed = JiraFulfillerSupport.fetchIssue(ref, null);
                JiraFulfillerSupport.markTokenApplied(pending.recordId);

                responseItem.isSuccess = true;
                responseItem.didUpdateFields = true;
                responseItem.jiraIssueKey = ref.normalizedKey;
                responseItem.jiraStatus = JiraIntegrationSupport.issueStatus(refreshed);
                responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(ref.profile, ref.normalizedKey);
                responseItem.message = 'Jira issue ' + ref.normalizedKey + ' updated successfully.';
                JiraDirectActionSupport.recordTransaction(
                    correlationId, 'FulfillerFieldUpdate', ref.normalizedKey, 'Success', startedAt, null
                );
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.didUpdateFields = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.message = 'Jira field update failed: ' + errorInfo.safeMessage;
                JiraDirectActionSupport.recordTransaction(
                    correlationId, 'FulfillerFieldUpdate', requestItem == null ? null : requestItem.jiraIssueKey, 'Failure', startedAt, errorInfo
                );
            }
            responses.add(responseItem);
        }
        return responses;
    }
}