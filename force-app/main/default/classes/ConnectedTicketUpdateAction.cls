public with sharing class ConnectedTicketUpdateAction {
    public class Request {
        @InvocableVariable(label='Connector Key')
        public String connectorKey;
        @InvocableVariable(label='Route Key')
        public String routeKey;
        @InvocableVariable(label='Jira Issue Key' required=true)
        public String jiraIssueKey;
        @InvocableVariable(label='Salesforce Object API Name')
        public String objectApiName;
        @InvocableVariable(label='Source Record Id')
        public Id recordId;
        @InvocableVariable(label='Comment')
        public String comment;
        @InvocableVariable(label='Priority')
        public String priority;
        @InvocableVariable(label='Impact')
        public String impact;
        @InvocableVariable(label='Urgency')
        public String urgency;
        @InvocableVariable(label='Severity')
        public String severity;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Assignee')
        public String assignee;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Connector Key')
        public String connectorKey;
        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;
        @InvocableVariable(label='Jira Issue URL')
        public String jiraIssueUrl;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Employee Summary')
        public String employeeSummary;
    }

    @InvocableMethod(label='Update Connected Ticket' description='Updates fields or comments on a Jira ticket through the active connector mapping.')
    public static List<Result> updateTickets(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            ConnectedTicketService.Request serviceRequest = new ConnectedTicketService.Request();
            serviceRequest.connectorKey = request.connectorKey;
            serviceRequest.routeKey = request.routeKey;
            serviceRequest.jiraIssueKey = request.jiraIssueKey;
            serviceRequest.objectApiName = request.objectApiName;
            serviceRequest.recordId = request.recordId;
            serviceRequest.comment = request.comment;
            serviceRequest.priority = request.priority;
            serviceRequest.impact = request.impact;
            serviceRequest.urgency = request.urgency;
            serviceRequest.severity = request.severity;
            serviceRequest.status = request.status;
            serviceRequest.assignee = request.assignee;
            results.add(toResult(ConnectedTicketService.updateTicket(serviceRequest)));
        }
        return results;
    }

    private static Result toResult(ConnectedTicketService.Response response) {
        Result result = new Result();
        result.success = response.success;
        result.connectorKey = response.connectorKey;
        result.jiraIssueKey = response.jiraIssueKey;
        result.jiraIssueUrl = response.jiraIssueUrl;
        result.message = response.message;
        result.employeeSummary = response.employeeSummary;
        return result;
    }
}
