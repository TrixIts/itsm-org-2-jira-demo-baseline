@IsTest
private class VoiceAgentIncidentCreationInvocable_Test {
    @IsTest
    static void createsIncidentWithDefaults() {
        VoiceAgentIncidentCreationInvocable.Request request =
            new VoiceAgentIncidentCreationInvocable.Request();
        request.chatContext = 'Caller cannot reset their Okta password.';

        Test.startTest();
        List<VoiceAgentIncidentCreationInvocable.Response> responses =
            VoiceAgentIncidentCreationInvocable.createIncident(
                new List<VoiceAgentIncidentCreationInvocable.Request>{ request }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(true, responses[0].IsSuccess, responses[0].StatusMessage);
        System.assertNotEquals(null, responses[0].IncidentNumber, 'Incident number should be returned.');

        Incident createdIncident = [
            SELECT Subject, Description, Status, Impact, Urgency
            FROM Incident
            WHERE Id = :responses[0].IncidentId
            LIMIT 1
        ];

        System.assertEquals('Caller cannot reset their Okta password.', createdIncident.Subject);
        System.assertEquals('Caller cannot reset their Okta password.', createdIncident.Description);
        System.assertEquals('New', createdIncident.Status);
        System.assertEquals('Low', createdIncident.Impact);
        System.assertEquals('Low', createdIncident.Urgency);
    }

    @IsTest
    static void handlesBlankContext() {
        VoiceAgentIncidentCreationInvocable.Request request =
            new VoiceAgentIncidentCreationInvocable.Request();

        List<VoiceAgentIncidentCreationInvocable.Response> responses =
            VoiceAgentIncidentCreationInvocable.createIncident(
                new List<VoiceAgentIncidentCreationInvocable.Request>{ request }
            );

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(true, responses[0].IsSuccess, responses[0].StatusMessage);
    }
}
