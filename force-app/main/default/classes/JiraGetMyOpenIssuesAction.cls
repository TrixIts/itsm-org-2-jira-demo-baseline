public with sharing class JiraGetMyOpenIssuesAction {
    public class Request {
        @InvocableVariable(label='Reporter Salesforce Username')
        public String reporterSalesforceUsername;

        @InvocableVariable(label='Max Results')
        public Integer maxResults;
    }

    public class Response {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Reporter Salesforce Username')
        public String reporterSalesforceUsername;

        @InvocableVariable(label='Jira Account Id')
        public String jiraAccountId;

        @InvocableVariable(label='Issue Count')
        public Integer issueCount;

        @InvocableVariable(label='Issues Summary')
        public String issuesSummary;

        @InvocableVariable(label='First Jira Issue Key')
        public String firstJiraIssueKey;

        @InvocableVariable(label='First Issue Latest Update Summary')
        public String firstIssueLatestUpdateSummary;

        @InvocableVariable(label='First Issue Priority')
        public String firstIssuePriority;
    }

    @InvocableMethod(
        label='Get My Open Jira Issues Direct'
        description='Finds open Jira issues for the mapped reporter by resolving Salesforce username to Jira accountId.'
    )
    public static List<Response> getMyOpenIssues(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            try {
                String resolvedUsername = JiraIntegrationSupport.resolveSalesforceUsername(
                    requestItem.reporterSalesforceUsername
                );
                JiraIntegrationSupport.JiraUserMapping reporterMapping =
                    JiraIntegrationSupport.getRequiredUserMapping(resolvedUsername);
                Map<String, Object> searchResult = JiraIntegrationSupport.searchIssuesForReporter(
                    resolvedUsername,
                    requestItem.maxResults
                );
                List<Object> issues = JiraIntegrationSupport.listValue(searchResult.get('issues'));
                List<String> renderedIssues = new List<String>();
                String firstIssueKey = '';
                String firstIssueLatestUpdateSummary = '';
                String firstIssuePriority = '';

                for (Object issueEntry : issues) {
                    Map<String, Object> issueMap = JiraIntegrationSupport.mapValue(issueEntry);
                    String issueKey = JiraIntegrationSupport.stringValue(issueMap.get('key'));
                    Map<String, Object> detailedIssue = String.isBlank(issueKey)
                        ? issueMap
                        : JiraIntegrationSupport.getIssueByKey(issueKey);
                    renderedIssues.add(JiraIntegrationSupport.summarizeIssueWithLatestUpdate(detailedIssue));
                    if (String.isBlank(firstIssueKey)) {
                        firstIssueKey = JiraIntegrationSupport.stringValue(detailedIssue.get('key'));
                        firstIssueLatestUpdateSummary = JiraIntegrationSupport.describeLatestUpdate(detailedIssue);
                        firstIssuePriority = JiraIntegrationSupport.issuePriority(detailedIssue);
                    }
                }

                responseItem.isSuccess = true;
                responseItem.reporterSalesforceUsername = resolvedUsername;
                responseItem.jiraAccountId = reporterMapping.jiraAccountId;
                responseItem.issueCount = issues.size();
                responseItem.issuesSummary = renderedIssues.isEmpty()
                    ? 'I did not find any open Jira issues for ' + resolvedUsername + '.'
                    : String.join(renderedIssues, '\n');
                responseItem.firstJiraIssueKey = firstIssueKey;
                responseItem.firstIssueLatestUpdateSummary = firstIssueLatestUpdateSummary;
                responseItem.firstIssuePriority = firstIssuePriority;
                responseItem.message = renderedIssues.isEmpty()
                    ? 'I did not find any open Jira issues for ' + resolvedUsername + '.'
                    : 'I found ' + String.valueOf(issues.size()) + ' open Jira issue(s) for ' + resolvedUsername + '.' +
                        (issues.size() == 1 && !String.isBlank(firstIssueLatestUpdateSummary)
                            ? ' Latest update: ' + firstIssueLatestUpdateSummary + '.'
                            : '');
            } catch (Exception ex) {
                responseItem.isSuccess = false;
                responseItem.message = 'Jira reporter lookup failed: ' + ex.getMessage();
                responseItem.reporterSalesforceUsername = JiraIntegrationSupport.resolveSalesforceUsername(
                    requestItem.reporterSalesforceUsername
                );
                responseItem.jiraAccountId = '';
                responseItem.issueCount = 0;
                responseItem.issuesSummary = '';
                responseItem.firstJiraIssueKey = '';
                responseItem.firstIssueLatestUpdateSummary = '';
                responseItem.firstIssuePriority = '';
            }
            responses.add(responseItem);
        }
        return responses;
    }
}
