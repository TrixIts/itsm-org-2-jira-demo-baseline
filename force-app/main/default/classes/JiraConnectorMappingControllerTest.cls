@IsTest
private class JiraConnectorMappingControllerTest {
    private class CreateMetadataMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            if (request.getMethod() == 'GET' && request.getEndpoint().contains('/rest/api/3/issue/createmeta')) {
                response.setStatusCode(200);
                response.setBody(
                    '{"projects":[{"id":"10001","issuetypes":[{"id":"10001","fields":{' +
                    '"summary":{"required":true,"name":"Summary","schema":{"type":"string"},"operations":["set"]},' +
                    '"description":{"required":true,"name":"Description","schema":{"type":"rich_text"},"operations":["set"]},' +
                    '"customfield_10043":{"required":false,"name":"Urgency","schema":{"type":"option","custom":"com.atlassian.jira.plugin.system.customfieldtypes:select"},"operations":["set"],"allowedValues":[{"id":"10022","value":"Medium"}]}' +
                    '}}]}]}'
                );
                return response;
            }

            response.setStatusCode(400);
            response.setBody('{"errorMessages":["Unexpected mock request"]}');
            return response;
        }
    }

    private class IssueTypeArrayMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            if (request.getMethod() == 'GET' && request.getEndpoint().contains('/rest/api/3/issuetype/project')) {
                response.setStatusCode(200);
                response.setBody('[{"id":"10001","name":"Incident","description":"Employee incident"},{"id":"10002","name":"Task"}]');
                return response;
            }

            response.setStatusCode(400);
            response.setBody('{"errorMessages":["Unexpected mock request"]}');
            return response;
        }
    }

    private static void applyConfigOverride() {
        JiraIntegrationSupport.JiraConfiguration config = new JiraIntegrationSupport.JiraConfiguration();
        config.namedCredentialApiName = 'Jira_Named_Credential';
        config.projectId = '10001';
        config.issueTypeId = '10001';
        config.projectKey = 'IT';
        config.browseBaseUrl = 'https://example.atlassian.net';
        config.openIssueJqlClause = 'statusCategory != Done ORDER BY updated DESC';
        JiraIntegrationSupport.configOverride = config;
    }

    @TestSetup
    static void setupProfiles() {
        insert new Jira_Connector_Profile__c(
            Name = 'Default Jira IT',
            Connector_Key__c = 'DefaultJira',
            Named_Credential_Api_Name__c = 'Jira_Named_Credential',
            Project_Id__c = '10001',
            Project_Key__c = 'IT',
            Project_Name__c = 'IT',
            Issue_Type_Id__c = '10001',
            Issue_Type_Name__c = 'Incident',
            Browse_Base_Url__c = 'https://example.atlassian.net',
            Open_Issue_Jql_Clause__c = 'statusCategory != Done ORDER BY updated DESC',
            Active__c = true
        );
        insert new Jira_Connector_Field__c(
            Unique_Key__c = 'DefaultJira|summary',
            Connector_Key__c = 'DefaultJira',
            Field_Key__c = 'summary',
            Display_Label__c = 'Old Summary',
            Schema_Type__c = 'string',
            Operations__c = 'set',
            Required__c = false,
            Custom_Field__c = false,
            Status__c = 'Active',
            Last_Seen_At__c = System.now().addDays(-1)
        );
    }

    @IsTest
    static void syncFields_discoversJiraCreateMetadata() {
        applyConfigOverride();
        Test.setMock(HttpCalloutMock.class, new CreateMetadataMock());

        Test.startTest();
        JiraConnectorMappingController.WorkspaceDTO workspace = JiraConnectorMappingController.syncFields('DefaultJira');
        Test.stopTest();

        System.assertEquals('DefaultJira', workspace.connectorKey);
        System.assertEquals('10001', workspace.projectId);
        System.assertEquals(1, workspace.profiles.size());
        System.assertEquals(3, workspace.backendFields.size());
        System.assertEquals(13, workspace.canonicalFields.size());

        List<Jira_Connector_Field__c> fields = [
            SELECT Field_Key__c, Display_Label__c, Required__c, Custom_Field__c, Status__c, Allowed_Values_JSON__c
            FROM Jira_Connector_Field__c
            WHERE Connector_Key__c = 'DefaultJira'
            ORDER BY Field_Key__c
        ];
        System.assertEquals(3, fields.size());
        System.assertEquals('customfield_10043', fields[0].Field_Key__c);
        System.assertEquals(true, fields[0].Custom_Field__c);
        System.assert(fields[0].Allowed_Values_JSON__c.contains('Medium'));
        System.assertEquals('summary', fields[2].Field_Key__c);
        System.assertEquals('Summary', fields[2].Display_Label__c);
    }

    @IsTest
    static void getJiraIssueTypes_handlesTopLevelArrayResponse() {
        applyConfigOverride();
        Test.setMock(HttpCalloutMock.class, new IssueTypeArrayMock());

        Test.startTest();
        List<JiraConnectorMappingController.SelectOptionDTO> options =
            JiraConnectorMappingController.getJiraIssueTypes('Jira_Named_Credential', '10001');
        Test.stopTest();

        System.assertEquals(2, options.size());
        System.assertEquals('Incident', options[0].label);
        System.assertEquals('10001', options[0].value);
    }

    @IsTest
    static void saveMapping_persistsAgentforcePolicy() {
        applyConfigOverride();

        JiraConnectorMappingController.MappingInputDTO input = new JiraConnectorMappingController.MappingInputDTO();
        input.connectorKey = 'DefaultJira';
        input.canonicalField = 'summary';
        input.backendFieldKey = 'summary';
        input.enabled = true;
        input.useForCreate = true;
        input.useForLookup = true;
        input.useInSummary = true;
        input.allowAgentUpdate = false;
        input.askUserIfMissing = true;
        input.transformType = 'Direct';
        input.notes = 'Primary Jira title mapping.';

        Test.startTest();
        JiraConnectorMappingController.WorkspaceDTO workspace = JiraConnectorMappingController.saveMapping(input);
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Jira_Field_Mapping__c
            WHERE Unique_Key__c = 'DefaultJira|summary'
            AND Enabled__c = true
            AND Use_For_Create__c = true
        ]);
        System.assertEquals(1, workspace.mappings.size() > 0 ? 1 : 0);
    }

    @IsTest
    static void saveProfile_createsIndependentConnectorScope() {
        JiraConnectorMappingController.ProfileInputDTO input = new JiraConnectorMappingController.ProfileInputDTO();
        input.name = 'Security Jira Requests';
        input.namedCredentialApiName = 'Jira_Named_Credential';
        input.projectId = '20001';
        input.projectKey = 'SEC';
        input.projectName = 'Security';
        input.issueTypeId = '10004';
        input.issueTypeName = 'Task';
        input.browseBaseUrl = 'https://example.atlassian.net';
        input.openIssueJqlClause = 'statusCategory != Done ORDER BY updated DESC';
        input.active = true;

        Test.startTest();
        JiraConnectorMappingController.WorkspaceDTO workspace = JiraConnectorMappingController.saveProfile(input);
        Test.stopTest();

        System.assertEquals('SEC_10004', workspace.connectorKey);
        System.assertEquals('Security', workspace.projectName);
        System.assertEquals('10004', workspace.issueTypeId);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM Jira_Connector_Profile__c
            WHERE Connector_Key__c = 'SEC_10004'
            AND Project_Id__c = '20001'
        ]);
        System.assert(workspace.profiles.size() >= 2);
    }
}
