public with sharing class JiraFulfillerCreateIssueAction {
  public class Request {
    @InvocableVariable(label='Connector Key')
    public String connectorKey;

    @InvocableVariable(label='Route Key')
    public String routeKey;

    @InvocableVariable(label='Jira Summary' required=true)
    public String jiraSummary;

    @InvocableVariable(label='Jira Description' required=true)
    public String jiraDescription;

    @InvocableVariable(label='Jira Priority')
    public String jiraPriority;

    @InvocableVariable(label='Requester Email')
    public String requesterEmail;

    @InvocableVariable(label='Channel')
    public String channel;

    @InvocableVariable(label='Source Reference')
    public String sourceReference;

    @InvocableVariable(label='Reporter Salesforce Username')
    public String reporterSalesforceUsername;

    @InvocableVariable(label='Confirmed By Employee' required=true)
    public Boolean confirmedByEmployee;
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
    label='Create Jira Issue (Fulfiller)'
    description='Creates a Jira issue in the selected project route after explicit employee confirmation.'
    callout=true
  )
  public static List<Response> createIssue(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request requestItem : requests) {
      Response responseItem = new Response();
      Long startedAt = Datetime.now().getTime();
      String correlationId;
      try {
        JiraFulfillerSupport.requirePermission(
          JiraFulfillerSupport.PERMISSION_CREATE
        );
        if (requestItem.confirmedByEmployee != true) {
          throw JiraIntegrationSupport.newException(
            'VALIDATION',
            null,
            false,
            'The employee must confirm the new Jira issue before it is created.'
          );
        }
        JiraDirectActionSupport.validateCreateInputs(
          requestItem.jiraSummary,
          requestItem.jiraDescription,
          requestItem.jiraPriority,
          requestItem.requesterEmail,
          requestItem.channel,
          requestItem.sourceReference
        );
        Jira_Connector_Profile__c profile = JiraFulfillerSupport.resolveProfileForRoute(
          requestItem.connectorKey,
          requestItem.routeKey
        );
        correlationId = JiraDirectActionSupport.buildCreateCorrelationKey(
          requestItem.sourceReference,
          requestItem.jiraSummary,
          requestItem.jiraDescription,
          requestItem.requesterEmail
        );
        responseItem.correlationId = correlationId;

        Jira_Integration_Transaction__c existing = JiraDirectActionSupport.findSuccessfulTransaction(
          correlationId
        );
        if (existing != null) {
          responseItem.isSuccess = true;
          responseItem.isDuplicate = true;
          responseItem.jiraIssueKey = existing.Jira_Issue_Key__c;
          responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(
            profile,
            responseItem.jiraIssueKey
          );
          responseItem.message =
            'This request was already submitted as Jira issue ' +
            responseItem.jiraIssueKey +
            '.';
          responses.add(responseItem);
          continue;
        }

        Map<String, Object> fields = new Map<String, Object>{
          'project' => new Map<String, Object>{ 'id' => profile.Project_Id__c },
          'issuetype' => new Map<String, Object>{
            'id' => profile.Issue_Type_Id__c
          },
          'summary' => requestItem.jiraSummary,
          'description' => JiraIntegrationSupport.buildAdfDocument(
            JiraIntegrationSupport.buildIssueDescriptionLines(
              requestItem.jiraDescription,
              requestItem.requesterEmail,
              requestItem.channel,
              requestItem.sourceReference
            )
          )
        };
        if (!String.isBlank(requestItem.jiraPriority)) {
          fields.put(
            'priority',
            new Map<String, Object>{ 'name' => requestItem.jiraPriority }
          );
        }
        if (!String.isBlank(requestItem.reporterSalesforceUsername)) {
          JiraIntegrationSupport.JiraUserMapping reporter = JiraIntegrationSupport.getRequiredUserMapping(
            requestItem.reporterSalesforceUsername
          );
          fields.put(
            'reporter',
            new Map<String, Object>{ 'id' => reporter.jiraAccountId }
          );
        }

        Map<String, Object> createResult = JiraIntegrationSupport.sendRequestVia(
          profile.Named_Credential_Api_Name__c,
          'POST',
          '/rest/api/3/issue',
          null,
          new Map<String, Object>{ 'fields' => fields }
        );

        responseItem.isSuccess = true;
        responseItem.isDuplicate = false;
        responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(
          createResult.get('key')
        );
        responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(
          createResult.get('id')
        );
        responseItem.jiraIssueUrl = JiraFulfillerSupport.buildIssueUrl(
          profile,
          responseItem.jiraIssueKey
        );
        responseItem.message =
          'Jira issue ' +
          responseItem.jiraIssueKey +
          ' created successfully.';
        JiraDirectActionSupport.recordTransaction(
          correlationId,
          'FulfillerCreate',
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
        responseItem.message =
          'Jira issue creation failed: ' + errorInfo.safeMessage;
        JiraDirectActionSupport.recordTransaction(
          String.isBlank(correlationId)
            ? JiraDirectActionSupport.newAuditCorrelation(
                'FulfillerCreate',
                null
              )
            : correlationId,
          'FulfillerCreate',
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
