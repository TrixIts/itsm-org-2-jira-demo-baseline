@isTest
private class JiraFulfillerActionsTest {
    private static final Set<String> ALL_PERMISSIONS = new Set<String>{
        JiraFulfillerSupport.PERMISSION_SEARCH,
        JiraFulfillerSupport.PERMISSION_READ,
        JiraFulfillerSupport.PERMISSION_CREATE,
        JiraFulfillerSupport.PERMISSION_FIELD_UPDATE,
        JiraFulfillerSupport.PERMISSION_COMMENT,
        JiraFulfillerSupport.PERMISSION_ASSIGN,
        JiraFulfillerSupport.PERMISSION_TRANSITION
    };

    private class RouterMock implements HttpCalloutMock {
        public Integer forcedStatus = null;
        public String capturedEndpoint;
        public String capturedSearchEndpoint;
        public Integer approximateCount = 2;
        public String searchNextPageToken;
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            if (forcedStatus != null) {
                response.setStatusCode(forcedStatus);
                response.setBody('{"errorMessages":["Simulated Jira failure"]}');
                return response;
            }
            String endpoint = request.getEndpoint();
            capturedEndpoint = endpoint;
            String method = request.getMethod();
            response.setStatusCode(200);
            if (endpoint.contains('/search/jql')) {
                capturedSearchEndpoint = endpoint;
                response.setBody(
                    '{"issues":[' +
                    '{"key":"OPS-1","fields":{"summary":"Login broken","status":{"name":"To Do"},"priority":{"name":"High"},"assignee":{"displayName":"Dana"},"reporter":{"displayName":"Sam"},"updated":"2026-01-01T00:00:00.000+0000"}},' +
                    '{"key":"OPS-2","fields":{"summary":"VPN down","status":{"name":"In Progress"}}}' +
                    ']' +
                    (String.isBlank(searchNextPageToken) ? '' : ',"nextPageToken":"' + searchNextPageToken + '"') +
                    '}'
                );
            } else if (endpoint.contains('/search/approximate-count')) {
                response.setBody('{"count":' + approximateCount + '}');
            } else if (endpoint.contains('/transitions')) {
                response.setBody(method == 'GET'
                    ? '{"transitions":[{"id":"31","name":"Start Progress","to":{"name":"In Progress"}}]}'
                    : '');
            } else if (endpoint.contains('/assignable/search')) {
                response.setBody('[{"accountId":"acc-1","displayName":"Dana Dev"}]');
            } else if (endpoint.contains('/assignee')) {
                response.setBody('');
            } else if (endpoint.contains('/comment')) {
                response.setBody('{"id":"c1"}');
            } else if (endpoint.contains('/issue/') && method == 'GET') {
                response.setBody(issueJson());
            } else if (endpoint.contains('/issue/') && method == 'PUT') {
                response.setBody('');
            } else if (endpoint.endsWith('/issue') && method == 'POST') {
                response.setBody('{"key":"OPS-9","id":"99"}');
            } else {
                response.setBody('{}');
            }
            return response;
        }
    }

    private static String issueJson() {
        return '{"key":"OPS-1","id":"10001","fields":{' +
            '"project":{"id":"10000","key":"OPS"},' +
            '"summary":"Login broken","description":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Users cannot log in."}]}]},' +
            '"status":{"name":"To Do","statusCategory":{"key":"indeterminate"}},' +
            '"priority":{"name":"High"},' +
            '"reporter":{"displayName":"Sam","accountId":"rep-1"},' +
            '"assignee":{"displayName":"Dana","accountId":"acc-1"},' +
            '"updated":"2026-01-02T00:00:00.000+0000",' +
            '"comment":{"comments":[{"author":{"displayName":"Dana"},"body":{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Investigating."}]}]},"created":"2026-01-02T00:00:00.000+0000"}]}' +
            '}, "changelog":{"histories":[{"author":{"displayName":"Dana"},"created":"2026-01-02T01:00:00.000+0000","items":[{"field":"status","fromString":"To Do","toString":"In Progress"}]}]}}';
    }

    private static void seedRuntime() {
        JiraDirectActionSupport.permissionOverrides = new Set<String>(ALL_PERMISSIONS);
        JiraIntegrationSupport.JiraConfiguration config = new JiraIntegrationSupport.JiraConfiguration();
        config.namedCredentialApiName = 'JiraNC';
        config.projectId = '10000';
        config.issueTypeId = '10001';
        config.projectKey = 'OPS';
        config.browseBaseUrl = 'https://example.atlassian.net';
        config.exposeInternalComments = false;
        JiraIntegrationSupport.configOverride = config;
        Jira_Connector_Profile__c profile = new Jira_Connector_Profile__c(
            Connector_Key__c = 'proj-a',
            Named_Credential_Api_Name__c = 'JiraNC',
            Project_Id__c = '10000',
            Project_Key__c = 'OPS',
            Issue_Type_Id__c = '10001',
            Browse_Base_Url__c = 'https://example.atlassian.net',
            Active__c = true,
            Is_Active_For_Agentforce__c = true,
            Route_Key__c = 'incident'
        );
        JiraFulfillerSupport.profileOverrides = new List<Jira_Connector_Profile__c>{ profile };
        JiraFulfillerSupport.mappingOverrides = new List<Jira_Field_Mapping__c>{
            new Jira_Field_Mapping__c(
                Connector_Key__c = 'proj-a',
                Canonical_Field__c = 'summary',
                Backend_Field_Key__c = 'summary',
                Backend_Field_Label__c = 'Summary',
                Enabled__c = true,
                Allow_Agent_Update__c = true,
                Use_In_Summary__c = true,
                Transform_Type__c = 'Direct'
            )
        };
    }

    @isTest
    static void testSearchReturnsGroundedResults() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerSearchIssuesAction.Request req = new JiraFulfillerSearchIssuesAction.Request();
        req.statusCategory = 'open';
        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(new List<JiraFulfillerSearchIssuesAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, responses[0].isSuccess, responses[0].message);
        System.assertEquals(2, responses[0].totalCount);
        System.assertEquals('OPS-1', responses[0].firstJiraIssueKey);
        System.assertEquals('UNTRUSTED_EXTERNAL_DATA', responses[0].contentTrust);
        Assert.isTrue(
            responses[0].issuesSummary.contains(
                '• OPS-1 — Login broken\n  Status: To Do · Priority: High · Assignee: Dana'
            ),
            'Queue results should render a readable two-line issue card'
        );
        Assert.isTrue(
            responses[0].issuesSummary.contains('\n\n• OPS-2 — VPN down'),
            'Queue issue cards should be separated by a blank line'
        );
    }

    @isTest
    static void search_UsesCurrentJiraUser_WhenAssigneeFilterIsMe() {
        seedRuntime();
        RouterMock mock = new RouterMock();
        Test.setMock(HttpCalloutMock.class, mock);
        JiraFulfillerSearchIssuesAction.Request requestItem = new JiraFulfillerSearchIssuesAction.Request();
        requestItem.assigneeFilter = 'me';

        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(
                new List<JiraFulfillerSearchIssuesAction.Request>{ requestItem }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].isSuccess, responses[0].message);
        String decodedEndpoint = EncodingUtil.urlDecode(mock.capturedSearchEndpoint, 'UTF-8');
        Assert.isTrue(
            decodedEndpoint.contains('assignee = currentUser()'),
            'The me filter should use Jira currentUser() without treating me as an account id'
        );
    }

    @isTest
    static void search_UsesReturnedRows_WhenApproximateCountLags() {
        seedRuntime();
        RouterMock mock = new RouterMock();
        mock.approximateCount = 0;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(
                new List<JiraFulfillerSearchIssuesAction.Request>{
                    new JiraFulfillerSearchIssuesAction.Request()
                }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].isSuccess, responses[0].message);
        Assert.areEqual(
            responses[0].returnedCount,
            responses[0].totalCount,
            'Total count must never be lower than the issues returned by Jira'
        );
    }

    @isTest
    static void search_UsesEnhancedSearchContinuationToken() {
        seedRuntime();
        RouterMock mock = new RouterMock();
        mock.approximateCount = 8;
        mock.searchNextPageToken = 'jira-token-2';
        Test.setMock(HttpCalloutMock.class, mock);
        JiraFulfillerSearchIssuesAction.Request requestItem =
            new JiraFulfillerSearchIssuesAction.Request();
        requestItem.nextPageToken = 'jira-token-1';
        requestItem.startAt = 2;

        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(
                new List<JiraFulfillerSearchIssuesAction.Request>{ requestItem }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].isSuccess, responses[0].message);
        Assert.areEqual(8, responses[0].totalCount, 'Approximate Jira count should be returned');
        Assert.isTrue(responses[0].hasMore, 'A continuation token means more issues are available');
        Assert.areEqual('jira-token-2', responses[0].nextPageToken, 'Next Jira token should be exposed');
        Assert.areEqual(4, responses[0].nextStartAt, 'Logical offset should advance by returned rows');
        Assert.isTrue(
            EncodingUtil.urlDecode(mock.capturedSearchEndpoint, 'UTF-8')
                .contains('nextPageToken=jira-token-1'),
            'The prior Jira continuation token should be sent to enhanced search'
        );
    }

    @isTest
    static void testSearchProjectScopeDenied() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerSearchIssuesAction.Request req = new JiraFulfillerSearchIssuesAction.Request();
        req.projectKeys = new List<String>{ 'NOPE' };
        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(new List<JiraFulfillerSearchIssuesAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('SCOPE', responses[0].errorType);
    }

    @isTest
    static void testSearchPermissionDenied() {
        seedRuntime();
        JiraDirectActionSupport.permissionOverrides = new Set<String>();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(new List<JiraFulfillerSearchIssuesAction.Request>{ new JiraFulfillerSearchIssuesAction.Request() });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('AUTHORIZATION', responses[0].errorType);
    }

    @isTest
    static void testSearchSanitizedError() {
        seedRuntime();
        RouterMock mock = new RouterMock();
        mock.forcedStatus = 500;
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(new List<JiraFulfillerSearchIssuesAction.Request>{ new JiraFulfillerSearchIssuesAction.Request() });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('AVAILABILITY', responses[0].errorType);
        System.assertEquals(true, responses[0].isRetryable);
    }

    @isTest
    static void testGetDetail() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerGetIssueDetailAction.Request req = new JiraFulfillerGetIssueDetailAction.Request();
        req.jiraIssueKey = 'OPS-1';
        Test.startTest();
        List<JiraFulfillerGetIssueDetailAction.Response> responses =
            JiraFulfillerGetIssueDetailAction.getDetail(new List<JiraFulfillerGetIssueDetailAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, responses[0].isSuccess, responses[0].message);
        System.assertEquals('OPS-1', responses[0].jiraIssueKey);
        System.assertEquals('To Do', responses[0].jiraStatus);
        System.assert(responses[0].jiraDescription.contains('log in'), responses[0].jiraDescription);
    }

    @isTest
    static void testGetDetailScopeDenied() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerGetIssueDetailAction.Request req = new JiraFulfillerGetIssueDetailAction.Request();
        req.jiraIssueKey = 'ZZZ-1';
        Test.startTest();
        List<JiraFulfillerGetIssueDetailAction.Response> responses =
            JiraFulfillerGetIssueDetailAction.getDetail(new List<JiraFulfillerGetIssueDetailAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('SCOPE', responses[0].errorType);
    }

    @isTest
    static void testCreateRequiresConfirmation() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerCreateIssueAction.Request req = new JiraFulfillerCreateIssueAction.Request();
        req.jiraSummary = 'New laptop';
        req.jiraDescription = 'Requesting a new laptop.';
        req.confirmedByEmployee = false;
        Test.startTest();
        List<JiraFulfillerCreateIssueAction.Response> responses =
            JiraFulfillerCreateIssueAction.createIssue(new List<JiraFulfillerCreateIssueAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('VALIDATION', responses[0].errorType);
    }

    @isTest
    static void testCreateSucceeds() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerCreateIssueAction.Request req = new JiraFulfillerCreateIssueAction.Request();
        req.connectorKey = 'proj-a';
        req.jiraSummary = 'New laptop';
        req.jiraDescription = 'Requesting a new laptop.';
        req.jiraPriority = 'High';
        req.confirmedByEmployee = true;
        Test.startTest();
        List<JiraFulfillerCreateIssueAction.Response> responses =
            JiraFulfillerCreateIssueAction.createIssue(new List<JiraFulfillerCreateIssueAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, responses[0].isSuccess, responses[0].message);
        System.assertEquals('OPS-9', responses[0].jiraIssueKey);
    }

    @isTest
    static void testPrepareFieldUpdateAllowlisted() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerPrepareFieldUpdateAction.Request req = new JiraFulfillerPrepareFieldUpdateAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.changesJson = '{"summary":"Login page returns 500"}';
        Test.startTest();
        List<JiraFulfillerPrepareFieldUpdateAction.Response> responses =
            JiraFulfillerPrepareFieldUpdateAction.prepare(new List<JiraFulfillerPrepareFieldUpdateAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, responses[0].isSuccess, responses[0].message);
        System.assert(String.isNotBlank(responses[0].confirmationToken), 'Expected a token');
        System.assert(responses[0].previewText.contains('Summary'), responses[0].previewText);
    }

    @isTest
    static void testPrepareFieldUpdateRejectsNonAllowlisted() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerPrepareFieldUpdateAction.Request req = new JiraFulfillerPrepareFieldUpdateAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.changesJson = '{"labels":"urgent"}';
        Test.startTest();
        List<JiraFulfillerPrepareFieldUpdateAction.Response> responses =
            JiraFulfillerPrepareFieldUpdateAction.prepare(new List<JiraFulfillerPrepareFieldUpdateAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('VALIDATION', responses[0].errorType);
    }

    @isTest
    static void testApplyFieldUpdateWithToken() {
        seedRuntime();
        String token = 'FieldUpdate:testtoken';
        JiraFulfillerSupport.pendingTokenDetailOverrides = new Map<String, Map<String, Object>>{
            token => new Map<String, Object>{
                'connectorKey' => 'proj-a',
                'issueKey' => 'OPS-1',
                'createdByUserId' => UserInfo.getUserId(),
                'payload' => new Map<String, Object>{ 'summary' => 'Login page returns 500' }
            }
        };
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerApplyFieldUpdateAction.Request req = new JiraFulfillerApplyFieldUpdateAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.confirmationToken = token;
        req.confirmedByEmployee = true;
        Test.startTest();
        List<JiraFulfillerApplyFieldUpdateAction.Response> responses =
            JiraFulfillerApplyFieldUpdateAction.apply(new List<JiraFulfillerApplyFieldUpdateAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, responses[0].isSuccess, responses[0].message);
        System.assertEquals(true, responses[0].didUpdateFields);
    }

    @isTest
    static void testApplyFieldUpdateRejectsBadToken() {
        seedRuntime();
        JiraFulfillerSupport.pendingTokenDetailOverrides = new Map<String, Map<String, Object>>();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerApplyFieldUpdateAction.Request req = new JiraFulfillerApplyFieldUpdateAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.confirmationToken = 'FieldUpdate:missing';
        req.confirmedByEmployee = true;
        Test.startTest();
        List<JiraFulfillerApplyFieldUpdateAction.Response> responses =
            JiraFulfillerApplyFieldUpdateAction.apply(new List<JiraFulfillerApplyFieldUpdateAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('VALIDATION', responses[0].errorType);
    }

    @isTest
    static void testAddComment() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerAddCommentAction.Request req = new JiraFulfillerAddCommentAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.commentText = 'Investigating now.';
        req.confirmedByEmployee = true;
        req.confirmedJiraIssueKey = 'OPS-1';
        req.confirmedCommentText = 'Investigating now.';
        Test.startTest();
        List<JiraFulfillerAddCommentAction.Response> responses =
            JiraFulfillerAddCommentAction.addComment(new List<JiraFulfillerAddCommentAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, responses[0].isSuccess, responses[0].message);
    }

    @isTest
    static void testAddCommentRejectsMismatchedConfirmation() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerAddCommentAction.Request req = new JiraFulfillerAddCommentAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.commentText = 'Investigating now.';
        req.confirmedByEmployee = true;
        req.confirmedJiraIssueKey = 'OPS-1';
        req.confirmedCommentText = 'Different text.';
        Test.startTest();
        List<JiraFulfillerAddCommentAction.Response> responses =
            JiraFulfillerAddCommentAction.addComment(new List<JiraFulfillerAddCommentAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('VALIDATION', responses[0].errorType);
    }

    @isTest
    static void testGetTransitionsAndTransition() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerGetTransitionsAction.Request getReq = new JiraFulfillerGetTransitionsAction.Request();
        getReq.jiraIssueKey = 'OPS-1';

        JiraFulfillerTransitionIssueAction.Request transitionReq = new JiraFulfillerTransitionIssueAction.Request();
        transitionReq.jiraIssueKey = 'OPS-1';
        transitionReq.transitionId = '31';
        transitionReq.confirmedByEmployee = true;
        transitionReq.confirmedJiraIssueKey = 'OPS-1';
        transitionReq.confirmedTransitionId = '31';

        Test.startTest();
        List<JiraFulfillerGetTransitionsAction.Response> getResponses =
            JiraFulfillerGetTransitionsAction.getTransitions(new List<JiraFulfillerGetTransitionsAction.Request>{ getReq });
        List<JiraFulfillerTransitionIssueAction.Response> transitionResponses =
            JiraFulfillerTransitionIssueAction.transitionIssue(new List<JiraFulfillerTransitionIssueAction.Request>{ transitionReq });
        Test.stopTest();

        System.assertEquals(true, getResponses[0].isSuccess, getResponses[0].message);
        System.assertEquals('31', getResponses[0].firstTransitionId);
        System.assertEquals(true, transitionResponses[0].isSuccess, transitionResponses[0].message);
    }

    @isTest
    static void testTransitionRejectsMismatchedConfirmation() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerTransitionIssueAction.Request req = new JiraFulfillerTransitionIssueAction.Request();
        req.jiraIssueKey = 'OPS-1';
        req.transitionId = '31';
        req.confirmedByEmployee = true;
        req.confirmedTransitionId = '99';
        Test.startTest();
        List<JiraFulfillerTransitionIssueAction.Response> responses =
            JiraFulfillerTransitionIssueAction.transitionIssue(new List<JiraFulfillerTransitionIssueAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('VALIDATION', responses[0].errorType);
    }

    @isTest
    static void testSearchAssigneesAndAssign() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerSearchAssigneeAction.Request searchReq = new JiraFulfillerSearchAssigneeAction.Request();
        searchReq.jiraIssueKey = 'OPS-1';
        searchReq.query = 'Dana';

        JiraFulfillerAssignIssueAction.Request assignReq = new JiraFulfillerAssignIssueAction.Request();
        assignReq.jiraIssueKey = 'OPS-1';
        assignReq.assigneeAccountId = 'acc-1';
        assignReq.confirmedByEmployee = true;
        assignReq.confirmedJiraIssueKey = 'OPS-1';
        assignReq.confirmedAssigneeAccountId = 'acc-1';

        Test.startTest();
        List<JiraFulfillerSearchAssigneeAction.Response> searchResponses =
            JiraFulfillerSearchAssigneeAction.searchAssignees(new List<JiraFulfillerSearchAssigneeAction.Request>{ searchReq });
        List<JiraFulfillerAssignIssueAction.Response> assignResponses =
            JiraFulfillerAssignIssueAction.assignIssue(new List<JiraFulfillerAssignIssueAction.Request>{ assignReq });
        Test.stopTest();

        System.assertEquals(true, searchResponses[0].isSuccess, searchResponses[0].message);
        System.assertEquals('acc-1', searchResponses[0].firstAccountId);
        System.assertEquals(true, assignResponses[0].isSuccess, assignResponses[0].message);
        System.assertEquals('Dana', assignResponses[0].jiraAssigneeDisplayName);
    }

    @isTest
    static void testInvalidIssueKeyFormat() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerGetIssueDetailAction.Request req = new JiraFulfillerGetIssueDetailAction.Request();
        req.jiraIssueKey = 'not-a-key';
        Test.startTest();
        List<JiraFulfillerGetIssueDetailAction.Response> responses =
            JiraFulfillerGetIssueDetailAction.getDetail(new List<JiraFulfillerGetIssueDetailAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, responses[0].isSuccess);
        System.assertEquals('VALIDATION', responses[0].errorType);
    }

    @isTest
    static void resolveProfile_SelectsConnectorAndRoute() {
        seedRuntime();
        Jira_Connector_Profile__c requestProfile = new Jira_Connector_Profile__c(
            Connector_Key__c = 'proj-b',
            Named_Credential_Api_Name__c = 'JiraNC',
            Project_Id__c = '20000',
            Project_Key__c = 'REQ',
            Issue_Type_Id__c = '20001',
            Active__c = true,
            Is_Active_For_Agentforce__c = true,
            Route_Key__c = 'request'
        );
        JiraFulfillerSupport.profileOverrides.add(requestProfile);

        Test.startTest();
        Jira_Connector_Profile__c byConnector =
            JiraFulfillerSupport.resolveProfileForRoute('proj-b', null);
        Jira_Connector_Profile__c byRoute =
            JiraFulfillerSupport.resolveProfileForRoute(null, 'incident');
        Set<String> projectKeys = JiraFulfillerSupport.allowedProjectKeys();
        String routes = JiraFulfillerSupport.describeRoutes(JiraFulfillerSupport.activeProfiles());
        Test.stopTest();

        Assert.areEqual('REQ', byConnector.Project_Key__c, 'Connector key should select the request profile');
        Assert.areEqual('OPS', byRoute.Project_Key__c, 'Route key should select the incident profile');
        Assert.isTrue(projectKeys.contains('OPS') && projectKeys.contains('REQ'), 'Both allowed project keys should be returned');
        Assert.isTrue(routes.contains('incident (OPS)') && routes.contains('request (REQ)'), 'Route description should include both profiles');
    }

    @isTest
    static void resolveProfile_RejectsUnknownConnector() {
        seedRuntime();

        Test.startTest();
        try {
            JiraFulfillerSupport.resolveProfileForRoute('missing', null);
            Assert.fail('Unknown connector keys must be rejected');
        } catch (JiraIntegrationSupport.JiraIntegrationException exceptionValue) {
            Assert.isTrue(exceptionValue.getMessage().contains('No active Jira connector profile'), 'Error should identify the missing connector profile');
        }
        Test.stopTest();
    }

    @isTest
    static void resolveProfile_RequiresRouteWithMultipleProfiles() {
        seedRuntime();
        JiraFulfillerSupport.profileOverrides.add(new Jira_Connector_Profile__c(
            Connector_Key__c = 'proj-b',
            Named_Credential_Api_Name__c = 'JiraNC',
            Project_Id__c = '20000',
            Project_Key__c = 'REQ',
            Issue_Type_Id__c = '20001',
            Active__c = true,
            Is_Active_For_Agentforce__c = true,
            Route_Key__c = 'request'
        ));

        Test.startTest();
        try {
            JiraFulfillerSupport.resolveProfileForRoute(null, null);
            Assert.fail('Multiple profiles must require an explicit route');
        } catch (JiraIntegrationSupport.JiraIntegrationException exceptionValue) {
            Assert.isTrue(exceptionValue.getMessage().contains('Multiple Jira projects'), 'Error should ask for a connector or route key');
        }
        Test.stopTest();
    }

    @isTest
    static void search_AppliesAllStructuredFiltersAndCapsPageSize() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerSearchIssuesAction.Request requestItem = new JiraFulfillerSearchIssuesAction.Request();
        requestItem.projectKeys = new List<String>{ 'ops' };
        requestItem.statusCategory = 'done';
        requestItem.priorityNames = new List<String>{ 'High', 'Highest' };
        requestItem.assigneeFilter = 'unassigned';
        requestItem.reporterFilter = 'rep-1';
        requestItem.textQuery = 'login';
        requestItem.updatedWithinDays = 30;
        requestItem.startAt = -5;
        requestItem.maxResults = 500;

        Test.startTest();
        List<JiraFulfillerSearchIssuesAction.Response> responses =
            JiraFulfillerSearchIssuesAction.search(
                new List<JiraFulfillerSearchIssuesAction.Request>{ requestItem }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].isSuccess, responses[0].message);
        Assert.areEqual(0, responses[0].startAt, 'Negative offsets should normalize to zero');
        Assert.areEqual(2, responses[0].returnedCount, 'Mocked issues should be rendered');
    }

    @isTest
    static void prepareFieldUpdate_TransformsPriorityAndOptionValues() {
        seedRuntime();
        JiraFulfillerSupport.mappingOverrides.add(new Jira_Field_Mapping__c(
            Connector_Key__c = 'proj-a',
            Canonical_Field__c = 'priority',
            Backend_Field_Key__c = 'priority',
            Backend_Field_Label__c = 'Priority',
            Enabled__c = true,
            Allow_Agent_Update__c = true,
            Transform_Type__c = 'Direct'
        ));
        JiraFulfillerSupport.mappingOverrides.add(new Jira_Field_Mapping__c(
            Connector_Key__c = 'proj-a',
            Canonical_Field__c = 'impact',
            Backend_Field_Key__c = 'customfield_10004',
            Backend_Field_Label__c = 'Impact',
            Enabled__c = true,
            Allow_Agent_Update__c = true,
            Transform_Type__c = 'Option Id',
            Transform_Config_JSON__c = '{"High":"10010"}'
        ));
        JiraFulfillerSupport.IssueRef issueRef =
            JiraFulfillerSupport.validateAndResolveIssueKey('OPS-1');

        Test.startTest();
        JiraFulfillerSupport.PreparedUpdate prepared = JiraFulfillerSupport.prepareFieldUpdate(
            issueRef,
            new Map<String, Object>{ 'priority' => 'High', 'impact' => 'High' }
        );
        Test.stopTest();

        Assert.areEqual('High', JiraIntegrationSupport.stringValue(
            JiraIntegrationSupport.mapValue(prepared.fields.get('priority')).get('name')
        ), 'Priority should use Jira name shape');
        Assert.areEqual('10010', JiraIntegrationSupport.stringValue(
            JiraIntegrationSupport.mapValue(prepared.fields.get('customfield_10004')).get('id')
        ), 'Option alias should map to the configured Jira option id');
    }

    @isTest
    static void mappedFields_RendersScalarMapAndListValues() {
        seedRuntime();
        JiraFulfillerSupport.mappingOverrides.add(new Jira_Field_Mapping__c(
            Connector_Key__c = 'proj-a',
            Canonical_Field__c = 'impact',
            Backend_Field_Key__c = 'customfield_10004',
            Backend_Field_Label__c = 'Impact',
            Enabled__c = true,
            Use_In_Summary__c = true
        ));
        JiraFulfillerSupport.mappingOverrides.add(new Jira_Field_Mapping__c(
            Connector_Key__c = 'proj-a',
            Canonical_Field__c = 'labels',
            Backend_Field_Key__c = 'labels',
            Backend_Field_Label__c = 'Labels',
            Enabled__c = true,
            Use_In_Summary__c = true
        ));

        Test.startTest();
        String rendered = JiraFulfillerSupport.renderMappedFields(
            'proj-a',
            new Map<String, Object>{
                'summary' => 'Login broken',
                'customfield_10004' => new Map<String, Object>{ 'value' => 'High' },
                'labels' => new List<Object>{ 'identity', 'production' }
            }
        );
        String normalizedUrl = JiraFulfillerSupport.buildIssueUrl(
            new Jira_Connector_Profile__c(Browse_Base_Url__c = 'https://example.atlassian.net/'),
            'OPS-1'
        );
        Test.stopTest();

        Assert.isTrue(rendered.contains('Impact: High'), 'Map-valued fields should render their value');
        Assert.isTrue(rendered.contains('Labels: identity, production'), 'List-valued fields should render each value');
        Assert.areEqual('https://example.atlassian.net/browse/OPS-1', normalizedUrl, 'Issue URL should normalize a trailing slash');
    }

    @isTest
    static void pendingToken_RejectsDifferentUser() {
        seedRuntime();
        String token = 'FieldUpdate:otheruser';
        JiraFulfillerSupport.pendingTokenDetailOverrides = new Map<String, Map<String, Object>>{
            token => new Map<String, Object>{
                'issueKey' => 'OPS-1',
                'createdByUserId' => '005000000000001AAA',
                'payload' => new Map<String, Object>{ 'summary' => 'Changed' }
            }
        };

        Test.startTest();
        try {
            JiraFulfillerSupport.validatePendingToken('FieldUpdate', token, 'OPS-1');
            Assert.fail('A token created by another user must be rejected');
        } catch (JiraIntegrationSupport.JiraIntegrationException exceptionValue) {
            Assert.isTrue(exceptionValue.getMessage().contains('different user'), 'Error should identify token ownership mismatch');
        }
        Test.stopTest();
    }

    @isTest
    static void getTransitions_ReturnsSanitizedError() {
        seedRuntime();
        RouterMock mock = new RouterMock();
        mock.forcedStatus = 403;
        Test.setMock(HttpCalloutMock.class, mock);
        JiraFulfillerGetTransitionsAction.Request requestItem =
            new JiraFulfillerGetTransitionsAction.Request();
        requestItem.jiraIssueKey = 'OPS-1';

        Test.startTest();
        List<JiraFulfillerGetTransitionsAction.Response> responses =
            JiraFulfillerGetTransitionsAction.getTransitions(
                new List<JiraFulfillerGetTransitionsAction.Request>{ requestItem }
            );
        Test.stopTest();

        Assert.isFalse(responses[0].isSuccess, '403 callout should return a safe action failure');
        Assert.areEqual('AUTHORIZATION', responses[0].errorType, '403 should map to authorization');
    }

    @isTest
    static void searchAssignees_ReturnsSanitizedError() {
        seedRuntime();
        RouterMock mock = new RouterMock();
        mock.forcedStatus = 500;
        Test.setMock(HttpCalloutMock.class, mock);
        JiraFulfillerSearchAssigneeAction.Request requestItem =
            new JiraFulfillerSearchAssigneeAction.Request();
        requestItem.jiraIssueKey = 'OPS-1';

        Test.startTest();
        List<JiraFulfillerSearchAssigneeAction.Response> responses =
            JiraFulfillerSearchAssigneeAction.searchAssignees(
                new List<JiraFulfillerSearchAssigneeAction.Request>{ requestItem }
            );
        Test.stopTest();

        Assert.isFalse(responses[0].isSuccess, 'Unavailable Jira should return a safe action failure');
        Assert.areEqual('AVAILABILITY', responses[0].errorType, '500 should map to availability');
    }

    @isTest
    static void assignIssue_RejectsMismatchedConfirmation() {
        seedRuntime();
        Test.setMock(HttpCalloutMock.class, new RouterMock());
        JiraFulfillerAssignIssueAction.Request requestItem =
            new JiraFulfillerAssignIssueAction.Request();
        requestItem.jiraIssueKey = 'OPS-1';
        requestItem.assigneeAccountId = 'acc-1';
        requestItem.confirmedByEmployee = true;
        requestItem.confirmedJiraIssueKey = 'OPS-1';
        requestItem.confirmedAssigneeAccountId = 'different-account';

        Test.startTest();
        List<JiraFulfillerAssignIssueAction.Response> responses =
            JiraFulfillerAssignIssueAction.assignIssue(
                new List<JiraFulfillerAssignIssueAction.Request>{ requestItem }
            );
        Test.stopTest();

        Assert.isFalse(responses[0].isSuccess, 'Mismatched assignee confirmation must be rejected');
        Assert.areEqual('VALIDATION', responses[0].errorType, 'Mismatch should be a validation error');
    }
}