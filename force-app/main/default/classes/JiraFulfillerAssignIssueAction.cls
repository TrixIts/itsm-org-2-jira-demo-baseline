public with sharing class JiraFulfillerAssignIssueAction {
  public class Request {
    @InvocableVariable(label='Jira Issue Key' required=true)
    public String jiraIssueKey;

    @InvocableVariable(label='Assignee Account Id' required=true)
    public String assigneeAccountId;

    @InvocableVariable(label='Confirmed By Employee' required=true)
    public Boolean confirmedByEmployee;

    @InvocableVariable(label='Confirmed Jira Issue Key')
    public String confirmedJiraIssueKey;

    @InvocableVariable(label='Confirmed Assignee Account Id' required=true)
    public String confirmedAssigneeAccountId;
  }

  public class Response {
    @InvocableVariable(label='Is Success')
    public Boolean isSuccess;

    @InvocableVariable(label='Message')
    public String message;

    @InvocableVariable(label='Jira Issue Key')
    public String jiraIssueKey;

    @InvocableVariable(label='Jira Assignee Display Name')
    public String jiraAssigneeDisplayName;

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
    label='Assign Jira Issue (Fulfiller)'
    description='Assigns a scoped Jira issue to a confirmed Jira account after explicit employee confirmation.'
    callout=true
  )
  public static List<Response> assignIssue(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request requestItem : requests) {
      Response responseItem = new Response();
      Long startedAt = Datetime.now().getTime();
      String correlationId = JiraDirectActionSupport.newAuditCorrelation(
        'FulfillerAssign',
        requestItem == null ? null : requestItem.jiraIssueKey
      );
      responseItem.correlationId = correlationId;
      try {
        JiraFulfillerSupport.requirePermission(
          JiraFulfillerSupport.PERMISSION_ASSIGN
        );
        JiraFulfillerSupport.IssueRef ref = JiraFulfillerSupport.validateAndResolveIssueKey(
          requestItem.jiraIssueKey
        );
        if (requestItem.confirmedByEmployee != true) {
          throw JiraIntegrationSupport.newException(
            'VALIDATION',
            null,
            false,
            'The employee must confirm the Jira assignment before it is applied.'
          );
        }
        if (
          !String.isBlank(requestItem.confirmedJiraIssueKey) &&
          !ref.normalizedKey.equalsIgnoreCase(
            requestItem.confirmedJiraIssueKey.trim()
          )
        ) {
          throw JiraIntegrationSupport.newException(
            'VALIDATION',
            null,
            false,
            'The confirmed Jira issue key does not match the requested issue.'
          );
        }
        if (
          String.isBlank(requestItem.assigneeAccountId) ||
          requestItem.assigneeAccountId.trim() !=
          String.valueOf(requestItem.confirmedAssigneeAccountId).trim()
        ) {
          throw JiraIntegrationSupport.newException(
            'VALIDATION',
            null,
            false,
            'The confirmed assignee account id must match the assignee being set.'
          );
        }

        JiraFulfillerSupport.assignIssue(
          ref,
          requestItem.assigneeAccountId.trim()
        );
        Map<String, Object> refreshed = JiraFulfillerSupport.fetchIssue(
          ref,
          null
        );
        Map<String, Object> fields = JiraIntegrationSupport.mapValue(
          refreshed.get('fields')
        );

        responseItem.isSuccess = true;
        responseItem.jiraIssueKey = ref.normalizedKey;
        responseItem.jiraAssigneeDisplayName = JiraDirectActionSupport.sanitizeExternalText(
          JiraIntegrationSupport.stringValue(
            JiraIntegrationSupport.mapValue(fields.get('assignee'))
              .get('displayName')
          ),
          120
        );
        responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(
          ref.profile,
          ref.normalizedKey
        );
        responseItem.message =
          'Jira issue ' +
          ref.normalizedKey +
          ' assigned successfully' +
          (String.isBlank(responseItem.jiraAssigneeDisplayName)
            ? '.'
            : ' to ' + responseItem.jiraAssigneeDisplayName + '.');
        JiraDirectActionSupport.recordTransaction(
          correlationId,
          'FulfillerAssign',
          ref.normalizedKey,
          'Success',
          startedAt,
          null
        );
      } catch (Exception ex) {
        JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(
          ex
        );
        responseItem.isSuccess = false;
        responseItem.errorType = errorInfo.errorType;
        responseItem.statusCode = errorInfo.statusCode;
        responseItem.isRetryable = errorInfo.isRetryable;
        responseItem.message =
          'Jira assignment failed: ' + errorInfo.safeMessage;
        JiraDirectActionSupport.recordTransaction(
          correlationId,
          'FulfillerAssign',
          requestItem == null ? null : requestItem.jiraIssueKey,
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
