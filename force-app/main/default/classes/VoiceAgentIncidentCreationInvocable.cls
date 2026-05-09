public without sharing class VoiceAgentIncidentCreationInvocable {
    public class Request {
        @InvocableVariable(label='Chat Context' description='Summary of the caller issue to use for incident creation.' required=true)
        public String chatContext;
    }

    public class Response {
        @InvocableVariable(label='Incident Number')
        public String IncidentNumber;

        @InvocableVariable(label='Incident Id')
        public String IncidentId;

        @InvocableVariable(label='Success')
        public Boolean IsSuccess;

        @InvocableVariable(label='Status Message')
        public String StatusMessage;
    }

    @InvocableMethod(label='Create Voice Agent Incident' description='Creates an ITSM Incident for a voice agent caller.')
    public static List<Response> createIncident(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request request : requests) {
            Response response = new Response();

            try {
                String context = String.isBlank(request?.chatContext)
                    ? 'Voice agent caller requested IT support.'
                    : request.chatContext.trim();

                Incident incidentRecord = new Incident(
                    Subject = buildSubject(context),
                    Description = context,
                    Status = 'New',
                    Impact = 'Low',
                    Urgency = 'Low'
                );

                insert incidentRecord;

                Incident createdIncident = [
                    SELECT IncidentNumber
                    FROM Incident
                    WHERE Id = :incidentRecord.Id
                    LIMIT 1
                ];

                response.IncidentId = incidentRecord.Id;
                response.IncidentNumber = createdIncident.IncidentNumber;
                response.IsSuccess = true;
                response.StatusMessage = 'Incident created: ' + createdIncident.IncidentNumber;
            } catch (Exception ex) {
                response.IsSuccess = false;
                response.StatusMessage = 'Incident creation failed: ' + ex.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    private static String buildSubject(String context) {
        String subject = context;
        if (subject.length() > 120) {
            subject = subject.substring(0, 117) + '...';
        }
        return subject;
    }
}
