public with sharing class JiraGetIssueByKeyAction {
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

        @InvocableVariable(label='Jira Issue Url')
        public String jiraIssueUrl;

        @InvocableVariable(label='Latest Update Summary')
        public String latestUpdateSummary;

        @InvocableVariable(label='Recent Comments Summary')
        public String recentCommentsSummary;

        @InvocableVariable(label='Recent History Summary')
        public String recentHistorySummary;
    }

    @InvocableMethod(
        label='Get Jira Issue By Key Direct'
        description='Retrieves a Jira issue directly by Jira key through Jira REST.'
    )
    public static List<Response> getIssue(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            try {
                Map<String, Object> issueData = JiraIntegrationSupport.getIssueByKey(requestItem.jiraIssueKey);
                Map<String, Object> fields = JiraIntegrationSupport.mapValue(issueData.get('fields'));

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(issueData.get('key'));
                responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(issueData.get('id'));
                responseItem.jiraSummary = JiraIntegrationSupport.stringValue(fields.get('summary'));
                responseItem.jiraStatus = JiraIntegrationSupport.issueStatus(issueData);
                responseItem.jiraPriority = JiraIntegrationSupport.issuePriority(issueData);
                responseItem.jiraResolution = JiraIntegrationSupport.issueResolution(issueData);
                responseItem.isClosed = JiraIntegrationSupport.isClosedIssue(issueData);
                responseItem.jiraReporterDisplayName = JiraIntegrationSupport.stringValue(
                    JiraIntegrationSupport.mapValue(fields.get('reporter')).get('displayName')
                );
                responseItem.jiraAssigneeDisplayName = JiraIntegrationSupport.stringValue(
                    JiraIntegrationSupport.mapValue(fields.get('assignee')).get('displayName')
                );
                responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(responseItem.jiraIssueKey);
                responseItem.latestUpdateSummary = JiraIntegrationSupport.describeLatestUpdate(issueData);
                responseItem.recentCommentsSummary = JiraIntegrationSupport.summarizeRecentComments(issueData, 3);
                responseItem.recentHistorySummary = JiraIntegrationSupport.summarizeRecentHistory(issueData, 3);
                responseItem.message = JiraIntegrationSupport.buildIssueResponseMessage(issueData);
            } catch (Exception ex) {
                responseItem.isSuccess = false;
                responseItem.message = 'Jira issue lookup failed: ' + ex.getMessage();
            }
            responses.add(responseItem);
        }
        return responses;
    }
}