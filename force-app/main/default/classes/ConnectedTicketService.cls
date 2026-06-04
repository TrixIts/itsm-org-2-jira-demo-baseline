public with sharing class ConnectedTicketService {
    public class ConnectedTicketException extends Exception {}

    public class Request {
        @AuraEnabled public String connectorKey { get; set; }
        @AuraEnabled public String routeKey { get; set; }
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String jiraIssueKey { get; set; }
        @AuraEnabled public String summary { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String requesterEmail { get; set; }
        @AuraEnabled public String requesterName { get; set; }
        @AuraEnabled public String reporterSalesforceUsername { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String impact { get; set; }
        @AuraEnabled public String urgency { get; set; }
        @AuraEnabled public String severity { get; set; }
        @AuraEnabled public String channel { get; set; }
        @AuraEnabled public String sourceReference { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String assignee { get; set; }
        @AuraEnabled public String comment { get; set; }
    }

    public class Response {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String connectorKey { get; set; }
        @AuraEnabled public String jiraIssueId { get; set; }
        @AuraEnabled public String jiraIssueKey { get; set; }
        @AuraEnabled public String jiraIssueUrl { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String employeeSummary { get; set; }
        @AuraEnabled public List<String> validationMessages { get; set; }
        @AuraEnabled public String rawJson { get; set; }
    }

    public static Response createTicket(Request request) {
        JiraMappingResolver.ResolvedPayload payload = JiraMappingResolver.resolveCreate(toResolverRequest(request));
        if (!payload.validationMessages.isEmpty()) {
            Response response = baseResponse(payload.profile);
            response.success = false;
            response.message = 'Connector mapping is missing required values.';
            response.validationMessages = payload.validationMessages;
            return response;
        }

        Map<String, Object> jiraResponse = JiraTicketGateway.createIssue(payload.profile, payload.fields);
        Response response = baseResponse(payload.profile);
        response.success = true;
        response.jiraIssueId = JiraIntegrationSupport.stringValue(jiraResponse.get('id'));
        response.jiraIssueKey = JiraIntegrationSupport.stringValue(jiraResponse.get('key'));
        response.jiraIssueUrl = JiraTicketGateway.buildIssueUrl(payload.profile, response.jiraIssueKey);
        response.message = 'Created Jira issue ' + response.jiraIssueKey + '.';
        response.employeeSummary = response.message + (String.isBlank(response.jiraIssueUrl) ? '' : ' Track it at ' + response.jiraIssueUrl + '.');
        response.rawJson = JSON.serialize(jiraResponse);
        return response;
    }

    public static Response lookupTicket(Request request) {
        if (request == null || String.isBlank(request.jiraIssueKey)) {
            throw new ConnectedTicketException('jiraIssueKey is required for lookup.');
        }
        JiraMappingResolver.ResolvedPayload payload = JiraMappingResolver.resolveLookup(toResolverRequest(request));
        Map<String, Object> issue = JiraTicketGateway.getIssueByKey(payload.profile, request.jiraIssueKey, payload.lookupFieldKeys);
        Response response = baseResponse(payload.profile);
        response.success = true;
        response.jiraIssueId = JiraIntegrationSupport.stringValue(issue.get('id'));
        response.jiraIssueKey = JiraIntegrationSupport.stringValue(issue.get('key'));
        response.jiraIssueUrl = JiraTicketGateway.buildIssueUrl(payload.profile, response.jiraIssueKey);
        response.employeeSummary = JiraIntegrationSupport.buildIssueResponseMessage(issue);
        response.message = 'Found Jira issue ' + response.jiraIssueKey + '.';
        response.rawJson = JSON.serialize(issue);
        return response;
    }

    public static Response updateTicket(Request request) {
        if (request == null || String.isBlank(request.jiraIssueKey)) {
            throw new ConnectedTicketException('jiraIssueKey is required for update.');
        }
        JiraMappingResolver.ResolvedPayload payload = JiraMappingResolver.resolveUpdate(toResolverRequest(request));
        JiraTicketGateway.updateIssue(payload.profile, request.jiraIssueKey, payload.fields);
        JiraTicketGateway.addComment(payload.profile, request.jiraIssueKey, request.comment);

        Response response = baseResponse(payload.profile);
        response.success = true;
        response.jiraIssueKey = request.jiraIssueKey;
        response.jiraIssueUrl = JiraTicketGateway.buildIssueUrl(payload.profile, response.jiraIssueKey);
        response.message = 'Updated Jira issue ' + response.jiraIssueKey + '.';
        response.employeeSummary = response.message;
        return response;
    }

    private static Response baseResponse(Jira_Connector_Profile__c profile) {
        Response response = new Response();
        response.connectorKey = profile.Connector_Key__c;
        response.validationMessages = new List<String>();
        return response;
    }

    private static JiraMappingResolver.TicketRequest toResolverRequest(Request request) {
        JiraMappingResolver.TicketRequest resolverRequest = new JiraMappingResolver.TicketRequest();
        if (request == null) {
            return resolverRequest;
        }
        resolverRequest.connectorKey = request.connectorKey;
        resolverRequest.routeKey = request.routeKey;
        resolverRequest.recordId = request.recordId;
        resolverRequest.objectApiName = request.objectApiName;
        resolverRequest.summary = request.summary;
        resolverRequest.description = request.description;
        resolverRequest.requesterEmail = request.requesterEmail;
        resolverRequest.requesterName = request.requesterName;
        resolverRequest.reporterSalesforceUsername = request.reporterSalesforceUsername;
        resolverRequest.priority = request.priority;
        resolverRequest.impact = request.impact;
        resolverRequest.urgency = request.urgency;
        resolverRequest.severity = request.severity;
        resolverRequest.channel = request.channel;
        resolverRequest.sourceReference = request.sourceReference;
        resolverRequest.status = request.status;
        resolverRequest.assignee = request.assignee;
        resolverRequest.comment = request.comment;
        return resolverRequest;
    }
}
