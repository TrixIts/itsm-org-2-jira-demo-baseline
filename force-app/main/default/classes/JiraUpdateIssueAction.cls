public with sharing class JiraUpdateIssueAction {
    public class Request {
        @InvocableVariable(label='Jira Issue Id Or Key' required=true)
        public String jiraIssueIdOrKey;

        @InvocableVariable(label='Jira Summary')
        public String jiraSummary;

        @InvocableVariable(label='Jira Priority')
        public String jiraPriority;

        @InvocableVariable(label='Jira Impact Option Id')
        public String jiraImpactOptionId;

        @InvocableVariable(label='Jira Urgency Option Id')
        public String jiraUrgencyOptionId;

        @InvocableVariable(label='Jira Severity Option Id')
        public String jiraSeverityOptionId;

        @InvocableVariable(label='Comment Text')
        public String commentText;

        @InvocableVariable(label='Confirmed By Employee')
        public Boolean confirmedByEmployee;

        @InvocableVariable(label='Confirmed Jira Issue Key')
        public String confirmedJiraIssueKey;

        @InvocableVariable(label='Confirmed Comment Text')
        public String confirmedCommentText;
    }

    public class Response {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Jira Issue Key')
        public String jiraIssueKey;

        @InvocableVariable(label='Jira Issue Id')
        public String jiraIssueId;

        @InvocableVariable(label='Jira Summary')
        public String jiraSummary;

        @InvocableVariable(label='Jira Status')
        public String jiraStatus;

        @InvocableVariable(label='Jira Issue Url')
        public String jiraIssueUrl;

        @InvocableVariable(label='Did Update Fields')
        public Boolean didUpdateFields;

        @InvocableVariable(label='Did Add Comment')
        public Boolean didAddComment;

        @InvocableVariable(label='Correlation Id')
        public String correlationId;

        @InvocableVariable(label='Is Duplicate')
        public Boolean isDuplicate;

        @InvocableVariable(label='Error Type')
        public String errorType;

        @InvocableVariable(label='HTTP Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Is Retryable')
        public Boolean isRetryable;
    }

    @InvocableMethod(
        label='Update Jira Issue Direct'
        description='Updates Jira fields and optionally adds a Jira comment directly through Jira REST.'
    )
    public static List<Response> updateIssue(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            Long startedAt = Datetime.now().getTime();
            String triageCorrelationId;
            String commentCorrelationId;
            try {
                Boolean hasFieldUpdate =
                    !String.isBlank(requestItem.jiraSummary) ||
                    !String.isBlank(requestItem.jiraPriority) ||
                    !String.isBlank(requestItem.jiraImpactOptionId) ||
                    !String.isBlank(requestItem.jiraUrgencyOptionId) ||
                    !String.isBlank(requestItem.jiraSeverityOptionId);
                Boolean hasComment = !String.isBlank(requestItem.commentText);

                if (!hasFieldUpdate && !hasComment) {
                    throw JiraIntegrationSupport.newException(
                        'VALIDATION',
                        null,
                        false,
                        'Provide at least one Jira field update or a comment before calling the direct Jira update action.'
                    );
                }
                String validatedIssueKey = JiraDirectActionSupport.validateIssueKey(requestItem.jiraIssueIdOrKey);
                if (hasFieldUpdate) {
                    JiraDirectActionSupport.requirePermission(JiraDirectActionSupport.PERMISSION_TRIAGE);
                    JiraDirectActionSupport.validateSummary(requestItem.jiraSummary);
                    JiraDirectActionSupport.validatePriority(requestItem.jiraPriority);
                    triageCorrelationId = JiraDirectActionSupport.buildTriageCorrelationKey(
                        validatedIssueKey,
                        requestItem.jiraPriority,
                        requestItem.jiraImpactOptionId,
                        requestItem.jiraUrgencyOptionId,
                        requestItem.jiraSeverityOptionId
                    );
                }
                if (hasComment) {
                    JiraDirectActionSupport.requirePermission(JiraDirectActionSupport.PERMISSION_COMMENT);
                    JiraDirectActionSupport.validateComment(requestItem.commentText);
                    commentCorrelationId = JiraDirectActionSupport.buildCommentCorrelationKey(
                        validatedIssueKey,
                        requestItem.commentText
                    );
                }
                responseItem.correlationId = hasComment ? commentCorrelationId : triageCorrelationId;

                JiraIntegrationSupport.validateWriteConfirmation(
                    validatedIssueKey,
                    requestItem.confirmedByEmployee,
                    requestItem.confirmedJiraIssueKey,
                    requestItem.commentText,
                    requestItem.confirmedCommentText
                );

                Boolean triageDuplicate = hasFieldUpdate &&
                    JiraDirectActionSupport.findSuccessfulTransaction(triageCorrelationId) != null;
                Boolean commentDuplicate = hasComment &&
                    JiraDirectActionSupport.findSuccessfulTransaction(commentCorrelationId) != null;
                if (hasFieldUpdate && !triageDuplicate) {
                    JiraIntegrationSupport.updateIssue(
                        validatedIssueKey,
                        requestItem.jiraSummary,
                        requestItem.jiraPriority,
                        requestItem.jiraImpactOptionId,
                        requestItem.jiraUrgencyOptionId,
                        requestItem.jiraSeverityOptionId
                    );
                }
                if (hasComment && !commentDuplicate) {
                    JiraIntegrationSupport.addComment(validatedIssueKey, requestItem.commentText);
                }

                Map<String, Object> refreshedIssue = JiraIntegrationSupport.getIssueByKey(validatedIssueKey);
                Map<String, Object> fields = JiraIntegrationSupport.mapValue(refreshedIssue.get('fields'));

                responseItem.isSuccess = true;
                responseItem.jiraIssueKey = JiraIntegrationSupport.stringValue(refreshedIssue.get('key'));
                responseItem.jiraIssueId = JiraIntegrationSupport.stringValue(refreshedIssue.get('id'));
                responseItem.jiraSummary = JiraIntegrationSupport.stringValue(fields.get('summary'));
                responseItem.jiraStatus = JiraIntegrationSupport.stringValue(
                    JiraIntegrationSupport.mapValue(fields.get('status')).get('name')
                );
                responseItem.jiraIssueUrl = JiraIntegrationSupport.buildIssueUrl(responseItem.jiraIssueKey);
                responseItem.didUpdateFields = hasFieldUpdate && !triageDuplicate;
                responseItem.didAddComment = hasComment && !commentDuplicate;
                responseItem.isDuplicate = (hasFieldUpdate == triageDuplicate) && (hasComment == commentDuplicate);

                List<String> actionsTaken = new List<String>();
                if (responseItem.didUpdateFields) {
                    actionsTaken.add('updated');
                }
                if (responseItem.didAddComment) {
                    actionsTaken.add('commented');
                }

                responseItem.message = actionsTaken.isEmpty()
                    ? 'The confirmed Jira changes were already applied to issue ' + responseItem.jiraIssueKey + '.'
                    : 'Jira issue ' + responseItem.jiraIssueKey + ' ' +
                        String.join(actionsTaken, ' and ') + ' successfully.';
                if (hasFieldUpdate && !triageDuplicate) {
                    JiraDirectActionSupport.recordTransaction(
                        triageCorrelationId, 'Triage', responseItem.jiraIssueKey, 'Success', startedAt, null
                    );
                }
                if (hasComment && !commentDuplicate) {
                    JiraDirectActionSupport.recordTransaction(
                        commentCorrelationId, 'Comment', responseItem.jiraIssueKey, 'Success', startedAt, null
                    );
                }
            } catch (Exception ex) {
                JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(ex);
                responseItem.isSuccess = false;
                responseItem.errorType = errorInfo.errorType;
                responseItem.statusCode = errorInfo.statusCode;
                responseItem.isRetryable = errorInfo.isRetryable;
                responseItem.isDuplicate = false;
                responseItem.message = 'Jira issue update failed: ' + errorInfo.safeMessage;
                responseItem.jiraIssueKey = '';
                responseItem.jiraIssueId = '';
                responseItem.jiraSummary = '';
                responseItem.jiraStatus = '';
                responseItem.jiraIssueUrl = '';
                responseItem.didUpdateFields = false;
                responseItem.didAddComment = false;
                JiraDirectActionSupport.recordTransaction(
                    JiraDirectActionSupport.newAuditCorrelation('Update', requestItem.jiraIssueIdOrKey),
                    'Update',
                    requestItem.jiraIssueIdOrKey,
                    'Failure',
                    startedAt,
                    errorInfo
                );
            }
            responses.add(responseItem);
        }
        return responses;
    }
}