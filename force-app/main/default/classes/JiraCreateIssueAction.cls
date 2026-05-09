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
    }

    @InvocableMethod(
        label='Create Jira Issue Direct'
        description='Creates a Jira issue directly through Jira REST using the configured named credential.'
    )
    public static List<Response> createIssue(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            try {
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
                responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(createResult.get('key'));
                responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(createResult.get('id'));
                responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(responseItem.jiraIssueKey);
                responseItem.message = String.isBlank(responseItem.jiraIssueKey)
                    ? 'Jira issue created successfully.'
                    : 'Jira issue ' + responseItem.jiraIssueKey + ' created successfully.';
            } catch (Exception ex) {
                responseItem.isSuccess = false;
                responseItem.message = 'Jira issue creation failed: ' + ex.getMessage();
                responseItem.jiraIssueKey = '';
                responseItem.jiraIssueId = '';
                responseItem.jiraIssueUrl = '';
            }
            responses.add(responseItem);
        }
        return responses;
    }
}
