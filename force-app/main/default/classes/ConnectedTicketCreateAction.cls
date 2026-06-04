public with sharing class ConnectedTicketCreateAction {
    public class Request {
        @InvocableVariable(label='Connector Key')
        public String connectorKey;
        @InvocableVariable(label='Route Key')
        public String routeKey;
        @InvocableVariable(label='Source Record Id')
        public Id recordId;
        @InvocableVariable(label='Salesforce Object API Name')
        public String objectApiName;
        @InvocableVariable(label='Summary' required=true)
        public String summary;
        @InvocableVariable(label='Description')
        public String description;
        @InvocableVariable(label='Requester Email')
        public String requesterEmail;
        @InvocableVariable(label='Reporter Salesforce Username')
        public String reporterSalesforceUsername;
        @InvocableVariable(label='Priority')
        public String priority;
        @InvocableVariable(label='Impact')
        public String impact;
        @InvocableVariable(label='Urgency')
        public String urgency;
        @InvocableVariable(label='Severity')
        public String severity;
        @InvocableVariable(label='Channel')
        public String channel;
        @InvocableVariable(label='Source Reference')
        public String sourceReference;
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
        @InvocableVariable(label='Validation Messages')
        public String validationMessages;
    }

    @InvocableMethod(label='Create Connected Ticket' description='Creates a Jira ticket through the active admin-managed connector mapping.')
    public static List<Result> createTickets(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            results.add(toResult(ConnectedTicketService.createTicket(toServiceRequest(request))));
        }
        return results;
    }

    private static ConnectedTicketService.Request toServiceRequest(Request request) {
        ConnectedTicketService.Request serviceRequest = new ConnectedTicketService.Request();
        serviceRequest.connectorKey = request.connectorKey;
        serviceRequest.routeKey = request.routeKey;
        serviceRequest.recordId = request.recordId;
        serviceRequest.objectApiName = request.objectApiName;
        serviceRequest.summary = request.summary;
        serviceRequest.description = request.description;
        serviceRequest.requesterEmail = request.requesterEmail;
        serviceRequest.reporterSalesforceUsername = request.reporterSalesforceUsername;
        serviceRequest.priority = request.priority;
        serviceRequest.impact = request.impact;
        serviceRequest.urgency = request.urgency;
        serviceRequest.severity = request.severity;
        serviceRequest.channel = request.channel;
        serviceRequest.sourceReference = request.sourceReference;
        return serviceRequest;
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
        result.validationMessages = response.validationMessages == null ? null : String.join(response.validationMessages, '; ');
        return result;
    }
}
