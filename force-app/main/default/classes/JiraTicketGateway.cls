public with sharing class JiraTicketGateway {
    public class JiraGatewayException extends Exception {}

    public static Jira_Connector_Profile__c getProfile(String connectorKey) {
        List<Jira_Connector_Profile__c> profiles;
        if (String.isBlank(connectorKey)) {
            profiles = [
                SELECT Id, Name, Connector_Key__c, Named_Credential_Api_Name__c, Project_Id__c, Project_Key__c,
                    Project_Name__c, Issue_Type_Id__c, Issue_Type_Name__c, Browse_Base_Url__c,
                    Open_Issue_Jql_Clause__c, Active__c, Salesforce_Object_Api_Name__c, Salesforce_Object_Label__c,
                    Route_Key__c, Is_Active_For_Agentforce__c
                FROM Jira_Connector_Profile__c
                WHERE Active__c = true
                ORDER BY Is_Active_For_Agentforce__c DESC, Name ASC
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
            throw new JiraGatewayException('No Jira connector profile found for ' + connectorKey + '.');
        }
        return profiles[0];
    }

    public static Map<String, Object> createIssue(Jira_Connector_Profile__c profile, Map<String, Object> fields) {
        Map<String, Object> fieldsWithScope = new Map<String, Object>(fields);
        fieldsWithScope.put('project', new Map<String, Object>{ 'id' => profile.Project_Id__c });
        fieldsWithScope.put('issuetype', new Map<String, Object>{ 'id' => profile.Issue_Type_Id__c });
        return sendRequest(profile, 'POST', '/rest/api/3/issue', null, new Map<String, Object>{ 'fields' => fieldsWithScope });
    }

    public static Map<String, Object> getIssueByKey(
        Jira_Connector_Profile__c profile,
        String jiraIssueKey,
        Set<String> fieldKeys
    ) {
        Set<String> resolvedFieldKeys = new Set<String>{ 'summary', 'status', 'reporter', 'assignee', 'updated', 'comment', 'priority', 'resolution' };
        if (fieldKeys != null) {
            resolvedFieldKeys.addAll(fieldKeys);
        }
        return sendRequest(
            profile,
            'GET',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(jiraIssueKey, 'UTF-8'),
            new Map<String, String>{
                'fields' => String.join(new List<String>(resolvedFieldKeys), ','),
                'expand' => 'changelog'
            },
            null
        );
    }

    public static void updateIssue(Jira_Connector_Profile__c profile, String jiraIssueIdOrKey, Map<String, Object> fields) {
        if (fields == null || fields.isEmpty()) {
            return;
        }
        sendRequest(
            profile,
            'PUT',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(jiraIssueIdOrKey, 'UTF-8'),
            null,
            new Map<String, Object>{ 'fields' => fields }
        );
    }

    public static void addComment(Jira_Connector_Profile__c profile, String jiraIssueIdOrKey, String commentText) {
        if (String.isBlank(commentText)) {
            return;
        }
        sendRequest(
            profile,
            'POST',
            '/rest/api/3/issue/' + EncodingUtil.urlEncode(jiraIssueIdOrKey, 'UTF-8') + '/comment',
            null,
            new Map<String, Object>{
                'body' => JiraIntegrationSupport.buildAdfDocument(
                    JiraIntegrationSupport.buildStampedCommentLines(commentText)
                )
            }
        );
    }

    public static String buildIssueUrl(Jira_Connector_Profile__c profile, String jiraIssueKey) {
        if (String.isBlank(profile.Browse_Base_Url__c) || String.isBlank(jiraIssueKey)) {
            return '';
        }
        String baseUrl = profile.Browse_Base_Url__c.endsWith('/')
            ? profile.Browse_Base_Url__c.substring(0, profile.Browse_Base_Url__c.length() - 1)
            : profile.Browse_Base_Url__c;
        return baseUrl + '/browse/' + jiraIssueKey;
    }

    public static Map<String, Object> sendRequest(
        Jira_Connector_Profile__c profile,
        String method,
        String path,
        Map<String, String> queryParams,
        Object body
    ) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setTimeout(60000);

        String endpoint = 'callout:' + profile.Named_Credential_Api_Name__c + path;
        if (queryParams != null && !queryParams.isEmpty()) {
            List<String> encodedPairs = new List<String>();
            for (String key : queryParams.keySet()) {
                if (queryParams.get(key) != null) {
                    encodedPairs.add(
                        EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(queryParams.get(key), 'UTF-8')
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
            throw new JiraGatewayException('Jira request failed with status ' + statusCode + ': ' + response.getBody());
        }
        if (String.isBlank(response.getBody())) {
            return new Map<String, Object>();
        }

        Object parsed = JSON.deserializeUntyped(response.getBody());
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }
        throw new JiraGatewayException('Jira returned an unexpected response shape.');
    }
}