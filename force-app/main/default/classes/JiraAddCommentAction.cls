public with sharing class JiraAddCommentAction {
  public class Request {
    @InvocableVariable(label='Jira Issue Id Or Key' required=true)
    public String jiraIssueIdOrKey;

    @InvocableVariable(label='Comment Text' required=true)
    public String commentText;

    @InvocableVariable(label='Confirmed By Employee' required=true)
    public Boolean confirmedByEmployee;

    @InvocableVariable(label='Confirmed Jira Issue Key')
    public String confirmedJiraIssueKey;

    @InvocableVariable(label='Confirmed Comment Text' required=true)
    public String confirmedCommentText;
  }

  public class Response {
    @InvocableVariable(label='Is Success')
    public Boolean isSuccess;

    @InvocableVariable(label='Message')
    public String message;

    @InvocableVariable(label='Jira Issue Key')
    public String jiraIssueKey;

    @InvocableVariable(label='Jira Issue Url')
    public String jiraIssueUrl;

    @InvocableVariable(label='Correlation Id')
    public String correlationId;

    @InvocableVariable(label='Is Duplicate')
    public Boolean isDuplicate;

    @InvocableVariable(label='Error Type')
    public String errorType;

    @InvocableVariable(label='HTTP Status Code')
    public Integer statusCode;

    @InvocableVariable(label='Is Retryable')
    public Boolean isRetryable;
  }

  @InvocableMethod(
    label='Add Jira Comment Direct'
    description='Adds an employee-confirmed public Jira comment through Jira REST.'
  )
  public static List<Response> addComment(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request requestItem : requests) {
      Response responseItem = new Response();
      Long startedAt = Datetime.now().getTime();
      String correlationId;
      try {
        JiraDirectActionSupport.requirePermission(
          JiraDirectActionSupport.PERMISSION_COMMENT
        );
        String validatedIssueKey = JiraDirectActionSupport.validateIssueKey(
          requestItem.jiraIssueIdOrKey
        );
        JiraDirectActionSupport.validateComment(requestItem.commentText);
        correlationId = JiraDirectActionSupport.buildCommentCorrelationKey(
          validatedIssueKey,
          requestItem.commentText
        );
        responseItem.correlationId = correlationId;
        Jira_Integration_Transaction__c existingTransaction = JiraDirectActionSupport.findSuccessfulTransaction(
          correlationId
        );
        if (existingTransaction != null) {
          responseItem.isSuccess = true;
          responseItem.isDuplicate = true;
          responseItem.jiraIssueKey = existingTransaction.Jira_Issue_Key__c;
          responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(
            responseItem.jiraIssueKey
          );
          responseItem.message =
            'This confirmed comment was already added to Jira issue ' +
            responseItem.jiraIssueKey +
            '.';
          responses.add(responseItem);
          continue;
        }
        JiraIntegrationSupport.validateWriteConfirmation(
          validatedIssueKey,
          requestItem.confirmedByEmployee,
          requestItem.confirmedJiraIssueKey,
          requestItem.commentText,
          requestItem.confirmedCommentText
        );
        JiraIntegrationSupport.addComment(
          validatedIssueKey,
          requestItem.commentText
        );

        Map<String, Object> refreshedIssue = JiraIntegrationSupport.getIssueByKey(
          validatedIssueKey
        );
        responseItem.isSuccess = true;
        responseItem.isDuplicate = false;
        responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(
          refreshedIssue.get('key')
        );
        responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(
          responseItem.jiraIssueKey
        );
        responseItem.message =
          'Comment added to Jira issue ' +
          responseItem.jiraIssueKey +
          ' successfully.';
        JiraDirectActionSupport.recordTransaction(
          correlationId,
          'Comment',
          responseItem.jiraIssueKey,
          'Success',
          startedAt,
          null
        );
      } catch (Exception ex) {
        JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(
          ex
        );
        responseItem.isSuccess = false;
        responseItem.isDuplicate = false;
        responseItem.errorType = errorInfo.errorType;
        responseItem.statusCode = errorInfo.statusCode;
        responseItem.isRetryable = errorInfo.isRetryable;
        responseItem.message = 'Jira comment failed: ' + errorInfo.safeMessage;
        responseItem.jiraIssueKey = '';
        responseItem.jiraIssueUrl = '';
        JiraDirectActionSupport.recordTransaction(
          String.isBlank(correlationId)
            ? JiraDirectActionSupport.newAuditCorrelation(
                'Comment',
                requestItem.jiraIssueIdOrKey
              )
            : correlationId,
          'Comment',
          requestItem.jiraIssueIdOrKey,
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
