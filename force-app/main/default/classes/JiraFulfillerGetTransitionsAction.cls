public with sharing class JiraFulfillerGetTransitionsAction {
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

        @InvocableVariable(label='Transitions Summary')
        public String transitionsSummary;

        @InvocableVariable(label='Transition Count')
        public Integer transitionCount;

        @InvocableVariable(label='First Transition Id')
        public String firstTransitionId;

        @InvocableVariable(label='First Transition Name')
        public String firstTransitionName;

        @InvocableVariable(label='Content Trust')
        public String contentTrust;

        @InvocableVariable(label='Error Type')
        public String errorType;

        @InvocableVariable(label='HTTP Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Is Retryable')
        public Boolean isRetryable;
    }

    @InvocableMethod(
        label='Get Jira Transitions (Fulfiller)'
        description='Lists the valid workflow transitions currently available for a scoped Jira issue.'
        callout=true
    )
    public static List<Response> getTransitions(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            responseItem.contentTrust = JiraFulfillerSupport.CONTENT_TRUST;
            try {
                JiraFulfillerSupport.requirePermission(JiraFulfillerSupport.PERMISSION_READ);
                JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(requestItem.jiraIssueKey);
                List<Map<String, Object>> transitions = JiraFulfillerSupport.getTransitions(ref);

                List<String> rendered = new List<String>();
                for (Map<String, Object> transition : transitions) {
                    String id = JiraIntegrationSupport.stringValue(transition.get('id'));
                    String name = JiraDirectActionSupport.sanitizeExternalText(JiraIntegrationSupport.stringValue(transition.get('name')), 80);
                    String toName = JiraDirectActionSupport.sanitizeExternalText(JiraIntegrationSupport.stringValue(transition.get('to')), 80);
                    rendered.add(id + ': ' + name + (String.isBlank(toName) ? '' : ' -> ' + toName));
                    if (String.isBlank(responseItem.firstTransitionId)) {
                        responseItem.firstTransitionId = id;
                        responseItem.firstTransitionName = name;
                    }
                }

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = ref.normalizedKey;
                responseItem.transitionCount = transitions.size();
                responseItem.transitionsSummary = rendered.isEmpty()
                    ? 'No workflow transitions are currently available for ' + ref.normalizedKey + '.'
                    : String.join(rendered, '\n');
                responseItem.message = 'Found ' + transitions.size() + ' available transition(s) for ' + ref.normalizedKey + '.';
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.transitionCount = 0;
                responseItem.message = 'Could not load Jira transitions: ' + errorInfo.safeMessage;
            }
            responses.add(responseItem);
        }
        return responses;
    }
}