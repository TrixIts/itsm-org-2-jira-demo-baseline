public with sharing class JiraFulfillerPrepareFieldUpdateAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;

        @InvocableVariable(
            label='Changes JSON'
            description='JSON object of field alias to value, e.g. {"summary":"New title","priority":"High"}.'
            required=true
        )
        public String changesJson;
    }

    public class Response {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;

        @InvocableVariable(label='Preview Text')
        public String previewText;

        @InvocableVariable(label='Confirmation Token')
        public String confirmationToken;

        @InvocableVariable(label='Token Expires In Minutes')
        public Integer tokenExpiresInMinutes;

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
        label='Prepare Jira Field Update (Fulfiller)'
        description='Validates administrator-allowlisted field changes and returns an exact preview plus a short-lived confirmation token.'
        callout=true
    )
    public static List<Response> prepare(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            responseItem.contentTrust = JiraFulfillerSupport.CONTENT_TRUST;
            try {
                JiraFulfillerSupport.requirePermission(JiraFulfillerSupport.PERMISSION_FIELD_UPDATE);
                JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(requestItem.jiraIssueKey);
                Map<String, Object> requestedChanges = parseChanges(requestItem.changesJson);

                Map<String, Object> issueData = JiraFulfillerSupport.fetchIssue(ref, null);
                if (JiraIntegrationSupport.isClosedIssue(issueData)) {
                    throw JiraIntegrationSupport.newException(
                        'VALIDATION', null, false,
                        'Jira issue ' + ref.normalizedKey + ' is closed. Reopen it via a transition or add a comment instead of editing fields.'
                    );
                }

                JiraFulfillerSupport.PreparedUpdate prepared = JiraFulfillerSupport.prepareFieldUpdate(ref, requestedChanges);
                String preview = 'Apply to ' + ref.normalizedKey + ': ' + String.join(prepared.previewLines, '; ') + '.';
                String token = JiraFulfillerSupport.createPendingToken('FieldUpdate', ref, prepared.fields, preview);

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = ref.normalizedKey;
                responseItem.previewText = preview;
                responseItem.confirmationToken = token;
                responseItem.tokenExpiresInMinutes = 15;
                responseItem.message = 'Review this change and confirm to apply it: ' + preview;
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.message = 'Could not prepare the Jira field update: ' + errorInfo.safeMessage;
            }
            responses.add(responseItem);
        }
        return responses;
    }

    private static Map<String, Object> parseChanges(String changesJson) {
        if (String.isBlank(changesJson)) {
            throw JiraIntegrationSupport.newException('VALIDATION', null, false, 'Provide the field changes to preview.');
        }
        try {
            Object parsed = JSON.deserializeUntyped(changesJson);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
        } catch (Exception ignored) {
            // fall through to the validation error below
        }
        throw JiraIntegrationSupport.newException(
            'VALIDATION', null, false, 'Changes JSON must be a JSON object of field name to value.'
        );
    }
}