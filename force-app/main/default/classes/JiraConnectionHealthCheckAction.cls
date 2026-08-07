public with sharing class JiraConnectionHealthCheckAction {
  public class Request {
    @InvocableVariable(label='Reporter Salesforce Username')
    public String reporterSalesforceUsername;
  }

  public class Response {
    @InvocableVariable(label='Is Success')
    public Boolean isSuccess;

    @InvocableVariable(label='Message')
    public String message;

    @InvocableVariable(label='Named Credential API Name')
    public String namedCredentialApiName;

    @InvocableVariable(label='Project Key')
    public String projectKey;

    @InvocableVariable(label='Project Id')
    public String projectId;

    @InvocableVariable(label='Issue Type Id')
    public String issueTypeId;

    @InvocableVariable(label='Reporter Salesforce Username')
    public String reporterSalesforceUsername;

    @InvocableVariable(label='Jira Account Id')
    public String jiraAccountId;

    @InvocableVariable(label='Readiness Status')
    public String readinessStatus;

    @InvocableVariable(label='Readiness Issues')
    public String readinessIssues;

    @InvocableVariable(label='Error Type')
    public String errorType;

    @InvocableVariable(label='HTTP Status Code')
    public Integer statusCode;

    @InvocableVariable(label='Is Retryable')
    public Boolean isRetryable;
  }

  @InvocableMethod(
    label='Check Jira Direct Connection'
    description='Validates direct Jira configuration, reporter mapping, and the configured Jira project.'
  )
  public static List<Response> checkConnection(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request requestItem : requests) {
      Response responseItem = new Response();
      try {
        JiraDirectActionSupport.requirePermission(
          JiraDirectActionSupport.PERMISSION_READ
        );
        JiraIntegrationSupport.JiraConfiguration config = JiraIntegrationSupport.getConfiguration();
        List<String> readinessIssues = JiraIntegrationSupport.validateConfigurationReadiness(
          config
        );
        if (!readinessIssues.isEmpty()) {
          throw JiraIntegrationSupport.newException(
            'CONFIGURATION',
            null,
            false,
            'Jira configuration is not ready: ' +
            String.join(readinessIssues, ' ')
          );
        }
        String resolvedUsername = JiraIntegrationSupport.resolveSalesforceUsername(
          requestItem == null ? null : requestItem.reporterSalesforceUsername
        );
        JiraIntegrationSupport.JiraUserMapping mapping = JiraIntegrationSupport.getRequiredUserMapping(
          requestItem == null ? null : requestItem.reporterSalesforceUsername
        );
        if (
          !Pattern.matches('^[A-Za-z0-9:_-]{3,128}$', mapping.jiraAccountId)
        ) {
          throw JiraIntegrationSupport.newException(
            'CONFIGURATION',
            null,
            false,
            'The configured Jira reporter accountId is missing, malformed, or still a placeholder.'
          );
        }
        Map<String, Object> project = JiraIntegrationSupport.sendRequest(
          'GET',
          '/rest/api/3/project/' +
          EncodingUtil.urlEncode(config.projectId, 'UTF-8'),
          null,
          null
        );

        responseItem.isSuccess = true;
        responseItem.namedCredentialApiName = config.namedCredentialApiName;
        responseItem.projectId = config.projectId;
        responseItem.projectKey = JiraIntegrationSupport.stringValue(
          project.get('key')
        );
        if (String.isBlank(responseItem.projectKey)) {
          responseItem.projectKey = config.projectKey;
        }
        if (
          JiraIntegrationSupport.stringValue(project.get('id')) !=
          config.projectId ||
          responseItem.projectKey != config.projectKey
        ) {
          throw JiraIntegrationSupport.newException(
            'CONFIGURATION',
            null,
            false,
            'The reachable Jira project does not match the configured ProjectId and ProjectKey.'
          );
        }
        responseItem.issueTypeId = config.issueTypeId;
        responseItem.reporterSalesforceUsername = mapping.salesforceUsername;
        responseItem.jiraAccountId = mapping.jiraAccountId;
        responseItem.readinessStatus = 'READY';
        responseItem.readinessIssues = '';
        responseItem.message =
          'Jira direct connection is configured for project ' +
          responseItem.projectKey +
          '.';
      } catch (Exception ex) {
        JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(
          ex
        );
        responseItem.isSuccess = false;
        responseItem.readinessStatus = 'NOT_READY';
        responseItem.readinessIssues = errorInfo.safeMessage;
        responseItem.errorType = errorInfo.errorType;
        responseItem.statusCode = errorInfo.statusCode;
        responseItem.isRetryable = errorInfo.isRetryable;
        responseItem.message =
          'Jira direct connection check failed: ' + errorInfo.safeMessage;
      }
      responses.add(responseItem);
    }
    return responses;
  }
}
