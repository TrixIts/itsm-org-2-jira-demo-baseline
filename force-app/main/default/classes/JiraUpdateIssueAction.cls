public with sharing class JiraUpdateIssueAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Id Or Key' required=true)
        public String jiraIssueIdOrKey;

        @InvocableVariable(label='Jira Summary')
        public String jiraSummary;

        @InvocableVariable(label='Jira Impact Option Id')
        public String jiraImpactOptionId;

        @InvocableVariable(label='Jira Urgency Option Id')
        public String jiraUrgencyOptionId;

        @InvocableVariable(label='Jira Severity Option Id')
        public String jiraSeverityOptionId;

        @InvocableVariable(label='Comment Text')
        public String commentText;
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

        @InvocableVariable(label='Jira Issue Url')
        public String jiraIssueUrl;

        @InvocableVariable(label='Did Update Fields')
        public Boolean didUpdateFields;

        @InvocableVariable(label='Did Add Comment')
        public Boolean didAddComment;
    }

    @InvocableMethod(
        label='Update Jira Issue Direct'
        description='Updates Jira fields and optionally adds a Jira comment directly through Jira REST.'
    )
    public static List<Response> updateIssue(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            try {
                Boolean hasFieldUpdate =
                    !String.isBlank(requestItem.jiraSummary) ||
                    !String.isBlank(requestItem.jiraImpactOptionId) ||
                    !String.isBlank(requestItem.jiraUrgencyOptionId) ||
                    !String.isBlank(requestItem.jiraSeverityOptionId);
                Boolean hasComment = !String.isBlank(requestItem.commentText);

                if (!hasFieldUpdate && !hasComment) {
                    throw new JiraIntegrationSupport.JiraIntegrationException(
                        'Provide at least one Jira field update or a comment before calling the direct Jira update action.'
                    );
                }

                JiraIntegrationSupport.updateIssue(
                    requestItem.jiraIssueIdOrKey,
                    requestItem.jiraSummary,
                    requestItem.jiraImpactOptionId,
                    requestItem.jiraUrgencyOptionId,
                    requestItem.jiraSeverityOptionId
                );
                JiraIntegrationSupport.addComment(requestItem.jiraIssueIdOrKey, requestItem.commentText);

                Map<String, Object> refreshedIssue = JiraIntegrationSupport.getIssueByKey(requestItem.jiraIssueIdOrKey);
                Map<String, Object> fields = JiraIntegrationSupport.mapValue(refreshedIssue.get('fields'));

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(refreshedIssue.get('key'));
                responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(refreshedIssue.get('id'));
                responseItem.jiraSummary = JiraIntegrationSupport.stringValue(fields.get('summary'));
                responseItem.jiraStatus = JiraIntegrationSupport.stringValue(
                    JiraIntegrationSupport.mapValue(fields.get('status')).get('name')
                );
                responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(responseItem.jiraIssueKey);
                responseItem.didUpdateFields = hasFieldUpdate;
                responseItem.didAddComment = hasComment;

                List<String> actionsTaken = new List<String>();
                if (hasFieldUpdate) {
                    actionsTaken.add('updated');
                }
                if (hasComment) {
                    actionsTaken.add('commented');
                }

                responseItem.message = 'Jira issue ' + responseItem.jiraIssueKey + ' ' +
                    String.join(actionsTaken, ' and ') + ' successfully.';
            } catch (Exception ex) {
                responseItem.isSuccess = false;
                responseItem.message = 'Jira issue update failed: ' + ex.getMessage();
                responseItem.jiraIssueKey = '';
                responseItem.jiraIssueId = '';
                responseItem.jiraSummary = '';
                responseItem.jiraStatus = '';
                responseItem.jiraIssueUrl = '';
                responseItem.didUpdateFields = false;
                responseItem.didAddComment = false;
            }
            responses.add(responseItem);
        }
        return responses;
    }
}
