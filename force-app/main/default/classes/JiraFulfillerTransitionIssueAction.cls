public with sharing class JiraFulfillerTransitionIssueAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;

        @InvocableVariable(label='Transition Id' required=true)
        public String transitionId;

        @InvocableVariable(label='Confirmed By Employee' required=true)
        public Boolean confirmedByEmployee;

        @InvocableVariable(label='Confirmed Jira Issue Key')
        public String confirmedJiraIssueKey;

        @InvocableVariable(label='Confirmed Transition Id' required=true)
        public String confirmedTransitionId;
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
        label='Transition Jira Issue (Fulfiller)'
        description='Moves a scoped Jira issue through a valid workflow transition after explicit employee confirmation.'
        callout=true
    )
    public static List<Response> transitionIssue(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            Long startedAt = Datetime.now().getTime();
            String correlationId = JiraDirectActionSupport.newAuditCorrelation(
                'FulfillerTransition', requestItem == null ? null : requestItem.jiraIssueKey
            );
            responseItem.correlationId = correlationId;
            try {
                JiraFulfillerSupport.requirePermission(JiraFulfillerSupport.PERMISSION_TRANSITION);
                JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(requestItem.jiraIssueKey);
                if (requestItem.confirmedByEmployee != true) {
                    throw JiraIntegrationSupport.newException('VALIDATION', null, false, 'The employee must confirm the Jira transition before it is applied.');
                }
                if (!String.isBlank(requestItem.confirmedJiraIssueKey) &&
                    !ref.normalizedKey.equalsIgnoreCase(requestItem.confirmedJiraIssueKey.trim())) {
                    throw JiraIntegrationSupport.newException('VALIDATION', null, false, 'The confirmed Jira issue key does not match the requested issue.');
                }
                if (String.isBlank(requestItem.transitionId) ||
                    requestItem.transitionId.trim() != String.valueOf(requestItem.confirmedTransitionId).trim()) {
                    throw JiraIntegrationSupport.newException('VALIDATION', null, false, 'The confirmed transition id must match the transition being applied.');
                }

                Boolean valid = false;
                for (Map<String, Object> transition : JiraFulfillerSupport.getTransitions(ref)) {
                    if (JiraIntegrationSupport.stringValue(transition.get('id')) == requestItem.transitionId.trim()) {
                        valid = true;
                        break;
                    }
                }
                if (!valid) {
                    throw JiraIntegrationSupport.newException('VALIDATION', null, false, 'Transition ' + requestItem.transitionId + ' is not currently valid for ' + ref.normalizedKey + '.');
                }

                JiraFulfillerSupport.applyTransition(ref, requestItem.transitionId.trim());
                Map<String, Object> refreshed = JiraFulfillerSupport.fetchIssue(ref, null);

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = ref.normalizedKey;
                responseItem.jiraStatus = JiraIntegrationSupport.issueStatus(refreshed);
                responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(ref.profile, ref.normalizedKey);
                responseItem.message = 'Jira issue ' + ref.normalizedKey + ' moved to status ' + responseItem.jiraStatus + '.';
                JiraDirectActionSupport.recordTransaction(correlationId, 'FulfillerTransition', ref.normalizedKey, 'Success', startedAt, null);
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.message = 'Jira transition failed: ' + errorInfo.safeMessage;
                JiraDirectActionSupport.recordTransaction(correlationId, 'FulfillerTransition', requestItem == null ? null : requestItem.jiraIssueKey, 'Failure', startedAt, errorInfo);
            }
            responses.add(responseItem);
        }
        return responses;
    }
}