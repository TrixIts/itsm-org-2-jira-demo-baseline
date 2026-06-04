public with sharing class JiraConnectorMappingController {
    private static final String DEFAULT_CONNECTOR_KEY = 'DefaultJira';

    public class WorkspaceDTO {
        @AuraEnabled public String connectorKey { get; set; }
        @AuraEnabled public String projectId { get; set; }
        @AuraEnabled public String projectKey { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String issueTypeId { get; set; }
        @AuraEnabled public String issueTypeName { get; set; }
        @AuraEnabled public String namedCredentialApiName { get; set; }
        @AuraEnabled public Datetime lastSyncAt { get; set; }
        @AuraEnabled public List<String> healthMessages { get; set; }
        @AuraEnabled public List<ConnectorProfileDTO> profiles { get; set; }
        @AuraEnabled public ConnectorProfileDTO selectedProfile { get; set; }
        @AuraEnabled public List<SelectOptionDTO> projectOptions { get; set; }
        @AuraEnabled public List<SelectOptionDTO> issueTypeOptions { get; set; }
        @AuraEnabled public List<SelectOptionDTO> salesforceObjectOptions { get; set; }
        @AuraEnabled public List<SelectOptionDTO> sourceFieldOptions { get; set; }
        @AuraEnabled public List<CanonicalFieldDTO> canonicalFields { get; set; }
        @AuraEnabled public List<BackendFieldDTO> backendFields { get; set; }
        @AuraEnabled public List<MappingDTO> mappings { get; set; }
        @AuraEnabled public String payloadPreview { get; set; }
        @AuraEnabled public String summaryPreview { get; set; }
    }

    public class SelectOptionDTO {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String description { get; set; }
    }

    public class ConnectorProfileDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String connectorKey { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String namedCredentialApiName { get; set; }
        @AuraEnabled public String projectId { get; set; }
        @AuraEnabled public String projectKey { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String issueTypeId { get; set; }
        @AuraEnabled public String issueTypeName { get; set; }
        @AuraEnabled public String browseBaseUrl { get; set; }
        @AuraEnabled public String openIssueJqlClause { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public String salesforceObjectApiName { get; set; }
        @AuraEnabled public String salesforceObjectLabel { get; set; }
        @AuraEnabled public String routeKey { get; set; }
        @AuraEnabled public Boolean activeForAgentforce { get; set; }
    }

    public class ProfileInputDTO {
        @AuraEnabled public String connectorKey { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String namedCredentialApiName { get; set; }
        @AuraEnabled public String projectId { get; set; }
        @AuraEnabled public String projectKey { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String issueTypeId { get; set; }
        @AuraEnabled public String issueTypeName { get; set; }
        @AuraEnabled public String browseBaseUrl { get; set; }
        @AuraEnabled public String openIssueJqlClause { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public String salesforceObjectApiName { get; set; }
        @AuraEnabled public String salesforceObjectLabel { get; set; }
        @AuraEnabled public String routeKey { get; set; }
        @AuraEnabled public Boolean activeForAgentforce { get; set; }
    }

    public class CanonicalFieldDTO {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String groupName { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean requiredByAgent { get; set; }
        @AuraEnabled public List<String> recommendedOperations { get; set; }
    }

    public class BackendFieldDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String schemaType { get; set; }
        @AuraEnabled public String operations { get; set; }
        @AuraEnabled public Boolean required { get; set; }
        @AuraEnabled public Boolean customField { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Datetime lastSeenAt { get; set; }
        @AuraEnabled public String allowedValuesJson { get; set; }
    }

    public class MappingDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String canonicalField { get; set; }
        @AuraEnabled public String backendFieldKey { get; set; }
        @AuraEnabled public String backendFieldLabel { get; set; }
        @AuraEnabled public Boolean enabled { get; set; }
        @AuraEnabled public Boolean useForCreate { get; set; }
        @AuraEnabled public Boolean useForLookup { get; set; }
        @AuraEnabled public Boolean useInSummary { get; set; }
        @AuraEnabled public Boolean allowAgentUpdate { get; set; }
        @AuraEnabled public Boolean askUserIfMissing { get; set; }
        @AuraEnabled public Boolean requiredByAgent { get; set; }
        @AuraEnabled public String transformType { get; set; }
        @AuraEnabled public String defaultValue { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public Datetime lastReviewedAt { get; set; }
        @AuraEnabled public String sourceType { get; set; }
        @AuraEnabled public String sourceObjectApiName { get; set; }
        @AuraEnabled public String sourceFieldApiName { get; set; }
        @AuraEnabled public String sourceFieldLabel { get; set; }
        @AuraEnabled public String direction { get; set; }
        @AuraEnabled public String transformConfigJson { get; set; }
        @AuraEnabled public Boolean requiredByJira { get; set; }
        @AuraEnabled public String validationStatus { get; set; }
    }

    public class MappingInputDTO {
        @AuraEnabled public String connectorKey { get; set; }
        @AuraEnabled public String canonicalField { get; set; }
        @AuraEnabled public String backendFieldKey { get; set; }
        @AuraEnabled public Boolean enabled { get; set; }
        @AuraEnabled public Boolean useForCreate { get; set; }
        @AuraEnabled public Boolean useForLookup { get; set; }
        @AuraEnabled public Boolean useInSummary { get; set; }
        @AuraEnabled public Boolean allowAgentUpdate { get; set; }
        @AuraEnabled public Boolean askUserIfMissing { get; set; }
        @AuraEnabled public String transformType { get; set; }
        @AuraEnabled public String defaultValue { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public String sourceType { get; set; }
        @AuraEnabled public String sourceObjectApiName { get; set; }
        @AuraEnabled public String sourceFieldApiName { get; set; }
        @AuraEnabled public String sourceFieldLabel { get; set; }
        @AuraEnabled public String direction { get; set; }
        @AuraEnabled public String transformConfigJson { get; set; }
    }

    @AuraEnabled
    public static WorkspaceDTO getWorkspace(String connectorKey) {
        return buildWorkspace(connectorKey);
    }

    @AuraEnabled
    public static List<SelectOptionDTO> getJiraProjects(String namedCredentialApiName) {
        String resolvedNamedCredential = resolveNamedCredential(namedCredentialApiName);
        Map<String, Object> response = sendJiraRequest(
            resolvedNamedCredential,
            'GET',
            '/rest/api/3/project/search',
            new Map<String, String>{ 'maxResults' => '100' },
            null
        );

        List<SelectOptionDTO> options = new List<SelectOptionDTO>();
        for (Object entry : JiraIntegrationSupport.listValue(response.get('values'))) {
            Map<String, Object> project = JiraIntegrationSupport.mapValue(entry);
            String idValue = JiraIntegrationSupport.stringValue(project.get('id'));
            String keyValue = JiraIntegrationSupport.stringValue(project.get('key'));
            String nameValue = JiraIntegrationSupport.stringValue(project.get('name'));
            options.add(option(nameValue + ' (' + keyValue + ')', idValue, keyValue));
        }
        return options;
    }

    @AuraEnabled
    public static List<SelectOptionDTO> getJiraIssueTypes(String namedCredentialApiName, String projectId) {
        if (String.isBlank(projectId)) {
            return new List<SelectOptionDTO>();
        }

        String resolvedNamedCredential = resolveNamedCredential(namedCredentialApiName);
        Object response = sendJiraRequestUntyped(
            resolvedNamedCredential,
            'GET',
            '/rest/api/3/issuetype/project',
            new Map<String, String>{ 'projectId' => projectId },
            null
        );

        List<SelectOptionDTO> options = new List<SelectOptionDTO>();
        for (Object entry : jiraIssueTypeEntries(response)) {
            Map<String, Object> issueType = JiraIntegrationSupport.mapValue(entry);
            String idValue = JiraIntegrationSupport.stringValue(issueType.get('id'));
            String nameValue = JiraIntegrationSupport.stringValue(issueType.get('name'));
            options.add(option(nameValue, idValue, JiraIntegrationSupport.stringValue(issueType.get('description'))));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOptionDTO> getSalesforceObjects() {
        List<SelectOptionDTO> options = new List<SelectOptionDTO>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<String> objectNames = new List<String>(globalDescribe.keySet());
        objectNames.sort();
        for (String objectName : objectNames) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(objectName).getDescribe();
            if (describeResult.isQueryable() && describeResult.isCreateable() && !describeResult.isDeprecatedAndHidden()) {
                options.add(option(describeResult.getLabel() + ' (' + objectName + ')', objectName, describeResult.getLabelPlural()));
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOptionDTO> getSalesforceFields(String objectApiName) {
        if (String.isBlank(objectApiName) || !Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return new List<SelectOptionDTO>();
        }

        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>(fields.keySet());
        fieldNames.sort();
        List<SelectOptionDTO> options = new List<SelectOptionDTO>();
        for (String fieldName : fieldNames) {
            Schema.DescribeFieldResult fieldDescribe = fields.get(fieldName).getDescribe();
            if (fieldDescribe.isAccessible() && !fieldDescribe.isDeprecatedAndHidden()) {
                options.add(option(fieldDescribe.getLabel() + ' (' + fieldName + ')', fieldName, String.valueOf(fieldDescribe.getType())));
            }
        }
        return options;
    }

    @AuraEnabled
    public static WorkspaceDTO syncFields(String connectorKey) {
        Jira_Connector_Profile__c profile = loadSelectedProfile(connectorKey);
        syncJiraFields(profile);
        return buildWorkspace(profile.Connector_Key__c);
    }

    @AuraEnabled
    public static WorkspaceDTO saveProfile(ProfileInputDTO input) {
        if (input == null) {
            throw new AuraHandledException('Provide a Jira connector profile before saving.');
        }
        if (String.isBlank(input.name)) {
            throw new AuraHandledException('Provide a profile name, such as Jira IT Incidents.');
        }
        if (String.isBlank(input.namedCredentialApiName)) {
            throw new AuraHandledException('Provide the Jira Named Credential API name.');
        }
        if (String.isBlank(input.projectId)) {
            throw new AuraHandledException('Provide the Jira project id.');
        }
        if (String.isBlank(input.issueTypeId)) {
            throw new AuraHandledException('Provide the Jira issue type id.');
        }

        String connectorKey = String.isBlank(input.connectorKey)
            ? generateConnectorKey(input.name, input.projectKey, input.projectId, input.issueTypeId)
            : input.connectorKey.trim();

        Jira_Connector_Profile__c profile = new Jira_Connector_Profile__c();
        profile.Connector_Key__c = connectorKey;
        profile.Name = input.name.trim();
        profile.Named_Credential_Api_Name__c = input.namedCredentialApiName.trim();
        profile.Project_Id__c = input.projectId.trim();
        profile.Project_Key__c = blankToNull(input.projectKey);
        profile.Project_Name__c = blankToNull(input.projectName);
        profile.Issue_Type_Id__c = input.issueTypeId.trim();
        profile.Issue_Type_Name__c = blankToNull(input.issueTypeName);
        profile.Browse_Base_Url__c = blankToNull(input.browseBaseUrl);
        profile.Open_Issue_Jql_Clause__c = blankToNull(input.openIssueJqlClause);
        profile.Active__c = input.active != false;
        profile.Salesforce_Object_Api_Name__c = blankToNull(input.salesforceObjectApiName);
        profile.Salesforce_Object_Label__c = String.isBlank(input.salesforceObjectLabel)
            ? salesforceObjectLabel(input.salesforceObjectApiName)
            : input.salesforceObjectLabel.trim();
        profile.Route_Key__c = blankToNull(input.routeKey);
        profile.Is_Active_For_Agentforce__c = input.activeForAgentforce == true;

        upsert profile Connector_Key__c;
        return buildWorkspace(connectorKey);
    }

    @AuraEnabled
    public static WorkspaceDTO saveMapping(MappingInputDTO input) {
        if (input == null || String.isBlank(input.canonicalField)) {
            throw new AuraHandledException('Choose an Agentforce field before saving a mapping.');
        }

        String connectorKey = resolveConnectorKey(input.connectorKey);
        CanonicalFieldDTO canonicalField = canonicalFieldsByKey().get(input.canonicalField);
        if (canonicalField == null) {
            throw new AuraHandledException('Unknown Agentforce field: ' + input.canonicalField);
        }

        BackendFieldDTO backendField;
        if (!String.isBlank(input.backendFieldKey)) {
            backendField = backendFieldsByKey(connectorKey).get(input.backendFieldKey);
            if (backendField == null) {
                throw new AuraHandledException('Sync Jira fields before mapping to ' + input.backendFieldKey + '.');
            }
        }

        Jira_Field_Mapping__c mappingRecord = findMapping(connectorKey, input.canonicalField);
        if (mappingRecord == null) {
            mappingRecord = new Jira_Field_Mapping__c();
            mappingRecord.Unique_Key__c = mappingUniqueKey(connectorKey, input.canonicalField);
            mappingRecord.Connector_Key__c = connectorKey;
            mappingRecord.Canonical_Field__c = input.canonicalField;
        }

        mappingRecord.Backend_Field_Key__c = blankToNull(input.backendFieldKey);
        mappingRecord.Backend_Field_Label__c = backendField == null ? null : backendField.label;
        mappingRecord.Enabled__c = boolValue(input.enabled);
        mappingRecord.Use_For_Create__c = boolValue(input.useForCreate);
        mappingRecord.Use_For_Lookup__c = boolValue(input.useForLookup);
        mappingRecord.Use_In_Summary__c = boolValue(input.useInSummary);
        mappingRecord.Allow_Agent_Update__c = boolValue(input.allowAgentUpdate);
        mappingRecord.Ask_User_If_Missing__c = boolValue(input.askUserIfMissing);
        mappingRecord.Required_By_Agent__c = canonicalField.requiredByAgent;
        mappingRecord.Transform_Type__c = String.isBlank(input.transformType) ? 'Direct' : input.transformType;
        mappingRecord.Default_Value__c = blankToNull(input.defaultValue);
        mappingRecord.Notes__c = input.notes;
        mappingRecord.Source_Type__c = String.isBlank(input.sourceType) ? 'Agentforce Field' : input.sourceType;
        mappingRecord.Source_Object_Api_Name__c = blankToNull(input.sourceObjectApiName);
        mappingRecord.Source_Field_Api_Name__c = blankToNull(input.sourceFieldApiName);
        mappingRecord.Source_Field_Label__c = blankToNull(input.sourceFieldLabel);
        mappingRecord.Direction__c = String.isBlank(input.direction) ? 'Salesforce to Jira' : input.direction;
        mappingRecord.Transform_Config_JSON__c = input.transformConfigJson;
        mappingRecord.Required_By_Jira__c = backendField == null ? false : backendField.required;
        mappingRecord.Validation_Status__c = validationStatus(mappingRecord, backendField);
        mappingRecord.Last_Reviewed_At__c = System.now();

        upsert mappingRecord Unique_Key__c;
        return buildWorkspace(connectorKey);
    }

    private static WorkspaceDTO buildWorkspace(String requestedConnectorKey) {
        Jira_Connector_Profile__c selectedProfile = loadSelectedProfile(requestedConnectorKey);
        String connectorKey = selectedProfile.Connector_Key__c;

        WorkspaceDTO workspace = new WorkspaceDTO();
        workspace.connectorKey = connectorKey;
        workspace.projectId = selectedProfile.Project_Id__c;
        workspace.projectKey = selectedProfile.Project_Key__c;
        workspace.projectName = selectedProfile.Project_Name__c;
        workspace.issueTypeId = selectedProfile.Issue_Type_Id__c;
        workspace.issueTypeName = selectedProfile.Issue_Type_Name__c;
        workspace.namedCredentialApiName = selectedProfile.Named_Credential_Api_Name__c;
        workspace.healthMessages = new List<String>();
        workspace.profiles = profileDTOs();
        workspace.selectedProfile = toProfileDTO(selectedProfile);
        workspace.projectOptions = new List<SelectOptionDTO>();
        workspace.issueTypeOptions = new List<SelectOptionDTO>();
        workspace.salesforceObjectOptions = prioritizedObjectOptions();
        workspace.sourceFieldOptions = getSalesforceFields(selectedProfile.Salesforce_Object_Api_Name__c);
        workspace.canonicalFields = canonicalFieldList();
        workspace.backendFields = loadBackendFields(connectorKey);
        workspace.mappings = loadMappings(connectorKey);
        workspace.payloadPreview = buildPayloadPreview(workspace.mappings);
        workspace.summaryPreview = buildSummaryPreview(workspace.mappings);

        if (String.isBlank(selectedProfile.Project_Id__c) || String.isBlank(selectedProfile.Issue_Type_Id__c)) {
            workspace.healthMessages.add('Jira project or issue type is not configured for this profile.');
        }
        if (String.isBlank(selectedProfile.Named_Credential_Api_Name__c)) {
            workspace.healthMessages.add('Jira Named Credential API name is not configured for this profile.');
        }

        for (BackendFieldDTO field : workspace.backendFields) {
            if (field.lastSeenAt != null && (workspace.lastSyncAt == null || field.lastSeenAt > workspace.lastSyncAt)) {
                workspace.lastSyncAt = field.lastSeenAt;
            }
        }

        Set<String> mappedBackendKeys = new Set<String>();
        for (MappingDTO mapping : workspace.mappings) {
            if (mapping.enabled == true && !String.isBlank(mapping.backendFieldKey)) {
                mappedBackendKeys.add(mapping.backendFieldKey);
            }
            if (mapping.enabled == true && mapping.validationStatus != 'Ready') {
                workspace.healthMessages.add(mapping.canonicalField + ' mapping is ' + mapping.validationStatus + '.');
            }
        }
        for (BackendFieldDTO field : workspace.backendFields) {
            if (field.required == true && !mappedBackendKeys.contains(field.fieldKey)) {
                workspace.healthMessages.add(field.label + ' is required by Jira but is not enabled in any mapping.');
            }
            if (field.status == 'Missing' && mappedBackendKeys.contains(field.fieldKey)) {
                workspace.healthMessages.add(field.label + ' is mapped but was not found in the latest Jira sync.');
            }
        }

        return workspace;
    }

    private static void syncJiraFields(Jira_Connector_Profile__c profile) {
        Map<String, Object> createMetadata = sendJiraRequest(
            profile,
            'GET',
            '/rest/api/3/issue/createmeta',
            new Map<String, String>{
                'projectIds' => profile.Project_Id__c,
                'issuetypeIds' => profile.Issue_Type_Id__c,
                'expand' => 'projects.issuetypes.fields'
            },
            null
        );

        Map<String, Object> fieldsMetadata = extractFieldsMetadata(createMetadata);
        if (fieldsMetadata.isEmpty()) {
            throw new AuraHandledException('Jira did not return any create fields for this profile project and issue type.');
        }

        String connectorKey = profile.Connector_Key__c;
        Map<String, Jira_Connector_Field__c> existingByKey = new Map<String, Jira_Connector_Field__c>();
        for (Jira_Connector_Field__c existing : [
            SELECT Id, Field_Key__c
            FROM Jira_Connector_Field__c
            WHERE Connector_Key__c = :connectorKey
        ]) {
            existingByKey.put(existing.Field_Key__c, existing);
        }

        Datetime syncTime = System.now();
        Set<String> seenFieldKeys = new Set<String>();
        List<Jira_Connector_Field__c> recordsToUpsert = new List<Jira_Connector_Field__c>();
        for (String fieldKey : fieldsMetadata.keySet()) {
            Map<String, Object> fieldMetadata = JiraIntegrationSupport.mapValue(fieldsMetadata.get(fieldKey));
            seenFieldKeys.add(fieldKey);

            Jira_Connector_Field__c fieldRecord = existingByKey.get(fieldKey);
            Boolean isNew = fieldRecord == null;
            if (isNew) {
                fieldRecord = new Jira_Connector_Field__c();
                fieldRecord.Connector_Key__c = connectorKey;
                fieldRecord.Field_Key__c = fieldKey;
            }

            fieldRecord.Unique_Key__c = connectorKey + '|' + fieldKey;
            fieldRecord.Display_Label__c = JiraIntegrationSupport.stringValue(fieldMetadata.get('name'));
            fieldRecord.Schema_Type__c = schemaType(fieldMetadata);
            fieldRecord.Operations__c = String.join(stringList(fieldMetadata.get('operations')), ', ');
            fieldRecord.Required__c = boolValue((Boolean) fieldMetadata.get('required'));
            fieldRecord.Custom_Field__c = fieldKey.startsWith('customfield_');
            fieldRecord.Allowed_Values_JSON__c = truncate(JSON.serialize(fieldMetadata.get('allowedValues')), 32768);
            fieldRecord.Raw_Metadata_JSON__c = truncate(JSON.serialize(fieldMetadata), 32768);
            fieldRecord.Status__c = isNew ? 'New' : 'Active';
            fieldRecord.Last_Seen_At__c = syncTime;
            recordsToUpsert.add(fieldRecord);
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert Unique_Key__c;
        }

        List<Jira_Connector_Field__c> recordsToMarkMissing = new List<Jira_Connector_Field__c>();
        for (String existingFieldKey : existingByKey.keySet()) {
            if (!seenFieldKeys.contains(existingFieldKey)) {
                recordsToMarkMissing.add(new Jira_Connector_Field__c(
                    Id = existingByKey.get(existingFieldKey).Id,
                    Status__c = 'Missing'
                ));
            }
        }
        if (!recordsToMarkMissing.isEmpty()) {
            update recordsToMarkMissing;
        }
    }

    private static Map<String, Object> extractFieldsMetadata(Map<String, Object> createMetadata) {
        List<Object> projects = JiraIntegrationSupport.listValue(createMetadata.get('projects'));
        if (projects.isEmpty()) {
            return new Map<String, Object>();
        }
        Map<String, Object> projectData = JiraIntegrationSupport.mapValue(projects[0]);
        List<Object> issueTypes = JiraIntegrationSupport.listValue(projectData.get('issuetypes'));
        if (issueTypes.isEmpty()) {
            return new Map<String, Object>();
        }
        return JiraIntegrationSupport.mapValue(JiraIntegrationSupport.mapValue(issueTypes[0]).get('fields'));
    }

    private static List<BackendFieldDTO> loadBackendFields(String connectorKey) {
        List<BackendFieldDTO> fields = new List<BackendFieldDTO>();
        for (Jira_Connector_Field__c fieldRecord : [
            SELECT Id, Field_Key__c, Display_Label__c, Schema_Type__c, Operations__c, Required__c,
                Custom_Field__c, Status__c, Last_Seen_At__c, Allowed_Values_JSON__c
            FROM Jira_Connector_Field__c
            WHERE Connector_Key__c = :connectorKey
            ORDER BY Required__c DESC, Display_Label__c ASC
        ]) {
            fields.add(toBackendFieldDTO(fieldRecord));
        }
        return fields;
    }

    private static List<MappingDTO> loadMappings(String connectorKey) {
        Map<String, Jira_Field_Mapping__c> recordsByCanonicalField = new Map<String, Jira_Field_Mapping__c>();
        for (Jira_Field_Mapping__c mappingRecord : [
            SELECT Id, Canonical_Field__c, Backend_Field_Key__c, Backend_Field_Label__c, Enabled__c,
                Use_For_Create__c, Use_For_Lookup__c, Use_In_Summary__c, Allow_Agent_Update__c,
                Ask_User_If_Missing__c, Required_By_Agent__c, Transform_Type__c, Default_Value__c,
                Notes__c, Last_Reviewed_At__c, Source_Type__c, Source_Object_Api_Name__c, Source_Field_Api_Name__c,
                Source_Field_Label__c, Direction__c, Transform_Config_JSON__c, Required_By_Jira__c, Validation_Status__c
            FROM Jira_Field_Mapping__c
            WHERE Connector_Key__c = :connectorKey
        ]) {
            recordsByCanonicalField.put(mappingRecord.Canonical_Field__c, mappingRecord);
        }

        List<MappingDTO> mappings = new List<MappingDTO>();
        for (CanonicalFieldDTO canonicalField : canonicalFieldList()) {
            Jira_Field_Mapping__c mappingRecord = recordsByCanonicalField.get(canonicalField.key);
            mappings.add(mappingRecord == null ? defaultMapping(canonicalField) : toMappingDTO(mappingRecord, canonicalField));
        }
        return mappings;
    }

    private static Jira_Field_Mapping__c findMapping(String connectorKey, String canonicalField) {
        String uniqueKey = mappingUniqueKey(connectorKey, canonicalField);
        List<Jira_Field_Mapping__c> mappings = [
            SELECT Id, Unique_Key__c, Connector_Key__c, Canonical_Field__c
            FROM Jira_Field_Mapping__c
            WHERE Unique_Key__c = :uniqueKey
            LIMIT 1
        ];
        return mappings.isEmpty() ? null : mappings[0];
    }

    private static Map<String, BackendFieldDTO> backendFieldsByKey(String connectorKey) {
        Map<String, BackendFieldDTO> fieldsByKey = new Map<String, BackendFieldDTO>();
        for (BackendFieldDTO backendField : loadBackendFields(connectorKey)) {
            fieldsByKey.put(backendField.fieldKey, backendField);
        }
        return fieldsByKey;
    }

    private static Map<String, CanonicalFieldDTO> canonicalFieldsByKey() {
        Map<String, CanonicalFieldDTO> fieldsByKey = new Map<String, CanonicalFieldDTO>();
        for (CanonicalFieldDTO canonicalField : canonicalFieldList()) {
            fieldsByKey.put(canonicalField.key, canonicalField);
        }
        return fieldsByKey;
    }

    private static List<CanonicalFieldDTO> canonicalFieldList() {
        return new List<CanonicalFieldDTO>{
            canonical('summary', 'Summary', 'Issue Details', 'Short employee-facing issue title.', true, new List<String>{ 'create', 'lookup', 'summary' }),
            canonical('description', 'Description', 'Issue Details', 'Full issue description grounded in the employee conversation.', true, new List<String>{ 'create', 'lookup', 'summary' }),
            canonical('requesterEmail', 'Requester Email', 'Identity', 'Employee email used for correlation or requester context.', false, new List<String>{ 'create', 'lookup' }),
            canonical('reporter', 'Reporter', 'Identity', 'Mapped Jira reporter account for the running Salesforce user.', true, new List<String>{ 'create', 'lookup' }),
            canonical('priority', 'Priority', 'Triage', 'Jira priority or equivalent impact signal.', false, new List<String>{ 'create', 'lookup', 'summary', 'update' }),
            canonical('impact', 'Impact', 'Triage', 'Business or employee impact level.', false, new List<String>{ 'create', 'lookup', 'summary', 'update' }),
            canonical('urgency', 'Urgency', 'Triage', 'How quickly the issue needs attention.', false, new List<String>{ 'create', 'lookup', 'summary', 'update' }),
            canonical('severity', 'Severity', 'Triage', 'Severity option used in operational escalation.', false, new List<String>{ 'create', 'lookup', 'summary', 'update' }),
            canonical('status', 'Status', 'Lifecycle', 'Backend ticket lifecycle status for responses back to users.', false, new List<String>{ 'lookup', 'summary' }),
            canonical('assignee', 'Assignee', 'Lifecycle', 'Current owner or queue working the issue.', false, new List<String>{ 'lookup', 'summary' }),
            canonical('comment', 'Comment', 'Collaboration', 'Employee-confirmed comment text added to an existing backend ticket.', false, new List<String>{ 'update' }),
            canonical('sourceReference', 'Source Reference', 'Audit', 'Correlation id or source record reference.', false, new List<String>{ 'create', 'lookup' }),
            canonical('channel', 'Channel', 'Audit', 'Experience channel that originated the ticket.', false, new List<String>{ 'create', 'lookup', 'summary' })
        };
    }

    private static CanonicalFieldDTO canonical(
        String key,
        String label,
        String groupName,
        String description,
        Boolean requiredByAgent,
        List<String> recommendedOperations
    ) {
        CanonicalFieldDTO field = new CanonicalFieldDTO();
        field.key = key;
        field.label = label;
        field.groupName = groupName;
        field.description = description;
        field.requiredByAgent = requiredByAgent;
        field.recommendedOperations = recommendedOperations;
        return field;
    }

    private static BackendFieldDTO toBackendFieldDTO(Jira_Connector_Field__c fieldRecord) {
        BackendFieldDTO dto = new BackendFieldDTO();
        dto.recordId = fieldRecord.Id;
        dto.fieldKey = fieldRecord.Field_Key__c;
        dto.label = fieldRecord.Display_Label__c;
        dto.schemaType = fieldRecord.Schema_Type__c;
        dto.operations = fieldRecord.Operations__c;
        dto.required = fieldRecord.Required__c;
        dto.customField = fieldRecord.Custom_Field__c;
        dto.status = fieldRecord.Status__c;
        dto.lastSeenAt = fieldRecord.Last_Seen_At__c;
        dto.allowedValuesJson = fieldRecord.Allowed_Values_JSON__c;
        return dto;
    }

    private static Jira_Connector_Profile__c loadSelectedProfile(String requestedConnectorKey) {
        ensureDefaultProfileExists();

        String connectorKey = String.isBlank(requestedConnectorKey) ? null : requestedConnectorKey.trim();
        List<Jira_Connector_Profile__c> profiles;
        if (String.isBlank(connectorKey)) {
            profiles = [
                SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                    Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                    Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Salesforce_Object_Label__c,
                    Route_Key__c, Is_Active_For_Agentforce__c
                FROM Jira_Connector_Profile__c
                WHERE Active__c = true
                ORDER BY Name ASC
                LIMIT 1
            ];
        } else {
            profiles = [
                SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                    Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                    Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Salesforce_Object_Label__c,
                    Route_Key__c, Is_Active_For_Agentforce__c
                FROM Jira_Connector_Profile__c
                WHERE Connector_Key__c = :connectorKey
                LIMIT 1
            ];
        }

        if (profiles.isEmpty()) {
            throw new AuraHandledException('No active Jira connector profile is configured.');
        }
        return profiles[0];
    }

    private static void ensureDefaultProfileExists() {
        if ([SELECT COUNT() FROM Jira_Connector_Profile__c] > 0) {
            return;
        }

        JiraIntegrationSupport.JiraConfiguration config = JiraIntegrationSupport.getConfiguration();
        Jira_Connector_Profile__c defaultProfile = new Jira_Connector_Profile__c();
        defaultProfile.Name = 'Default Jira IT';
        defaultProfile.Connector_Key__c = DEFAULT_CONNECTOR_KEY;
        defaultProfile.Named_Credential_Api_Name__c = config.namedCredentialApiName;
        defaultProfile.Project_Id__c = config.projectId;
        defaultProfile.Project_Key__c = config.projectKey;
        defaultProfile.Project_Name__c = String.isBlank(config.projectKey) ? 'Default Jira Project' : config.projectKey;
        defaultProfile.Issue_Type_Id__c = config.issueTypeId;
        defaultProfile.Issue_Type_Name__c = 'Default Issue Type';
        defaultProfile.Browse_Base_Url__c = config.browseBaseUrl;
        defaultProfile.Open_Issue_Jql_Clause__c = config.openIssueJqlClause;
        defaultProfile.Active__c = true;
        defaultProfile.Salesforce_Object_Api_Name__c = 'Incident';
        defaultProfile.Salesforce_Object_Label__c = salesforceObjectLabel('Incident');
        defaultProfile.Route_Key__c = 'incident';
        defaultProfile.Is_Active_For_Agentforce__c = false;
        insert defaultProfile;
    }

    private static List<ConnectorProfileDTO> profileDTOs() {
        ensureDefaultProfileExists();

        List<ConnectorProfileDTO> results = new List<ConnectorProfileDTO>();
        for (Jira_Connector_Profile__c profile : [
            SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Salesforce_Object_Label__c,
                Route_Key__c, Is_Active_For_Agentforce__c
            FROM Jira_Connector_Profile__c
            WHERE Active__c = true
            ORDER BY Name ASC
        ]) {
            results.add(toProfileDTO(profile));
        }
        return results;
    }

    private static ConnectorProfileDTO toProfileDTO(Jira_Connector_Profile__c profile) {
        ConnectorProfileDTO dto = new ConnectorProfileDTO();
        dto.recordId = profile.Id;
        dto.connectorKey = profile.Connector_Key__c;
        dto.name = profile.Name;
        dto.namedCredentialApiName = profile.Named_Credential_Api_Name__c;
        dto.projectId = profile.Project_Id__c;
        dto.projectKey = profile.Project_Key__c;
        dto.projectName = profile.Project_Name__c;
        dto.issueTypeId = profile.Issue_Type_Id__c;
        dto.issueTypeName = profile.Issue_Type_Name__c;
        dto.browseBaseUrl = profile.Browse_Base_Url__c;
        dto.openIssueJqlClause = profile.Open_Issue_Jql_Clause__c;
        dto.active = profile.Active__c;
        dto.salesforceObjectApiName = profile.Salesforce_Object_Api_Name__c;
        dto.salesforceObjectLabel = profile.Salesforce_Object_Label__c;
        dto.routeKey = profile.Route_Key__c;
        dto.activeForAgentforce = profile.Is_Active_For_Agentforce__c;
        return dto;
    }

    private static MappingDTO defaultMapping(CanonicalFieldDTO canonicalField) {
        MappingDTO dto = new MappingDTO();
        dto.canonicalField = canonicalField.key;
        dto.enabled = false;
        dto.useForCreate = canonicalField.recommendedOperations.contains('create');
        dto.useForLookup = canonicalField.recommendedOperations.contains('lookup');
        dto.useInSummary = canonicalField.recommendedOperations.contains('summary');
        dto.allowAgentUpdate = canonicalField.recommendedOperations.contains('update');
        dto.askUserIfMissing = canonicalField.requiredByAgent;
        dto.requiredByAgent = canonicalField.requiredByAgent;
        dto.transformType = 'Direct';
        dto.sourceType = 'Agentforce Field';
        dto.direction = 'Salesforce to Jira';
        dto.requiredByJira = false;
        dto.validationStatus = 'Needs Mapping';
        return dto;
    }

    private static MappingDTO toMappingDTO(Jira_Field_Mapping__c mappingRecord, CanonicalFieldDTO canonicalField) {
        MappingDTO dto = defaultMapping(canonicalField);
        dto.recordId = mappingRecord.Id;
        dto.backendFieldKey = mappingRecord.Backend_Field_Key__c;
        dto.backendFieldLabel = mappingRecord.Backend_Field_Label__c;
        dto.enabled = mappingRecord.Enabled__c;
        dto.useForCreate = mappingRecord.Use_For_Create__c;
        dto.useForLookup = mappingRecord.Use_For_Lookup__c;
        dto.useInSummary = mappingRecord.Use_In_Summary__c;
        dto.allowAgentUpdate = mappingRecord.Allow_Agent_Update__c;
        dto.askUserIfMissing = mappingRecord.Ask_User_If_Missing__c;
        dto.requiredByAgent = mappingRecord.Required_By_Agent__c;
        dto.transformType = String.isBlank(mappingRecord.Transform_Type__c) ? 'Direct' : mappingRecord.Transform_Type__c;
        dto.defaultValue = mappingRecord.Default_Value__c;
        dto.notes = mappingRecord.Notes__c;
        dto.lastReviewedAt = mappingRecord.Last_Reviewed_At__c;
        dto.sourceType = String.isBlank(mappingRecord.Source_Type__c) ? 'Agentforce Field' : mappingRecord.Source_Type__c;
        dto.sourceObjectApiName = mappingRecord.Source_Object_Api_Name__c;
        dto.sourceFieldApiName = mappingRecord.Source_Field_Api_Name__c;
        dto.sourceFieldLabel = mappingRecord.Source_Field_Label__c;
        dto.direction = String.isBlank(mappingRecord.Direction__c) ? 'Salesforce to Jira' : mappingRecord.Direction__c;
        dto.transformConfigJson = mappingRecord.Transform_Config_JSON__c;
        dto.requiredByJira = mappingRecord.Required_By_Jira__c;
        dto.validationStatus = String.isBlank(mappingRecord.Validation_Status__c) ? 'Needs Mapping' : mappingRecord.Validation_Status__c;
        return dto;
    }

    private static String schemaType(Map<String, Object> fieldMetadata) {
        Map<String, Object> schema = JiraIntegrationSupport.mapValue(fieldMetadata.get('schema'));
        String customType = JiraIntegrationSupport.stringValue(schema.get('custom'));
        String typeValue = JiraIntegrationSupport.stringValue(schema.get('type'));
        if (!String.isBlank(customType)) {
            Integer delimiterIndex = customType.lastIndexOf(':');
            return delimiterIndex >= 0 ? customType.substring(delimiterIndex + 1) : customType;
        }
        return typeValue;
    }

    private static List<String> stringList(Object value) {
        List<String> results = new List<String>();
        for (Object entry : JiraIntegrationSupport.listValue(value)) {
            String entryValue = JiraIntegrationSupport.stringValue(entry);
            if (!String.isBlank(entryValue)) {
                results.add(entryValue);
            }
        }
        return results;
    }

    private static SelectOptionDTO option(String label, String value, String description) {
        SelectOptionDTO dto = new SelectOptionDTO();
        dto.label = label;
        dto.value = value;
        dto.description = description;
        return dto;
    }

    private static List<Object> jiraIssueTypeEntries(Object response) {
        if (response instanceof List<Object>) {
            return (List<Object>) response;
        }
        Map<String, Object> responseMap = JiraIntegrationSupport.mapValue(response);
        List<Object> values = JiraIntegrationSupport.listValue(responseMap.get('values'));
        if (!values.isEmpty()) {
            return values;
        }
        return JiraIntegrationSupport.listValue(responseMap.get('issueTypes'));
    }

    private static String resolveNamedCredential(String namedCredentialApiName) {
        if (!String.isBlank(namedCredentialApiName)) {
            return namedCredentialApiName.trim();
        }
        return JiraIntegrationSupport.getConfiguration().namedCredentialApiName;
    }

    private static List<SelectOptionDTO> prioritizedObjectOptions() {
        List<SelectOptionDTO> allOptions = getSalesforceObjects();
        List<String> preferred = new List<String>{ 'Incident', 'Problem', 'ChangeRequest', 'Case' };
        List<SelectOptionDTO> prioritized = new List<SelectOptionDTO>();
        Set<String> usedValues = new Set<String>();
        for (String preferredName : preferred) {
            for (SelectOptionDTO optionEntry : allOptions) {
                if (optionEntry.value == preferredName) {
                    prioritized.add(optionEntry);
                    usedValues.add(optionEntry.value);
                    break;
                }
            }
        }
        for (SelectOptionDTO optionEntry : allOptions) {
            if (!usedValues.contains(optionEntry.value)) {
                prioritized.add(optionEntry);
            }
        }
        return prioritized;
    }

    private static String salesforceObjectLabel(String objectApiName) {
        if (String.isBlank(objectApiName) || !Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return null;
        }
        return Schema.getGlobalDescribe().get(objectApiName).getDescribe().getLabel();
    }

    private static String validationStatus(Jira_Field_Mapping__c mappingRecord, BackendFieldDTO backendField) {
        if (mappingRecord.Enabled__c != true) {
            return 'Disabled';
        }
        if (String.isBlank(mappingRecord.Backend_Field_Key__c) || backendField == null) {
            return 'Needs Mapping';
        }
        if (
            mappingRecord.Source_Type__c == 'Salesforce Field' &&
            (String.isBlank(mappingRecord.Source_Object_Api_Name__c) || String.isBlank(mappingRecord.Source_Field_Api_Name__c))
        ) {
            return 'Needs Mapping';
        }
        if (
            mappingRecord.Transform_Type__c == 'Option Id' &&
            String.isBlank(mappingRecord.Default_Value__c) &&
            String.isBlank(mappingRecord.Transform_Config_JSON__c)
        ) {
            return 'Needs Transform';
        }
        return 'Ready';
    }

    private static String buildPayloadPreview(List<MappingDTO> mappings) {
        Map<String, Object> fields = new Map<String, Object>();
        for (MappingDTO mapping : mappings) {
            if (mapping.enabled == true && mapping.useForCreate == true && !String.isBlank(mapping.backendFieldKey)) {
                fields.put(mapping.backendFieldKey, sampleValue(mapping));
            }
        }
        return JSON.serializePretty(new Map<String, Object>{ 'fields' => fields });
    }

    private static String buildSummaryPreview(List<MappingDTO> mappings) {
        List<String> summaryParts = new List<String>();
        for (MappingDTO mapping : mappings) {
            if (mapping.enabled == true && mapping.useInSummary == true && !String.isBlank(mapping.backendFieldLabel)) {
                summaryParts.add(mapping.backendFieldLabel + ': ' + String.valueOf(sampleValue(mapping)));
            }
        }
        return summaryParts.isEmpty()
            ? 'No employee-facing summary fields are enabled yet.'
            : 'Agentforce can summarize: ' + String.join(summaryParts, '; ');
    }

    private static Object sampleValue(MappingDTO mapping) {
        if (!String.isBlank(mapping.defaultValue)) {
            if (mapping.transformType == 'Option Id') {
                return new Map<String, Object>{ 'id' => mapping.defaultValue };
            }
            return mapping.defaultValue;
        }
        if (mapping.transformType == 'ADF Document') {
            return JiraIntegrationSupport.buildAdfDocument(new List<String>{ 'Sample employee issue description.' });
        }
        if (mapping.transformType == 'Option Id') {
            return new Map<String, Object>{ 'id' => 'mapped-option-id' };
        }
        if (mapping.transformType == 'User Mapping') {
            return new Map<String, Object>{ 'id' => 'mapped-jira-account-id' };
        }
        return 'sample ' + mapping.canonicalField;
    }

    private static Boolean boolValue(Boolean value) {
        return value == true;
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static String resolveConnectorKey(String requestedConnectorKey) {
        return loadSelectedProfile(requestedConnectorKey).Connector_Key__c;
    }

    private static String mappingUniqueKey(String connectorKey, String canonicalField) {
        return connectorKey + '|' + canonicalField;
    }

    private static String generateConnectorKey(String profileName, String projectKey, String projectId, String issueTypeId) {
        String base = String.isBlank(projectKey) ? profileName : projectKey + '_' + issueTypeId;
        String key = base.trim().replaceAll('[^A-Za-z0-9]+', '_');
        key = key.replaceAll('(^_+|_+$)', '');
        if (String.isBlank(key)) {
            key = 'Jira_' + projectId + '_' + issueTypeId;
        }
        return key.length() > 80 ? key.substring(0, 80) : key;
    }

    private static Map<String, Object> sendJiraRequest(
        Jira_Connector_Profile__c profile,
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        return sendJiraRequest(profile.Named_Credential_Api_Name__c, method, path, queryParams, body);
    }

    private static Map<String, Object> sendJiraRequest(
        String namedCredentialApiName,
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        Object parsed = sendJiraRequestUntyped(namedCredentialApiName, method, path, queryParams, body);
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }

        throw new AuraHandledException('Jira returned an unexpected metadata response shape.');
    }

    private static Object sendJiraRequestUntyped(
        String namedCredentialApiName,
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setTimeout(60000);

        String endpoint = 'callout:' + namedCredentialApiName + path;
        if (queryParams != null && !queryParams.isEmpty()) {
            List<String> encodedPairs = new List<String>();
            for (String key : queryParams.keySet()) {
                String value = queryParams.get(key);
                if (value != null) {
                    encodedPairs.add(
                        EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(value, 'UTF-8')
                    );
                }
            }
            if (!encodedPairs.isEmpty()) {
                endpoint += '?' + String.join(encodedPairs, '&');
            }
        }
        request.setEndpoint(endpoint);

        if (body != null) {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(body));
        }

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();
        if (statusCode < 200 || statusCode >= 300) {
            throw new AuraHandledException('Jira metadata sync failed: ' + response.getBody());
        }
        if (String.isBlank(response.getBody())) {
            return new Map<String, Object>();
        }

        return JSON.deserializeUntyped(response.getBody());
    }

    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value) || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
