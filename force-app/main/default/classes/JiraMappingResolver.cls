public with sharing class JiraMappingResolver {
    public class ResolverException extends Exception {}

    public class TicketRequest {
        public String connectorKey;
        public String routeKey;
        public Id recordId;
        public String objectApiName;
        public String summary;
        public String description;
        public String requesterEmail;
        public String requesterName;
        public String reporterSalesforceUsername;
        public String priority;
        public String impact;
        public String urgency;
        public String severity;
        public String channel;
        public String sourceReference;
        public String status;
        public String assignee;
        public String comment;
    }

    public class ResolvedPayload {
        public Jira_Connector_Profile__c profile;
        public Map<String, Object> fields = new Map<String, Object>();
        public Set<String> lookupFieldKeys = new Set<String>();
        public List<String> validationMessages = new List<String>();
    }

    public static ResolvedPayload resolveCreate(TicketRequest request) {
        Jira_Connector_Profile__c profile = resolveProfile(request);
        ResolvedPayload payload = new ResolvedPayload();
        payload.profile = profile;
        List<Jira_Field_Mapping__c> mappings = loadMappings(profile.Connector_Key__c, 'create');
        Map<String, Object> recordValues = loadRecordValues(request, profile, mappings);
        Map<String, Jira_Connector_Field__c> backendFields = backendFieldsByKey(profile.Connector_Key__c);

        for (Jira_Field_Mapping__c mapping : mappings) {
            if (mapping.Use_For_Create__c != true) {
                continue;
            }
            Object sourceValue = sourceValue(mapping, request, recordValues);
            Object jiraValue = toJiraValue(mapping, sourceValue, request);
            if (jiraValue == null && mapping.Required_By_Jira__c == true) {
                payload.validationMessages.add(mapping.Backend_Field_Label__c + ' is required by Jira.');
            }
            if (jiraValue != null && !String.isBlank(mapping.Backend_Field_Key__c)) {
                payload.fields.put(mapping.Backend_Field_Key__c, jiraValue);
            }
            Jira_Connector_Field__c backendField = backendFields.get(mapping.Backend_Field_Key__c);
            if (backendField != null && backendField.Required__c == true && jiraValue == null) {
                payload.validationMessages.add(backendField.Display_Label__c + ' is required by Jira.');
            }
        }
        return payload;
    }

    public static ResolvedPayload resolveUpdate(TicketRequest request) {
        Jira_Connector_Profile__c profile = resolveProfile(request);
        ResolvedPayload payload = new ResolvedPayload();
        payload.profile = profile;
        List<Jira_Field_Mapping__c> mappings = loadMappings(profile.Connector_Key__c, 'update');
        Map<String, Object> recordValues = loadRecordValues(request, profile, mappings);
        for (Jira_Field_Mapping__c mapping : mappings) {
            if (mapping.Allow_Agent_Update__c != true) {
                continue;
            }
            Object jiraValue = toJiraValue(mapping, sourceValue(mapping, request, recordValues), request);
            if (jiraValue != null && !String.isBlank(mapping.Backend_Field_Key__c)) {
                payload.fields.put(mapping.Backend_Field_Key__c, jiraValue);
            }
        }
        return payload;
    }

    public static ResolvedPayload resolveLookup(TicketRequest request) {
        Jira_Connector_Profile__c profile = resolveProfile(request);
        ResolvedPayload payload = new ResolvedPayload();
        payload.profile = profile;
        for (Jira_Field_Mapping__c mapping : loadMappings(profile.Connector_Key__c, 'lookup')) {
            if ((mapping.Use_For_Lookup__c == true || mapping.Use_In_Summary__c == true) && !String.isBlank(mapping.Backend_Field_Key__c)) {
                payload.lookupFieldKeys.add(mapping.Backend_Field_Key__c);
            }
        }
        return payload;
    }

    private static Jira_Connector_Profile__c resolveProfile(TicketRequest request) {
        if (request == null) {
            request = new TicketRequest();
        }
        if (!String.isBlank(request.connectorKey)) {
            return JiraTicketGateway.getProfile(request.connectorKey);
        }
        if (!String.isBlank(request.routeKey)) {
            List<Jira_Connector_Profile__c> profiles = [
                SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                    Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                    Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Salesforce_Object_Label__c,
                    Route_Key__c, Is_Active_For_Agentforce__c
                FROM Jira_Connector_Profile__c
                WHERE Active__c = true AND Route_Key__c = :request.routeKey
                ORDER BY Is_Active_For_Agentforce__c DESC, Name ASC
                LIMIT 1
            ];
            if (!profiles.isEmpty()) {
                return profiles[0];
            }
        }
        if (!String.isBlank(request.objectApiName)) {
            List<Jira_Connector_Profile__c> profiles = [
                SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                    Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                    Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Salesforce_Object_Label__c,
                    Route_Key__c, Is_Active_For_Agentforce__c
                FROM Jira_Connector_Profile__c
                WHERE Active__c = true AND Salesforce_Object_Api_Name__c = :request.objectApiName
                ORDER BY Is_Active_For_Agentforce__c DESC, Name ASC
                LIMIT 1
            ];
            if (!profiles.isEmpty()) {
                return profiles[0];
            }
        }
        return JiraTicketGateway.getProfile(null);
    }

    private static List<Jira_Field_Mapping__c> loadMappings(String connectorKey, String operation) {
        String operationFilter = operation == 'update'
            ? 'Allow_Agent_Update__c = true'
            : operation == 'lookup'
                ? '(Use_For_Lookup__c = true OR Use_In_Summary__c = true)'
                : 'Use_For_Create__c = true';
        return Database.query(
            'SELECT Id, Connector_Key__c, Canonical_Field__c, Backend_Field_Key__c, Backend_Field_Label__c, Enabled__c, ' +
            'Use_For_Create__c, Use_For_Lookup__c, Use_In_Summary__c, Allow_Agent_Update__c, Transform_Type__c, ' +
            'Default_Value__c, Source_Type__c, Source_Object_Api_Name__c, Source_Field_Api_Name__c, Source_Field_Label__c, ' +
            'Direction__c, Transform_Config_JSON__c, Required_By_Jira__c, Validation_Status__c ' +
            'FROM Jira_Field_Mapping__c WHERE Connector_Key__c = :connectorKey AND Enabled__c = true AND ' + operationFilter
        );
    }

    private static Map<String, Jira_Connector_Field__c> backendFieldsByKey(String connectorKey) {
        Map<String, Jira_Connector_Field__c> fieldsByKey = new Map<String, Jira_Connector_Field__c>();
        for (Jira_Connector_Field__c fieldRecord : [
            SELECT Field_Key__c, Display_Label__c, Required__c
            FROM Jira_Connector_Field__c
            WHERE Connector_Key__c = :connectorKey
        ]) {
            fieldsByKey.put(fieldRecord.Field_Key__c, fieldRecord);
        }
        return fieldsByKey;
    }

    private static Map<String, Object> loadRecordValues(
        TicketRequest request,
        Jira_Connector_Profile__c profile,
        List<Jira_Field_Mapping__c> mappings
    ) {
        if (request == null || request.recordId == null) {
            return new Map<String, Object>();
        }
        String objectApiName = String.isBlank(request.objectApiName) ? profile.Salesforce_Object_Api_Name__c : request.objectApiName;
        if (String.isBlank(objectApiName) || !Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return new Map<String, Object>();
        }

        Map<String, Schema.SObjectField> describeFields = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        Set<String> fieldNames = new Set<String>{ 'Id' };
        for (Jira_Field_Mapping__c mapping : mappings) {
            if (
                mapping.Source_Type__c == 'Salesforce Field' &&
                !String.isBlank(mapping.Source_Field_Api_Name__c) &&
                describeFields.containsKey(mapping.Source_Field_Api_Name__c)
            ) {
                fieldNames.add(mapping.Source_Field_Api_Name__c);
            }
        }

        Id sourceRecordId = request.recordId;
        SObject record = Database.query(
            'SELECT ' + String.join(new List<String>(fieldNames), ',') +
            ' FROM ' + objectApiName +
            ' WHERE Id = :sourceRecordId LIMIT 1'
        );
        Map<String, Object> values = new Map<String, Object>();
        for (String fieldName : fieldNames) {
            values.put(fieldName, record.get(fieldName));
        }
        return values;
    }

    private static Object sourceValue(Jira_Field_Mapping__c mapping, TicketRequest request, Map<String, Object> recordValues) {
        if (mapping.Source_Type__c == 'Constant') {
            return mapping.Default_Value__c;
        }
        if (mapping.Source_Type__c == 'System Context') {
            return systemContextValue(mapping);
        }
        if (mapping.Source_Type__c == 'Salesforce Field') {
            Object recordValue = recordValues.get(mapping.Source_Field_Api_Name__c);
            return recordValue == null ? mapping.Default_Value__c : recordValue;
        }
        Object canonicalValue = canonicalValue(mapping.Canonical_Field__c, request);
        return canonicalValue == null ? mapping.Default_Value__c : canonicalValue;
    }

    private static Object toJiraValue(Jira_Field_Mapping__c mapping, Object sourceValue, TicketRequest request) {
        if (sourceValue == null || String.isBlank(String.valueOf(sourceValue))) {
            return null;
        }
        String transformType = String.isBlank(mapping.Transform_Type__c) ? 'Direct' : mapping.Transform_Type__c;
        if (transformType == 'ADF Document') {
            return JiraIntegrationSupport.buildAdfDocument(new List<String>{ String.valueOf(sourceValue) });
        }
        if (transformType == 'Option Id') {
            String optionId = optionIdFor(mapping.Transform_Config_JSON__c, String.valueOf(sourceValue));
            if (String.isBlank(optionId)) {
                optionId = String.valueOf(sourceValue);
            }
            return new Map<String, Object>{ 'id' => optionId };
        }
        if (transformType == 'User Mapping') {
            JiraIntegrationSupport.JiraUserMapping userMapping =
                JiraIntegrationSupport.getRequiredUserMapping(String.valueOf(sourceValue));
            return new Map<String, Object>{ 'id' => userMapping.jiraAccountId };
        }
        if (mapping.Backend_Field_Key__c == 'priority') {
            return new Map<String, Object>{ 'name' => String.valueOf(sourceValue) };
        }
        return sourceValue;
    }

    private static String optionIdFor(String transformConfigJson, String sourceValue) {
        if (String.isBlank(transformConfigJson) || String.isBlank(sourceValue)) {
            return null;
        }
        Object parsed = JSON.deserializeUntyped(transformConfigJson);
        if (!(parsed instanceof Map<String, Object>)) {
            return null;
        }
        Map<String, Object> optionMappings = (Map<String, Object>) parsed;
        Object match = optionMappings.get(sourceValue);
        return match == null ? null : String.valueOf(match);
    }

    private static Object canonicalValue(String canonicalField, TicketRequest request) {
        if (request == null || String.isBlank(canonicalField)) {
            return null;
        }
        if (canonicalField == 'summary') return request.summary;
        if (canonicalField == 'description') return request.description;
        if (canonicalField == 'requesterEmail') return request.requesterEmail;
        if (canonicalField == 'reporter') return request.reporterSalesforceUsername;
        if (canonicalField == 'priority') return request.priority;
        if (canonicalField == 'impact') return request.impact;
        if (canonicalField == 'urgency') return request.urgency;
        if (canonicalField == 'severity') return request.severity;
        if (canonicalField == 'status') return request.status;
        if (canonicalField == 'assignee') return request.assignee;
        if (canonicalField == 'comment') return request.comment;
        if (canonicalField == 'sourceReference') return request.sourceReference;
        if (canonicalField == 'channel') return request.channel;
        return null;
    }

    private static Object systemContextValue(Jira_Field_Mapping__c mapping) {
        if (mapping.Canonical_Field__c == 'sourceReference') {
            return UserInfo.getOrganizationId() + ':' + UserInfo.getUserId();
        }
        if (mapping.Canonical_Field__c == 'channel') {
            return 'Salesforce';
        }
        if (mapping.Canonical_Field__c == 'requesterEmail') {
            return UserInfo.getUserEmail();
        }
        return mapping.Default_Value__c;
    }
}
