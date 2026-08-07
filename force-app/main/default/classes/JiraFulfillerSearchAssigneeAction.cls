public with sharing class JiraFulfillerSearchAssigneeAction {
  public class Request {
    @InvocableVariable(label='Jira Issue Key' required=true)
    public String jiraIssueKey;

    @InvocableVariable(label='Query')
    public String query;
  }

  public class Response {
    @InvocableVariable(label='Is Success')
    public Boolean isSuccess;

    @InvocableVariable(label='Message')
    public String message;

    @InvocableVariable(label='Jira Issue Key')
    public String jiraIssueKey;

    @InvocableVariable(label='Candidates Summary')
    public String candidatesSummary;

    @InvocableVariable(label='Candidate Count')
    public Integer candidateCount;

    @InvocableVariable(label='First Account Id')
    public String firstAccountId;

    @InvocableVariable(label='First Display Name')
    public String firstDisplayName;

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
    label='Search Jira Assignees (Fulfiller)'
    description='Finds users who can be assigned to a scoped Jira issue, returning account ids and display names.'
    callout=true
  )
  public static List<Response> searchAssignees(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request requestItem : requests) {
      Response responseItem = new Response();
      responseItem.contentTrust = JiraFulfillerSupport.CONTENT_TRUST;
      try {
        JiraFulfillerSupport.requirePermission(
          JiraFulfillerSupport.PERMISSION_READ
        );
        JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(
          requestItem.jiraIssueKey
        );
        List<Map<String, Object>> candidates = JiraFulfillerSupport.searchAssignableUsers(
          ref,
          requestItem.query
        );

        List<String> rendered = new List<String>();
        for (Map<String, Object> candidate : candidates) {
          String accountId = JiraIntegrationSupport.stringValue(
            candidate.get('accountId')
          );
          String displayName = JiraDirectActionSupport.sanitizeExternalText(
            JiraIntegrationSupport.stringValue(candidate.get('displayName')),
            120
          );
          rendered.add(displayName + ' (' + accountId + ')');
          if (String.isBlank(responseItem.firstAccountId)) {
            responseItem.firstAccountId = accountId;
            responseItem.firstDisplayName = displayName;
          }
        }

        responseItem.isSuccess = true;
        responseItem.jiraIssueKey = ref.normalizedKey;
        responseItem.candidateCount = candidates.size();
        responseItem.candidatesSummary = rendered.isEmpty()
          ? 'No assignable users matched for ' + ref.normalizedKey + '.'
          : String.join(rendered, '\n');
        responseItem.message =
          'Found ' +
          candidates.size() +
          ' assignable user(s) for ' +
          ref.normalizedKey +
          '.';
      } catch (Exception ex) {
        JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(
          ex
        );
        responseItem.isSuccess = false;
        responseItem.errorType = errorInfo.errorType;
        responseItem.statusCode = errorInfo.statusCode;
        responseItem.isRetryable = errorInfo.isRetryable;
        responseItem.candidateCount = 0;
        responseItem.message =
          'Could not search Jira assignees: ' + errorInfo.safeMessage;
      }
      responses.add(responseItem);
    }
    return responses;
  }
}
