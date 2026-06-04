public with sharing class ConnectedTicketLookupAction {
    public class Request {
        @InvocableVariable(label='Connector Key')
        public String connectorKey;
        @InvocableVariable(label='Route Key')
        public String routeKey;
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;
        @InvocableVariable(label='Salesforce Object API Name')
        public String objectApiName;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Connector Key')
        public String connectorKey;
        @InvocableVariable(label='Jira Issue Id')
        public String jiraIssueId;
        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;
        @InvocableVariable(label='Jira Issue URL')
        public String jiraIssueUrl;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Employee Summary')
        public String employeeSummary;
        @InvocableVariable(label='Raw JSON')
        public String rawJson;
    }

    @InvocableMethod(label='Lookup Connected Ticket' description='Looks up a Jira ticket through the admin-managed connector mapping.')
    public static List<Result> lookupTickets(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            ConnectedTicketService.Request serviceRequest = new ConnectedTicketService.Request();
            serviceRequest.connectorKey = request.connectorKey;
            serviceRequest.routeKey = request.routeKey;
            serviceRequest.jiraIssueKey = request.jiraIssueKey;
            serviceRequest.objectApiName = request.objectApiName;
            results.add(toResult(ConnectedTicketService.lookupTicket(serviceRequest)));
        }
        return results;
    }

    private static Result toResult(ConnectedTicketService.Response response) {
        Result result = new Result();
        result.success = response.success;
        result.connectorKey = response.connectorKey;
        result.jiraIssueId = response.jiraIssueId;
        result.jiraIssueKey = response.jiraIssueKey;
        result.jiraIssueUrl = response.jiraIssueUrl;
        result.message = response.message;
        result.employeeSummary = response.employeeSummary;
        result.rawJson = response.rawJson;
        return result;
    }
}
