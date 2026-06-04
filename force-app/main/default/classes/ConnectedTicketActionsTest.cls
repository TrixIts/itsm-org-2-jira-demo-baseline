@IsTest
private class ConnectedTicketActionsTest {
    private class JiraRuntimeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            if (request.getMethod() == 'POST' && request.getEndpoint().endsWith('/rest/api/3/issue')) {
                response.setStatusCode(201);
                response.setBody('{"id":"10099","key":"IT-99"}');
                return response;
            }
            if (request.getMethod() == 'GET' && request.getEndpoint().contains('/rest/api/3/issue/IT-99')) {
                response.setStatusCode(200);
                response.setBody(
                    '{"id":"10099","key":"IT-99","fields":{"summary":"Laptop issue","updated":"2026-05-26T10:00:00.000-0700",' +
                    '"status":{"name":"In Progress","statusCategory":{"key":"indeterminate"}},"priority":{"name":"High"},' +
                    '"reporter":{"displayName":"Scott Hendrix"},"comment":{"comments":[]}},"changelog":{"histories":[]}}'
                );
                return response;
            }
            if (request.getMethod() == 'PUT' && request.getEndpoint().contains('/rest/api/3/issue/IT-99')) {
                response.setStatusCode(204);
                response.setBody('');
                return response;
            }
            if (request.getMethod() == 'POST' && request.getEndpoint().contains('/rest/api/3/issue/IT-99/comment')) {
                response.setStatusCode(201);
                response.setBody('{"id":"20001"}');
                return response;
            }
            response.setStatusCode(400);
            response.setBody('{"errorMessages":["Unexpected request"]}');
            return response;
        }
    }

    @TestSetup
    static void setupConnector() {
        insert new Jira_Connector_Profile__c(
            Name = 'Runtime Jira IT',
            Connector_Key__c = 'RuntimeJira',
            Named_Credential_Api_Name__c = 'Jira_Named_Credential',
            Project_Id__c = '10001',
            Project_Key__c = 'IT',
            Project_Name__c = 'IT',
            Issue_Type_Id__c = '10001',
            Issue_Type_Name__c = 'Incident',
            Browse_Base_Url__c = 'https://example.atlassian.net',
            Open_Issue_Jql_Clause__c = 'statusCategory != Done ORDER BY updated DESC',
            Active__c = true,
            Is_Active_For_Agentforce__c = true,
            Route_Key__c = 'incident'
        );

        insert new List<Jira_Connector_Field__c>{
            connectorField('summary', 'Summary', 'string', true),
            connectorField('description', 'Description', 'rich_text', false),
            connectorField('priority', 'Priority', 'priority', false),
            connectorField('comment', 'Comment', 'string', false)
        };

        insert new List<Jira_Field_Mapping__c>{
            mapping('summary', 'summary', 'Summary', 'Direct', true, true, true, false),
            mapping('description', 'description', 'Description', 'ADF Document', true, false, false, false),
            mapping('priority', 'priority', 'Priority', 'Direct', true, true, true, true),
            mapping('comment', 'comment', 'Comment', 'Direct', false, false, false, true)
        };
    }

    @IsTest
    static void createLookupAndUpdateUseConnectorRuntime() {
        Test.setMock(HttpCalloutMock.class, new JiraRuntimeMock());

        ConnectedTicketCreateAction.Request createRequest = new ConnectedTicketCreateAction.Request();
        createRequest.connectorKey = 'RuntimeJira';
        createRequest.summary = 'Laptop issue';
        createRequest.description = 'Laptop will not power on.';
        createRequest.priority = 'High';
        createRequest.channel = 'Slack';

        ConnectedTicketLookupAction.Request lookupRequest = new ConnectedTicketLookupAction.Request();
        lookupRequest.connectorKey = 'RuntimeJira';
        lookupRequest.jiraIssueKey = 'IT-99';

        ConnectedTicketUpdateAction.Request updateRequest = new ConnectedTicketUpdateAction.Request();
        updateRequest.connectorKey = 'RuntimeJira';
        updateRequest.jiraIssueKey = 'IT-99';
        updateRequest.priority = 'High';
        updateRequest.comment = 'Employee confirmed the issue persists.';

        Test.startTest();
        List<ConnectedTicketCreateAction.Result> createResults =
            ConnectedTicketCreateAction.createTickets(new List<ConnectedTicketCreateAction.Request>{ createRequest });
        List<ConnectedTicketLookupAction.Result> lookupResults =
            ConnectedTicketLookupAction.lookupTickets(new List<ConnectedTicketLookupAction.Request>{ lookupRequest });
        List<ConnectedTicketUpdateAction.Result> updateResults =
            ConnectedTicketUpdateAction.updateTickets(new List<ConnectedTicketUpdateAction.Request>{ updateRequest });
        Test.stopTest();

        System.assertEquals(true, createResults[0].success);
        System.assertEquals('IT-99', createResults[0].jiraIssueKey);
        System.assert(lookupResults[0].employeeSummary.contains('Laptop issue'));
        System.assertEquals(true, updateResults[0].success);
    }

    @IsTest
    static void resolverSupportsSourceFieldsConstantsAndRoutes() {
        insert new Jira_Connector_Profile__c(
            Name = 'Case Jira',
            Connector_Key__c = 'CaseJira',
            Named_Credential_Api_Name__c = 'Jira_Named_Credential',
            Project_Id__c = '10002',
            Project_Key__c = 'CASE',
            Project_Name__c = 'Case Project',
            Issue_Type_Id__c = '10002',
            Issue_Type_Name__c = 'Task',
            Browse_Base_Url__c = 'https://example.atlassian.net',
            Open_Issue_Jql_Clause__c = 'statusCategory != Done ORDER BY updated DESC',
            Active__c = true,
            Is_Active_For_Agentforce__c = true,
            Route_Key__c = 'case',
            Salesforce_Object_Api_Name__c = 'Case',
            Salesforce_Object_Label__c = 'Case'
        );
        insert new List<Jira_Connector_Field__c>{
            new Jira_Connector_Field__c(
                Unique_Key__c = 'CaseJira|summary',
                Connector_Key__c = 'CaseJira',
                Field_Key__c = 'summary',
                Display_Label__c = 'Summary',
                Schema_Type__c = 'string',
                Operations__c = 'set',
                Required__c = true,
                Custom_Field__c = false,
                Status__c = 'Active',
                Last_Seen_At__c = System.now()
            ),
            new Jira_Connector_Field__c(
                Unique_Key__c = 'CaseJira|customfield_10043',
                Connector_Key__c = 'CaseJira',
                Field_Key__c = 'customfield_10043',
                Display_Label__c = 'Urgency',
                Schema_Type__c = 'select',
                Operations__c = 'set',
                Required__c = false,
                Custom_Field__c = true,
                Status__c = 'Active',
                Last_Seen_At__c = System.now()
            ),
            new Jira_Connector_Field__c(
                Unique_Key__c = 'CaseJira|labels',
                Connector_Key__c = 'CaseJira',
                Field_Key__c = 'labels',
                Display_Label__c = 'Labels',
                Schema_Type__c = 'array',
                Operations__c = 'set',
                Required__c = false,
                Custom_Field__c = false,
                Status__c = 'Active',
                Last_Seen_At__c = System.now()
            ),
            new Jira_Connector_Field__c(
                Unique_Key__c = 'CaseJira|customfield_channel',
                Connector_Key__c = 'CaseJira',
                Field_Key__c = 'customfield_channel',
                Display_Label__c = 'Channel',
                Schema_Type__c = 'string',
                Operations__c = 'set',
                Required__c = false,
                Custom_Field__c = true,
                Status__c = 'Active',
                Last_Seen_At__c = System.now()
            )
        };
        insert new List<Jira_Field_Mapping__c>{
            new Jira_Field_Mapping__c(
                Unique_Key__c = 'CaseJira|summary',
                Connector_Key__c = 'CaseJira',
                Canonical_Field__c = 'summary',
                Backend_Field_Key__c = 'summary',
                Backend_Field_Label__c = 'Summary',
                Enabled__c = true,
                Use_For_Create__c = true,
                Transform_Type__c = 'Direct',
                Source_Type__c = 'Salesforce Field',
                Source_Object_Api_Name__c = 'Case',
                Source_Field_Api_Name__c = 'Subject',
                Source_Field_Label__c = 'Subject',
                Direction__c = 'Salesforce to Jira',
                Required_By_Jira__c = true,
                Validation_Status__c = 'Ready'
            ),
            new Jira_Field_Mapping__c(
                Unique_Key__c = 'CaseJira|urgency',
                Connector_Key__c = 'CaseJira',
                Canonical_Field__c = 'urgency',
                Backend_Field_Key__c = 'customfield_10043',
                Backend_Field_Label__c = 'Urgency',
                Enabled__c = true,
                Use_For_Create__c = true,
                Transform_Type__c = 'Option Id',
                Transform_Config_JSON__c = '{"High":"10043"}',
                Source_Type__c = 'Agentforce Field',
                Direction__c = 'Salesforce to Jira',
                Validation_Status__c = 'Ready'
            ),
            new Jira_Field_Mapping__c(
                Unique_Key__c = 'CaseJira|sourceReference',
                Connector_Key__c = 'CaseJira',
                Canonical_Field__c = 'sourceReference',
                Backend_Field_Key__c = 'labels',
                Backend_Field_Label__c = 'Labels',
                Enabled__c = true,
                Use_For_Create__c = true,
                Transform_Type__c = 'Direct',
                Source_Type__c = 'Constant',
                Default_Value__c = 'salesforce-case',
                Direction__c = 'Salesforce to Jira',
                Validation_Status__c = 'Ready'
            ),
            new Jira_Field_Mapping__c(
                Unique_Key__c = 'CaseJira|channel',
                Connector_Key__c = 'CaseJira',
                Canonical_Field__c = 'channel',
                Backend_Field_Key__c = 'customfield_channel',
                Backend_Field_Label__c = 'Channel',
                Enabled__c = true,
                Use_For_Create__c = true,
                Transform_Type__c = 'Direct',
                Source_Type__c = 'System Context',
                Direction__c = 'Salesforce to Jira',
                Validation_Status__c = 'Ready'
            )
        };

        Case sourceCase = new Case(Subject = 'VPN access issue', Origin = 'Phone');
        insert sourceCase;

        JiraMappingResolver.TicketRequest request = new JiraMappingResolver.TicketRequest();
        request.routeKey = 'case';
        request.objectApiName = 'Case';
        request.recordId = sourceCase.Id;
        request.urgency = 'High';

        Test.startTest();
        JiraMappingResolver.ResolvedPayload payload = JiraMappingResolver.resolveCreate(request);
        JiraMappingResolver.ResolvedPayload lookupPayload = JiraMappingResolver.resolveLookup(request);
        Test.stopTest();

        System.assertEquals('CaseJira', payload.profile.Connector_Key__c);
        System.assertEquals('VPN access issue', payload.fields.get('summary'));
        System.assertEquals('10043', JiraIntegrationSupport.stringValue(JiraIntegrationSupport.mapValue(payload.fields.get('customfield_10043')).get('id')));
        System.assertEquals('salesforce-case', payload.fields.get('labels'));
        System.assert(!String.isBlank(JiraIntegrationSupport.stringValue(payload.fields.get('customfield_channel'))));
        System.assertEquals(true, lookupPayload.lookupFieldKeys.isEmpty());
    }

    @IsTest
    static void resolverReportsRequiredMappingGapsAndDefaultProfile() {
        JiraMappingResolver.TicketRequest missingRequest = new JiraMappingResolver.TicketRequest();
        missingRequest.priority = 'High';

        Test.startTest();
        JiraMappingResolver.ResolvedPayload createPayload = JiraMappingResolver.resolveCreate(missingRequest);
        JiraMappingResolver.ResolvedPayload lookupPayload = JiraMappingResolver.resolveLookup(new JiraMappingResolver.TicketRequest());
        Test.stopTest();

        System.assertEquals('RuntimeJira', createPayload.profile.Connector_Key__c);
        System.assertEquals(true, createPayload.validationMessages.size() > 0);
        System.assertEquals(true, lookupPayload.lookupFieldKeys.contains('summary'));
    }

    private static Jira_Connector_Field__c connectorField(String key, String label, String schemaType, Boolean required) {
        return new Jira_Connector_Field__c(
            Unique_Key__c = 'RuntimeJira|' + key,
            Connector_Key__c = 'RuntimeJira',
            Field_Key__c = key,
            Display_Label__c = label,
            Schema_Type__c = schemaType,
            Operations__c = 'set',
            Required__c = required,
            Custom_Field__c = false,
            Status__c = 'Active',
            Last_Seen_At__c = System.now()
        );
    }

    private static Jira_Field_Mapping__c mapping(
        String canonicalField,
        String backendFieldKey,
        String backendFieldLabel,
        String transformType,
        Boolean useForCreate,
        Boolean useForLookup,
        Boolean useInSummary,
        Boolean allowUpdate
    ) {
        return new Jira_Field_Mapping__c(
            Unique_Key__c = 'RuntimeJira|' + canonicalField,
            Connector_Key__c = 'RuntimeJira',
            Canonical_Field__c = canonicalField,
            Backend_Field_Key__c = backendFieldKey,
            Backend_Field_Label__c = backendFieldLabel,
            Enabled__c = true,
            Use_For_Create__c = useForCreate,
            Use_For_Lookup__c = useForLookup,
            Use_In_Summary__c = useInSummary,
            Allow_Agent_Update__c = allowUpdate,
            Ask_User_If_Missing__c = false,
            Required_By_Agent__c = canonicalField == 'summary',
            Transform_Type__c = transformType,
            Source_Type__c = 'Agentforce Field',
            Direction__c = 'Salesforce to Jira',
            Required_By_Jira__c = canonicalField == 'summary',
            Validation_Status__c = 'Ready'
        );
    }
}
