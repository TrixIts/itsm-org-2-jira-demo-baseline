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

        @InvocableVariable(label='Content Trust')
        public String contentTrust;

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
        label='Get My Open Jira Issues Direct'
        description='Finds open Jira issues for the mapped reporter by resolving Salesforce username to Jira accountId.'
    )
    public static List<Response> getMyOpenIssues(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            Long startedAt = Datetime.now().getTime();
            String correlationId = JiraDirectActionSupport.newAuditCorrelation('SearchIssues', null);
            responseItem.correlationId = correlationId;
            try {
                JiraDirectActionSupport.requirePermission(JiraDirectActionSupport.PERMISSION_READ);
                String resolvedUsername = JiraIntegrationSupport.resolveSalesforceUsername(
                    requestItem.reporterSalesforceUsername
                );
                JiraIntegrationSupport.JiraUserMapping reporterMapping =
                    JiraIntegrationSupport.getRequiredUserMapping(requestItem.reporterSalesforceUsername);
                Map<String, Object> searchResult = JiraIntegrationSupport.searchIssuesForReporter(
                    requestItem.reporterSalesforceUsername,
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
                    renderedIssues.add(JiraIntegrationSupport.summarizeIssueForList(detailedIssue));
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
                responseItem.contentTrust = 'UNTRUSTED_EXTERNAL_DATA';
                responseItem.message = renderedIssues.isEmpty()
                    ? 'No open Jira issues were found for the configured reporter.'
                    : 'Found ' + String.valueOf(issues.size()) + ' open Jira issue(s).' +
                        (issues.size() == 1 && !String.isBlank(firstIssueLatestUpdateSummary)
                            ? ' Latest update: ' + firstIssueLatestUpdateSummary + '.'
                            : '');
                JiraDirectActionSupport.recordTransaction(
                    correlationId,
                    'SearchIssues',
                    firstIssueKey,
                    'Success',
                    startedAt,
                    null
                );
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.contentTrust = 'UNTRUSTED_EXTERNAL_DATA';
                responseItem.message = 'Jira reporter lookup failed: ' + errorInfo.safeMessage;
                responseItem.reporterSalesforceUsername = JiraIntegrationSupport.resolveSalesforceUsername(
                    requestItem.reporterSalesforceUsername
                );
                responseItem.jiraAccountId = '';
                responseItem.issueCount = 0;
                responseItem.issuesSummary = '';
                responseItem.firstJiraIssueKey = '';
                responseItem.firstIssueLatestUpdateSummary = '';
                responseItem.firstIssuePriority = '';
                JiraDirectActionSupport.recordTransaction(
                    correlationId,
                    'SearchIssues',
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