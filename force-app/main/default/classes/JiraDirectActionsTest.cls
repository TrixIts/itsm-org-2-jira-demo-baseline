@IsTest
private class JiraDirectActionsTest {
  private class JiraMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      String endpoint = request.getEndpoint();

      if (
        request.getMethod() == 'POST' &&
        endpoint.contains('/rest/api/3/issue') &&
        !endpoint.endsWith('/comment')
      ) {
        System.assert(request.getBody().contains('"description"'));
        System.assert(request.getBody().contains('"type":"doc"'));
        System.assert(request.getBody().contains('"version":1'));
        response.setStatusCode(201);
        response.setBody(
          '{"id":"10010","key":"IT-123","self":"https://example.atlassian.net/rest/api/3/issue/10010"}'
        );
        return response;
      }

      if (
        request.getMethod() == 'GET' && endpoint.contains('/rest/api/3/issue/')
      ) {
        response.setStatusCode(200);
        if (endpoint.contains('/IT-125')) {
          response.setBody(
            '{"id":"10012","key":"IT-125","fields":{' +
              '"project":{"id":"10001","key":"IT"},' +
              '"summary":"Closed account access request",' +
              '"status":{"name":"Done","statusCategory":{"key":"done"}},' +
              '"priority":{"name":"Low"},' +
              '"resolution":{"name":"Completed"},' +
              '"updated":"2026-04-24T21:50:00.000+0000",' +
              '"reporter":{"accountId":"acct-123","displayName":"Scott Hendrix"},' +
              '"assignee":{"displayName":"Access Queue"},' +
              '"comment":{"comments":[]}' +
              '},' +
              '"changelog":{"histories":[]}' +
              '}'
          );
          return response;
        }
        if (endpoint.contains('/IT-124')) {
          response.setBody(
            '{"id":"10011","key":"IT-124","fields":{' +
              '"project":{"id":"10001","key":"IT"},' +
              '"summary":"VPN fails on startup",' +
              '"status":{"name":"Waiting for support","statusCategory":{"key":"indeterminate"}},' +
              '"priority":{"name":"Medium"},' +
              '"updated":"2026-04-24T21:40:00.000+0000",' +
              '"reporter":{"accountId":"acct-123","displayName":"Scott Hendrix"},' +
              '"assignee":{"displayName":"Network Queue"},' +
              '"comment":{"comments":[{' +
              '"author":{"displayName":"Scott Hendrix"},' +
              '"created":"2026-04-24T21:20:00.000+0000",' +
              '"updated":"2026-04-24T21:20:00.000+0000",' +
              '"jsdPublic":true,' +
              '"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Customer confirmed the VPN error still appears after reboot."}]}]}' +
              '}]}' +
              '},' +
              '"changelog":{"histories":[{' +
              '"created":"2026-04-24T21:35:00.000+0000",' +
              '"author":{"displayName":"Scott Trix"},' +
              '"items":[{"field":"status","fromString":"Open","toString":"Waiting for support"}]' +
              '}]}' +
              '}'
          );
          return response;
        }
        if (endpoint.contains('/HR-999')) {
          response.setBody(
            '{"id":"10099","key":"HR-999","fields":{' +
              '"project":{"id":"20001","key":"HR"},' +
              '"summary":"Out of scope HR issue",' +
              '"status":{"name":"Open","statusCategory":{"key":"new"}},' +
              '"reporter":{"accountId":"acct-123","displayName":"Scott Hendrix"},' +
              '"comment":{"comments":[]}' +
              '},' +
              '"changelog":{"histories":[]}' +
              '}'
          );
          return response;
        }

        response.setBody(
          '{"id":"10010","key":"IT-123","fields":{' +
            '"project":{"id":"10001","key":"IT"},' +
            '"summary":"Laptop will not boot",' +
            '"status":{"name":"In Progress","statusCategory":{"key":"indeterminate"}},' +
            '"priority":{"name":"High"},' +
            '"updated":"2026-04-24T21:15:00.000+0000",' +
            '"reporter":{"accountId":"acct-123","displayName":"Scott Hendrix"},' +
            '"assignee":{"displayName":"IT Queue"},' +
            '"comment":{"comments":[{' +
            '"author":{"displayName":"Scott Trix"},' +
            '"created":"2026-04-24T21:10:00.000+0000",' +
            '"updated":"2026-04-24T21:10:00.000+0000",' +
            '"jsdPublic":false,' +
            '"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Investigating startup logs and recovery options."}]}]}' +
            '}]}' +
            '},' +
            '"changelog":{"histories":[{' +
            '"created":"2026-04-24T21:00:00.000+0000",' +
            '"author":{"displayName":"Scott Trix"},' +
            '"items":[{"field":"assignee","fromString":"Unassigned","toString":"IT Queue"}]' +
            '}]}' +
            '}'
        );
        return response;
      }

      if (
        request.getMethod() == 'GET' &&
        endpoint.contains('/rest/api/3/project/10001')
      ) {
        response.setStatusCode(200);
        response.setBody(
          '{"id":"10001","key":"IT","name":"IT Service Management"}'
        );
        return response;
      }

      if (
        request.getMethod() == 'GET' &&
        endpoint.contains('/rest/api/3/search/jql')
      ) {
        response.setStatusCode(200);
        response.setBody(
          '{"issues":[' +
            '{"id":"10010","key":"IT-123","fields":{"summary":"Laptop will not boot","status":{"name":"In Progress"},"reporter":{"displayName":"Scott Hendrix"},"assignee":{"displayName":"IT Queue"}}},' +
            '{"id":"10011","key":"IT-124","fields":{"summary":"VPN fails on startup","status":{"name":"Waiting for support"},"reporter":{"displayName":"Scott Hendrix"},"assignee":{"displayName":"Network Queue"}}}' +
            ']}'
        );
        return response;
      }

      if (
        request.getMethod() == 'PUT' && endpoint.contains('/rest/api/3/issue/')
      ) {
        response.setStatusCode(204);
        response.setBody('');
        return response;
      }

      if (request.getMethod() == 'POST' && endpoint.endsWith('/comment')) {
        System.assert(request.getBody().contains('"body"'));
        System.assert(request.getBody().contains('"type":"doc"'));
        System.assert(
          request.getBody()
            .contains('Customer update from Scott Hendrix via Agentforce:')
        );
        response.setStatusCode(201);
        response.setBody('{"id":"20001"}');
        return response;
      }

      response.setStatusCode(400);
      response.setBody(
        '{"errorMessages":["Unexpected mock request: ' +
          String.escapeSingleQuotes(endpoint) +
          '"]}'
      );
      return response;
    }
  }

  private class EmptySearchJiraMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      String endpoint = request.getEndpoint();

      if (
        request.getMethod() == 'GET' &&
        endpoint.contains('/rest/api/3/search/jql')
      ) {
        response.setStatusCode(200);
        response.setBody('{"issues":[]}');
        return response;
      }

      if (
        request.getMethod() == 'GET' && endpoint.contains('/rest/api/3/issue/')
      ) {
        response.setStatusCode(200);
        response.setBody(
          '{"id":"10010","key":"IT-123","fields":{"project":{"id":"10001","key":"IT"},' +
            '"summary":"Laptop will not boot","status":{"name":"In Progress"},' +
            '"reporter":{"accountId":"acct-123","displayName":"Scott Hendrix"},"comment":{"comments":[]}}}'
        );
        return response;
      }

      if (
        request.getMethod() == 'PUT' && endpoint.contains('/rest/api/3/issue/')
      ) {
        response.setStatusCode(204);
        response.setBody('');
        return response;
      }

      response.setStatusCode(201);
      response.setBody('{}');
      return response;
    }
  }

  private class ErrorJiraMock implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;

    ErrorJiraMock(Integer statusCode, String responseBody) {
      this.statusCode = statusCode;
      this.responseBody = responseBody;
    }

    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCode);
      response.setBody(responseBody);
      return response;
    }
  }

  private static void applyOverrides() {
    JiraIntegrationSupport.JiraConfiguration config = new JiraIntegrationSupport.JiraConfiguration();
    config.namedCredentialApiName = 'Jira_Named_Credential';
    config.projectId = '10001';
    config.issueTypeId = '10001';
    config.projectKey = 'IT';
    config.browseBaseUrl = 'https://example.atlassian.net';
    config.openIssueJqlClause = 'statusCategory != Done ORDER BY updated DESC';
    config.impactFieldKey = 'customfield_10004';
    config.urgencyFieldKey = 'customfield_10043';
    config.severityFieldKey = 'customfield_10048';
    config.allowedImpactOptionIds = new Set<String>{
      '10000',
      '10001',
      '10002',
      '10003'
    };
    config.allowedUrgencyOptionIds = new Set<String>{
      '10020',
      '10021',
      '10022',
      '10023'
    };
    config.allowedSeverityOptionIds = new Set<String>{
      '10028',
      '10029',
      '10030',
      '10031'
    };
    config.enforceProjectScope = true;
    config.requireReporterMatchForRead = false;
    config.requireReporterMatchForWrite = false;
    config.exposeInternalComments = false;
    config.sharedReporterAccountId = 'acct-shared';
    config.sharedReporterDisplayName = 'Shared Demo Reporter';
    JiraIntegrationSupport.configOverride = config;

    JiraIntegrationSupport.JiraUserMapping mapping = new JiraIntegrationSupport.JiraUserMapping();
    mapping.salesforceUsername = 'scott@example.demo';
    mapping.jiraAccountId = 'acct-123';
    mapping.jiraDisplayName = 'Scott Hendrix';
    JiraIntegrationSupport.mappingOverridesByUsername = new Map<String, JiraIntegrationSupport.JiraUserMapping>{
      'scott@example.demo' => mapping,
      UserInfo.getUserName() => mapping
    };
    JiraIntegrationSupport.commentAuthorSalesforceUsernameOverride = 'scott@example.demo';
    JiraDirectActionSupport.permissionOverrides = new Set<String>{
      JiraDirectActionSupport.PERMISSION_READ,
      JiraDirectActionSupport.PERMISSION_CREATE,
      JiraDirectActionSupport.PERMISSION_COMMENT,
      JiraDirectActionSupport.PERMISSION_TRIAGE
    };
    JiraDirectActionSupport.transactionOverridesByCorrelation = new Map<String, Jira_Integration_Transaction__c>();
  }

  @IsTest
  static void createIssue_returnsKeyAndUrl() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraCreateIssueAction.Request requestItem = new JiraCreateIssueAction.Request();
    requestItem.jiraSummary = 'Laptop will not boot';
    requestItem.jiraDescription = 'The laptop fails before the login screen after the latest update.';
    requestItem.jiraPriority = 'High';
    requestItem.jiraUrgencyOptionId = '10021';
    requestItem.jiraImpactOptionId = '10001';
    requestItem.jiraSeverityOptionId = '10029';
    requestItem.requesterEmail = 'scott@example.demo';
    requestItem.channel = 'Agentforce';
    requestItem.sourceReference = 'demo-001';
    requestItem.reporterSalesforceUsername = 'scott@example.demo';

    Test.startTest();
    List<JiraCreateIssueAction.Response> responses = JiraCreateIssueAction.createIssue(
      new List<JiraCreateIssueAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals('IT-123', responses[0].jiraIssueKey);
    System.assertEquals('10010', responses[0].jiraIssueId);
    System.assertEquals(
      'https://example.atlassian.net/browse/IT-123',
      responses[0].jiraIssueUrl
    );
  }

  @IsTest
  static void getRequiredUserMapping_usesSharedReporter_WhenNoReporterProvided() {
    applyOverrides();

    JiraIntegrationSupport.JiraUserMapping mapping = JiraIntegrationSupport.getRequiredUserMapping(
      null
    );

    Assert.areEqual(
      'acct-shared',
      mapping.jiraAccountId,
      'Blank reporter input should use the configured shared reporter'
    );
    Assert.areEqual(
      'Shared Demo Reporter',
      mapping.jiraDisplayName,
      'Shared reporter display name should come from config'
    );
  }

  @IsTest
  static void getIssueByKey_returnsReadableSummary() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraGetIssueByKeyAction.Request requestItem = new JiraGetIssueByKeyAction.Request();
    requestItem.jiraIssueKey = 'IT-123';

    Test.startTest();
    List<JiraGetIssueByKeyAction.Response> responses = JiraGetIssueByKeyAction.getIssue(
      new List<JiraGetIssueByKeyAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals('In Progress', responses[0].jiraStatus);
    System.assertEquals('High', responses[0].jiraPriority);
    System.assertEquals(false, responses[0].isClosed);
    System.assert(responses[0].message.contains('IT-123'));
    System.assert(responses[0].message.contains('Laptop will not boot'));
    System.assert(responses[0].message.contains('priority High'));
    System.assert(responses[0].message.contains('Latest update'));
    System.assert(responses[0].latestUpdateSummary.contains('field update'));
    System.assertEquals('', responses[0].recentCommentsSummary);
  }

  @IsTest
  static void getIssueByKey_handlesClosedIssueGuidance() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraGetIssueByKeyAction.Request requestItem = new JiraGetIssueByKeyAction.Request();
    requestItem.jiraIssueKey = 'IT-125';

    Test.startTest();
    List<JiraGetIssueByKeyAction.Response> responses = JiraGetIssueByKeyAction.getIssue(
      new List<JiraGetIssueByKeyAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals('Low', responses[0].jiraPriority);
    System.assertEquals('Completed', responses[0].jiraResolution);
    System.assertEquals(true, responses[0].isClosed);
    System.assert(responses[0].message.contains('appears closed'));
    System.assert(responses[0].message.contains('create a new request'));
  }

  @IsTest
  static void getMyOpenIssues_returnsReporterScopedResults() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraGetMyOpenIssuesAction.Request requestItem = new JiraGetMyOpenIssuesAction.Request();
    requestItem.reporterSalesforceUsername = 'scott@example.demo';
    requestItem.maxResults = 5;

    Test.startTest();
    List<JiraGetMyOpenIssuesAction.Response> responses = JiraGetMyOpenIssuesAction.getMyOpenIssues(
      new List<JiraGetMyOpenIssuesAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals(2, responses[0].issueCount);
    System.assertEquals('acct-123', responses[0].jiraAccountId);
    System.assertEquals('IT-123', responses[0].firstJiraIssueKey);
    System.assertEquals('High', responses[0].firstIssuePriority);
    System.assert(responses[0].issuesSummary.contains('IT-124'));
    System.assert(responses[0].issuesSummary.contains('priority High'));
    System.assert(responses[0].issuesSummary.contains('Latest update'));
    System.assert(
      responses[0].firstIssueLatestUpdateSummary.contains('field update')
    );
  }

  @IsTest
  static void updateIssue_supportsFieldUpdateAndComment() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraUpdateIssueAction.Request requestItem = new JiraUpdateIssueAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.jiraSummary = 'Laptop still will not boot';
    requestItem.jiraImpactOptionId = '10001';
    requestItem.jiraUrgencyOptionId = '10021';
    requestItem.jiraSeverityOptionId = '10029';
    requestItem.commentText = 'Still blocked after trying the suggested recovery steps.';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';
    requestItem.confirmedCommentText = 'Still blocked after trying the suggested recovery steps.';

    Test.startTest();
    List<JiraUpdateIssueAction.Response> responses = JiraUpdateIssueAction.updateIssue(
      new List<JiraUpdateIssueAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals(true, responses[0].didUpdateFields);
    System.assertEquals(true, responses[0].didAddComment);
    System.assertEquals('IT-123', responses[0].jiraIssueKey);
  }

  @IsTest
  static void createIssue_failsWhenMappingIsMissing() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraCreateIssueAction.Request requestItem = new JiraCreateIssueAction.Request();
    requestItem.jiraSummary = 'Missing mapping';
    requestItem.jiraDescription = 'This should fail.';
    requestItem.reporterSalesforceUsername = 'missing@example.demo';

    Test.startTest();
    List<JiraCreateIssueAction.Response> responses = JiraCreateIssueAction.createIssue(
      new List<JiraCreateIssueAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].isSuccess);
    System.assert(responses[0].message.contains('No Jira reporter mapping'));
  }

  @IsTest
  static void getMyOpenIssues_handlesEmptyResults() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new EmptySearchJiraMock());

    JiraGetMyOpenIssuesAction.Request requestItem = new JiraGetMyOpenIssuesAction.Request();
    requestItem.reporterSalesforceUsername = 'scott@example.demo';
    requestItem.maxResults = 5;

    Test.startTest();
    List<JiraGetMyOpenIssuesAction.Response> responses = JiraGetMyOpenIssuesAction.getMyOpenIssues(
      new List<JiraGetMyOpenIssuesAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals(0, responses[0].issueCount);
    System.assertEquals('', responses[0].firstJiraIssueKey);
    System.assert(
      responses[0].message.contains('did not find any open Jira issues')
    );
  }

  @IsTest
  static void updateIssue_failsWhenNoChangesProvided() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraUpdateIssueAction.Request requestItem = new JiraUpdateIssueAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';

    Test.startTest();
    List<JiraUpdateIssueAction.Response> responses = JiraUpdateIssueAction.updateIssue(
      new List<JiraUpdateIssueAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].isSuccess);
    System.assert(
      responses[0]
        .message.contains('Provide at least one Jira field update or a comment')
    );
  }

  @IsTest
  static void updateIssue_supportsCommentOnly() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraUpdateIssueAction.Request requestItem = new JiraUpdateIssueAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.commentText = 'Only adding a comment for this test.';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';
    requestItem.confirmedCommentText = 'Only adding a comment for this test.';

    Test.startTest();
    List<JiraUpdateIssueAction.Response> responses = JiraUpdateIssueAction.updateIssue(
      new List<JiraUpdateIssueAction.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].isSuccess);
    System.assertEquals(false, responses[0].didUpdateFields);
    System.assertEquals(true, responses[0].didAddComment);
    System.assert(responses[0].message.contains('commented successfully'));
  }

  @IsTest
  static void getIssueByKey_rejectsIssueOutsideConfiguredProject() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraGetIssueByKeyAction.Request requestItem = new JiraGetIssueByKeyAction.Request();
    requestItem.jiraIssueKey = 'HR-999';

    Test.startTest();
    List<JiraGetIssueByKeyAction.Response> responses = JiraGetIssueByKeyAction.getIssue(
      new List<JiraGetIssueByKeyAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isFalse(
      responses[0].isSuccess,
      'Lookup should fail for issues outside the configured project'
    );
    Assert.isTrue(
      responses[0].message.contains('configured project'),
      'Message should explain project scoping'
    );
  }

  @IsTest
  static void updateIssue_rejectsUnconfirmedWrite() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraUpdateIssueAction.Request requestItem = new JiraUpdateIssueAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.commentText = 'Unconfirmed comment.';

    Test.startTest();
    List<JiraUpdateIssueAction.Response> responses = JiraUpdateIssueAction.updateIssue(
      new List<JiraUpdateIssueAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isFalse(responses[0].isSuccess, 'Unconfirmed writes should fail');
    Assert.isTrue(
      responses[0].message.contains('explicitly confirm'),
      'Message should explain confirmation requirement'
    );
  }

  @IsTest
  static void addCommentAction_requiresExactConfirmedComment() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraAddCommentAction.Request requestItem = new JiraAddCommentAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.commentText = 'Please keep me posted.';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';
    requestItem.confirmedCommentText = 'Different comment.';

    Test.startTest();
    List<JiraAddCommentAction.Response> responses = JiraAddCommentAction.addComment(
      new List<JiraAddCommentAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isFalse(
      responses[0].isSuccess,
      'Mismatched comment confirmation should fail'
    );
    Assert.isTrue(
      responses[0].message.contains('exactly match'),
      'Message should explain exact comment matching'
    );
  }

  @IsTest
  static void addCommentAction_addsConfirmedComment() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraAddCommentAction.Request requestItem = new JiraAddCommentAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.commentText = 'Please keep me posted.';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';
    requestItem.confirmedCommentText = 'Please keep me posted.';

    Test.startTest();
    List<JiraAddCommentAction.Response> responses = JiraAddCommentAction.addComment(
      new List<JiraAddCommentAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isTrue(responses[0].isSuccess, 'Confirmed comment should succeed');
    Assert.areEqual(
      'IT-123',
      responses[0].jiraIssueKey,
      'Response should return the Jira key'
    );
  }

  @IsTest
  static void updateTriageFieldsAction_rejectsDisallowedOptionId() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraUpdateTriageFieldsAction.Request requestItem = new JiraUpdateTriageFieldsAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.jiraImpactOptionId = '99999';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';

    Test.startTest();
    List<JiraUpdateTriageFieldsAction.Response> responses = JiraUpdateTriageFieldsAction.updateTriageFields(
      new List<JiraUpdateTriageFieldsAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isFalse(responses[0].isSuccess, 'Disallowed option ids should fail');
    Assert.isTrue(
      responses[0].message.contains('allowlist'),
      'Message should explain option allowlist enforcement'
    );
  }

  @IsTest
  static void updateTriageFieldsAction_updatesConfirmedTriage() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraUpdateTriageFieldsAction.Request requestItem = new JiraUpdateTriageFieldsAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.jiraPriority = 'High';
    requestItem.jiraImpactOptionId = '10001';
    requestItem.jiraUrgencyOptionId = '10021';
    requestItem.jiraSeverityOptionId = '10029';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';

    Test.startTest();
    List<JiraUpdateTriageFieldsAction.Response> responses = JiraUpdateTriageFieldsAction.updateTriageFields(
      new List<JiraUpdateTriageFieldsAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isTrue(
      responses[0].isSuccess,
      'Confirmed triage update should succeed'
    );
    Assert.areEqual(
      'IT-123',
      responses[0].jiraIssueKey,
      'Response should return the Jira key'
    );
  }

  @IsTest
  static void healthCheckAction_validatesDirectConfiguration() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());

    JiraConnectionHealthCheckAction.Request requestItem = new JiraConnectionHealthCheckAction.Request();
    requestItem.reporterSalesforceUsername = 'scott@example.demo';

    Test.startTest();
    List<JiraConnectionHealthCheckAction.Response> responses = JiraConnectionHealthCheckAction.checkConnection(
      new List<JiraConnectionHealthCheckAction.Request>{ requestItem }
    );
    Test.stopTest();

    Assert.isTrue(
      responses[0].isSuccess,
      'Health check should pass for configured mock Jira'
    );
    Assert.areEqual(
      'IT',
      responses[0].projectKey,
      'Health check should return the configured project key'
    );
    Assert.areEqual(
      'acct-123',
      responses[0].jiraAccountId,
      'Health check should return the mapped Jira account'
    );
  }

  @IsTest
  static void support_helpers_cover_additional_branches() {
    applyOverrides();

    JiraIntegrationSupport.JiraConfiguration blankBrowseConfig = new JiraIntegrationSupport.JiraConfiguration();
    blankBrowseConfig.namedCredentialApiName = 'Jira_Named_Credential';
    blankBrowseConfig.projectId = '10001';
    blankBrowseConfig.issueTypeId = '10001';
    blankBrowseConfig.projectKey = 'IT';
    blankBrowseConfig.browseBaseUrl = '';
    blankBrowseConfig.openIssueJqlClause = '';
    JiraIntegrationSupport.configOverride = blankBrowseConfig;

    System.assertEquals('', JiraIntegrationSupport.buildIssueUrl('IT-123'));
    System.assertEquals('', JiraIntegrationSupport.stringValue(null));
    System.assertEquals(
      0,
      JiraIntegrationSupport.listValue('not-a-list').size()
    );
    System.assertEquals(0, JiraIntegrationSupport.mapValue('not-a-map').size());
    System.assertEquals(
      'A\\\\B\\"C',
      JiraIntegrationSupport.escapeJqlLiteral('A\\B"C')
    );
    System.assertEquals(
      'Line one Line two',
      JiraIntegrationSupport.adfToPlainText(
        new Map<String, Object>{
          'type' => 'doc',
          'content' => new List<Object>{
            new Map<String, Object>{
              'type' => 'paragraph',
              'content' => new List<Object>{
                new Map<String, Object>{
                  'type' => 'text',
                  'text' => 'Line one'
                },
                new Map<String, Object>{ 'type' => 'hardBreak' },
                new Map<String, Object>{
                  'type' => 'text',
                  'text' => 'Line two'
                }
              }
            }
          }
        }
      )
    );
    System.assertEquals(
      'Customer update from Scott Hendrix via Agentforce:',
      JiraIntegrationSupport.buildStampedCommentLines(
        'Please expedite access restoration.'
      )[0]
    );
    System.assertEquals(
      'Please expedite access restoration.',
      JiraIntegrationSupport.buildStampedCommentLines(
        'Please expedite access restoration.'
      )[1]
    );

    Map<String, Object> syntheticIssue = (Map<String, Object>) JSON.deserializeUntyped(
      '{"key":"IT-777","fields":{"summary":"Synthetic issue","status":{"name":"Open","statusCategory":{"key":"indeterminate"}},' +
        '"priority":{"name":"High"},' +
        '"reporter":{"displayName":"Scott Hendrix"},"assignee":{"displayName":"IT Queue"},' +
        '"updated":"2026-04-24T21:30:00.000+0000","comment":{"comments":[{' +
        '"author":{"displayName":"Scott Trix"},"updated":"2026-04-24T21:25:00.000+0000",' +
        '"jsdPublic":false,"body":{"type":"doc","content":[{"type":"paragraph","content":[{' +
        '"type":"text","text":"Investigating startup logs and recovery options."}]}]}}]}},' +
        '"changelog":{"histories":[{"created":"2026-04-24T21:20:00.000+0000",' +
        '"author":{"displayName":"Scott Trix"},"items":[{"field":"status","fromString":"New","toString":"Open"}]}]}}'
    );
    System.assertEquals(
      '',
      JiraIntegrationSupport.summarizeRecentComments(syntheticIssue, 3)
    );
    System.assert(
      JiraIntegrationSupport.summarizeRecentHistory(syntheticIssue, 3)
        .contains('field update')
    );
    System.assert(
      JiraIntegrationSupport.describeLatestUpdate(syntheticIssue)
        .contains('field update')
    );
    System.assertEquals(
      'High',
      JiraIntegrationSupport.issuePriority(syntheticIssue)
    );
    System.assertEquals(
      false,
      JiraIntegrationSupport.isClosedIssue(syntheticIssue)
    );
    System.assert(
      JiraIntegrationSupport.summarizeIssueWithLatestUpdate(syntheticIssue)
        .contains('Latest update')
    );
    System.assertEquals(
      '',
      JiraIntegrationSupport.buildClosedIssueGuidance(syntheticIssue)
    );

    Map<String, Object> updatedOnlyIssue = (Map<String, Object>) JSON.deserializeUntyped(
      '{"fields":{"updated":"2026-04-24T22:00:00.000+0000"}}'
    );
    System.assert(
      JiraIntegrationSupport.describeLatestUpdate(updatedOnlyIssue)
        .contains('issue metadata was updated')
    );

    Map<String, Object> closedIssue = (Map<String, Object>) JSON.deserializeUntyped(
      '{"fields":{"status":{"name":"Done","statusCategory":{"key":"done"}},"resolution":{"name":"Completed"}}}'
    );
    System.assertEquals(
      true,
      JiraIntegrationSupport.isClosedIssue(closedIssue)
    );
    System.assert(
      JiraIntegrationSupport.buildClosedIssueGuidance(closedIssue)
        .contains('appears closed')
    );

    HttpResponse responseWithMessage = new HttpResponse();
    responseWithMessage.setStatusCode(400);
    responseWithMessage.setBody('{"message":"simple failure"}');
    System.assertEquals(
      'simple failure',
      JiraIntegrationSupport.extractErrorMessage(responseWithMessage)
    );

    HttpResponse responseWithErrors = new HttpResponse();
    responseWithErrors.setStatusCode(400);
    responseWithErrors.setBody('{"errors":{"summary":"required"}}');
    System.assert(
      JiraIntegrationSupport.extractErrorMessage(responseWithErrors)
        .contains('summary: required')
    );
  }

  @IsTest
  static void createIssue_returnsExistingIssueForDuplicateSourceReference() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());
    JiraCreateIssueAction.Request requestItem = new JiraCreateIssueAction.Request();
    requestItem.jiraSummary = 'Duplicate-safe request';
    requestItem.jiraDescription = 'Only one Jira issue should be created.';
    requestItem.sourceReference = 'stable-source-reference';

    Test.startTest();
    JiraCreateIssueAction.Response firstResponse = JiraCreateIssueAction.createIssue(
      new List<JiraCreateIssueAction.Request>{ requestItem }
    )[0];
    JiraCreateIssueAction.Response duplicateResponse = JiraCreateIssueAction.createIssue(
      new List<JiraCreateIssueAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isTrue(firstResponse.isSuccess, 'Initial create should succeed');
    Assert.isTrue(
      duplicateResponse.isSuccess,
      'Duplicate create should return a successful prior result'
    );
    Assert.isTrue(
      duplicateResponse.isDuplicate,
      'Duplicate create should be identified'
    );
    Assert.areEqual(
      'IT-123',
      duplicateResponse.jiraIssueKey,
      'Duplicate should return the original Jira key'
    );
  }

  @IsTest
  static void addComment_returnsDuplicateWithoutSecondWrite() {
    applyOverrides();
    Test.setMock(HttpCalloutMock.class, new JiraMock());
    JiraAddCommentAction.Request requestItem = new JiraAddCommentAction.Request();
    requestItem.jiraIssueIdOrKey = 'IT-123';
    requestItem.commentText = 'A repeat-safe confirmed comment.';
    requestItem.confirmedByEmployee = true;
    requestItem.confirmedJiraIssueKey = 'IT-123';
    requestItem.confirmedCommentText = requestItem.commentText;

    Test.startTest();
    JiraAddCommentAction.addComment(
      new List<JiraAddCommentAction.Request>{ requestItem }
    );
    JiraAddCommentAction.Response duplicateResponse = JiraAddCommentAction.addComment(
      new List<JiraAddCommentAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isTrue(
      duplicateResponse.isSuccess,
      'Duplicate comment should return success'
    );
    Assert.isTrue(
      duplicateResponse.isDuplicate,
      'Duplicate comment should be identified'
    );
  }

  @IsTest
  static void getIssueByKey_returnsSafeRateLimitContract() {
    applyOverrides();
    Test.setMock(
      HttpCalloutMock.class,
      new ErrorJiraMock(
        429,
        '{"message":"secret upstream diagnostic should not leak"}'
      )
    );
    JiraGetIssueByKeyAction.Request requestItem = new JiraGetIssueByKeyAction.Request();
    requestItem.jiraIssueKey = 'IT-123';

    Test.startTest();
    JiraGetIssueByKeyAction.Response response = JiraGetIssueByKeyAction.getIssue(
      new List<JiraGetIssueByKeyAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isFalse(
      response.isSuccess,
      'Rate-limited lookup should fail safely'
    );
    Assert.areEqual(
      'RATE_LIMIT',
      response.errorType,
      'Error type should be normalized'
    );
    Assert.areEqual(429, response.statusCode, 'HTTP status should be returned');
    Assert.isTrue(response.isRetryable, 'Rate limiting should be retryable');
    Assert.isFalse(
      response.message.contains('secret upstream'),
      'Raw Jira diagnostics must not be returned'
    );
  }

  @IsTest
  static void createIssue_rejectsMissingCustomPermission() {
    applyOverrides();
    JiraDirectActionSupport.permissionOverrides.remove(
      JiraDirectActionSupport.PERMISSION_CREATE
    );
    JiraCreateIssueAction.Request requestItem = new JiraCreateIssueAction.Request();
    requestItem.jiraSummary = 'Unauthorized create';
    requestItem.jiraDescription = 'This must not reach Jira.';

    Test.startTest();
    JiraCreateIssueAction.Response response = JiraCreateIssueAction.createIssue(
      new List<JiraCreateIssueAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isFalse(
      response.isSuccess,
      'Create without the custom permission should fail'
    );
    Assert.areEqual(
      'AUTHORIZATION',
      response.errorType,
      'Permission failure should be normalized'
    );
  }

  @IsTest
  static void getMyOpenIssues_rejectsMissingReadPermission() {
    applyOverrides();
    JiraDirectActionSupport.permissionOverrides.remove(
      JiraDirectActionSupport.PERMISSION_READ
    );
    JiraGetMyOpenIssuesAction.Request requestItem = new JiraGetMyOpenIssuesAction.Request();
    requestItem.maxResults = 5;

    Test.startTest();
    JiraGetMyOpenIssuesAction.Response response = JiraGetMyOpenIssuesAction.getMyOpenIssues(
      new List<JiraGetMyOpenIssuesAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isFalse(
      response.isSuccess,
      'Search without the read custom permission should fail'
    );
    Assert.areEqual(
      'AUTHORIZATION',
      response.errorType,
      'Permission failure should be normalized'
    );
    Assert.areEqual(
      0,
      response.issueCount,
      'Failed search should return zero issues'
    );
  }

  @IsTest
  static void getIssueByKey_rejectsMalformedAndEscapedKeys() {
    applyOverrides();
    JiraGetIssueByKeyAction.Request requestItem = new JiraGetIssueByKeyAction.Request();
    requestItem.jiraIssueKey = 'IT-123/../../HR-9';

    Test.startTest();
    JiraGetIssueByKeyAction.Response response = JiraGetIssueByKeyAction.getIssue(
      new List<JiraGetIssueByKeyAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isFalse(
      response.isSuccess,
      'Malformed path-like key should fail before callout'
    );
    Assert.areEqual(
      'VALIDATION',
      response.errorType,
      'Malformed key should be a validation error'
    );
  }

  @IsTest
  static void healthCheck_reportsPlaceholderConfiguration() {
    applyOverrides();
    JiraIntegrationSupport.configOverride.sharedReporterAccountId = 'YOUR_JIRA_ACCOUNT_ID';
    JiraConnectionHealthCheckAction.Request requestItem = new JiraConnectionHealthCheckAction.Request();

    Test.startTest();
    JiraConnectionHealthCheckAction.Response response = JiraConnectionHealthCheckAction.checkConnection(
      new List<JiraConnectionHealthCheckAction.Request>{ requestItem }
    )[0];
    Test.stopTest();

    Assert.isFalse(
      response.isSuccess,
      'Placeholder configuration should not be ready'
    );
    Assert.areEqual(
      'NOT_READY',
      response.readinessStatus,
      'Readiness status should be explicit'
    );
    Assert.areEqual(
      'CONFIGURATION',
      response.errorType,
      'Placeholder should be a configuration error'
    );
  }
}
