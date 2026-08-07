public with sharing class JiraDirectActionSupport {
  public static final String PERMISSION_READ = 'Jira_Direct_Read';
  public static final String PERMISSION_CREATE = 'Jira_Direct_Create';
  public static final String PERMISSION_COMMENT = 'Jira_Direct_Comment';
  public static final String PERMISSION_TRIAGE = 'Jira_Direct_Triage';

  private static final Integer MAX_SUMMARY_LENGTH = 255;
  private static final Integer MAX_DESCRIPTION_LENGTH = 10000;
  private static final Integer MAX_COMMENT_LENGTH = 5000;
  private static final Integer MAX_SOURCE_REFERENCE_LENGTH = 255;

  @TestVisible
  private static Set<String> permissionOverrides;

  @TestVisible
  private static Map<String, Jira_Integration_Transaction__c> transactionOverridesByCorrelation;

  public class ErrorInfo {
    public String errorType;
    public Integer statusCode;
    public Boolean isRetryable;
    public String safeMessage;
  }

  public static void requirePermission(String permissionName) {
    Boolean isAllowed = permissionOverrides == null
      ? FeatureManagement.checkPermission(permissionName)
      : permissionOverrides.contains(permissionName);
    if (!isAllowed) {
      throw JiraIntegrationSupport.newException(
        'AUTHORIZATION',
        null,
        false,
        'You do not have permission to perform this Jira action.'
      );
    }
  }

  public static void validateCreateInputs(
    String summary,
    String description,
    String priority,
    String requesterEmail,
    String channel,
    String sourceReference
  ) {
    validateText('Jira summary', summary, MAX_SUMMARY_LENGTH, true);
    validateText('Jira description', description, MAX_DESCRIPTION_LENGTH, true);
    validatePriority(priority);
    validateText('Requester email', requesterEmail, 254, false);
    validateText('Channel', channel, 80, false);
    validateText(
      'Source reference',
      sourceReference,
      MAX_SOURCE_REFERENCE_LENGTH,
      false
    );
    if (
      !String.isBlank(requesterEmail) &&
      !Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', requesterEmail.trim())
    ) {
      throw validationException(
        'Requester email must be a valid email address.'
      );
    }
  }

  public static String validateIssueKey(String issueKey) {
    validateText('Jira issue key', issueKey, 80, true);
    String normalizedKey = issueKey.trim().toUpperCase();
    String projectKey = JiraIntegrationSupport.getConfiguration().projectKey;
    if (String.isBlank(projectKey)) {
      throw JiraIntegrationSupport.newException(
        'CONFIGURATION',
        null,
        false,
        'ProjectKey must be configured before using issue-key actions.'
      );
    }
    String requiredPrefix = projectKey.trim().toUpperCase() + '-';
    if (!normalizedKey.startsWith(requiredPrefix)) {
      throw validationException(
        'Jira issue key must belong to the configured project.'
      );
    }
    String issueNumber = normalizedKey.substring(requiredPrefix.length());
    if (
      String.isBlank(issueNumber) ||
      !Pattern.matches('^[1-9][0-9]*$', issueNumber)
    ) {
      throw validationException(
        'Jira issue key must use the format ' +
          projectKey.trim().toUpperCase() +
          '-123.'
      );
    }
    return normalizedKey;
  }

  public static void validateComment(String commentText) {
    validateText('Jira comment', commentText, MAX_COMMENT_LENGTH, true);
  }

  public static void validateSummary(String summary) {
    validateText('Jira summary', summary, MAX_SUMMARY_LENGTH, false);
  }

  public static void validatePriority(String priority) {
    validateText('Jira priority', priority, 40, false);
    if (
      !String.isBlank(priority) &&
      !Pattern.matches('^[A-Za-z0-9 _-]+$', priority.trim())
    ) {
      throw validationException(
        'Jira priority contains unsupported characters.'
      );
    }
  }

  public static String buildCreateCorrelationKey(
    String sourceReference,
    String summary,
    String description,
    String requesterEmail
  ) {
    String stableInput = String.isBlank(sourceReference)
      ? String.valueOf(Date.today()) +
        '|' +
        UserInfo.getUserId() +
        '|' +
        summary +
        '|' +
        description +
        '|' +
        requesterEmail
      : sourceReference.trim();
    return 'CREATE:' + sha256(stableInput);
  }

  public static String buildCommentCorrelationKey(
    String issueKey,
    String commentText
  ) {
    return 'COMMENT:' +
      sha256(issueKey.trim().toUpperCase() + '|' + commentText.trim());
  }

  public static String buildTriageCorrelationKey(
    String issueKey,
    String priority,
    String impact,
    String urgency,
    String severity
  ) {
    return 'TRIAGE:' +
      sha256(
        issueKey.trim().toUpperCase() +
          '|' +
          stringOrBlank(priority) +
          '|' +
          stringOrBlank(impact) +
          '|' +
          stringOrBlank(urgency) +
          '|' +
          stringOrBlank(severity)
      );
  }

  public static String newAuditCorrelation(String operation, String issueKey) {
    return 'AUDIT:' +
      sha256(
        operation +
          '|' +
          stringOrBlank(issueKey) +
          '|' +
          UserInfo.getUserId() +
          '|' +
          String.valueOf(Datetime.now().getTime()) +
          '|' +
          EncodingUtil.convertToHex(Crypto.generateAesKey(128))
      );
  }

  public static Jira_Integration_Transaction__c findSuccessfulTransaction(
    String correlationKey
  ) {
    if (String.isBlank(correlationKey)) {
      return null;
    }
    if (transactionOverridesByCorrelation != null) {
      return transactionOverridesByCorrelation.get(correlationKey);
    }
    List<Jira_Integration_Transaction__c> matches = [
      SELECT Correlation_Key__c, Jira_Issue_Key__c, Operation__c, Outcome__c
      FROM Jira_Integration_Transaction__c
      WHERE
        Correlation_Key__c = :correlationKey
        AND Outcome__c IN ('Success', 'Duplicate')
      WITH USER_MODE
      LIMIT 1
    ];
    return matches.isEmpty() ? null : matches[0];
  }

  public static void recordTransaction(
    String correlationKey,
    String operation,
    String issueKey,
    String outcome,
    Long startedAt,
    ErrorInfo errorInfo
  ) {
    if (String.isBlank(correlationKey)) {
      return;
    }
    Map<String, Object> details = new Map<String, Object>{
      'executingUserId' => UserInfo.getUserId(),
      'latencyMs' => Math.max(0, Datetime.now().getTime() - startedAt),
      'statusCode' => errorInfo == null ? null : errorInfo.statusCode,
      'isRetryable' => errorInfo == null ? false : errorInfo.isRetryable,
      'errorType' => errorInfo == null ? '' : errorInfo.errorType
    };
    Jira_Integration_Transaction__c transactionRecord = new Jira_Integration_Transaction__c(
      Correlation_Key__c = correlationKey,
      Operation__c = shorten(operation, 40),
      Jira_Issue_Key__c = shorten(issueKey, 80),
      Outcome__c = shorten(outcome, 40),
      Details__c = JSON.serialize(details)
    );
    if (transactionOverridesByCorrelation != null) {
      if (!transactionOverridesByCorrelation.containsKey(correlationKey)) {
        transactionOverridesByCorrelation.put(
          correlationKey,
          transactionRecord
        );
      }
      return;
    }
    try {
      Database.insert(
        new List<Jira_Integration_Transaction__c>{ transactionRecord },
        false,
        AccessLevel.USER_MODE
      );
    } catch (Exception ignoredException) {
      // Audit persistence must not replace the safe Jira action result.
      String ignoredType = ignoredException.getTypeName();
      if (String.isBlank(ignoredType)) {
        return;
      }
    }
  }

  public static ErrorInfo toErrorInfo(Exception exceptionValue) {
    ErrorInfo info = new ErrorInfo();
    if (
      exceptionValue instanceof JiraIntegrationSupport.JiraIntegrationException
    ) {
      JiraIntegrationSupport.JiraIntegrationException jiraException = (JiraIntegrationSupport.JiraIntegrationException) exceptionValue;
      info.errorType = String.isBlank(jiraException.errorType)
        ? 'INTEGRATION'
        : jiraException.errorType;
      info.statusCode = jiraException.statusCode;
      info.isRetryable = jiraException.isRetryable == true;
      info.safeMessage = sanitizeExternalText(jiraException.getMessage(), 500);
    } else {
      info.errorType = 'UNEXPECTED';
      info.statusCode = null;
      info.isRetryable = false;
      info.safeMessage = 'The Jira action could not be completed because of an unexpected Salesforce error.';
    }
    return info;
  }

  public static String sanitizeExternalText(String value, Integer maxLength) {
    if (String.isBlank(value)) {
      return '';
    }
    String sanitized = value
      .replaceAll('[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]', '')
      .replaceAll('\\s+', ' ')
      .trim();
    return shorten(sanitized, maxLength);
  }

  private static void validateText(
    String label,
    String value,
    Integer maxLength,
    Boolean required
  ) {
    if (required == true && String.isBlank(value)) {
      throw validationException(label + ' is required.');
    }
    if (!String.isBlank(value) && value.length() > maxLength) {
      throw validationException(
        label + ' cannot exceed ' + maxLength + ' characters.'
      );
    }
    if (
      !String.isBlank(value) &&
      Pattern.compile('[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]')
        .matcher(value)
        .find()
    ) {
      throw validationException(
        label + ' contains unsupported control characters.'
      );
    }
  }

  private static JiraIntegrationSupport.JiraIntegrationException validationException(
    String message
  ) {
    return JiraIntegrationSupport.newException(
      'VALIDATION',
      null,
      false,
      message
    );
  }

  private static String sha256(String value) {
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(stringOrBlank(value)))
      )
      .toLowerCase();
  }

  private static String stringOrBlank(String value) {
    return value == null ? '' : value.trim();
  }

  private static String shorten(String value, Integer maxLength) {
    if (String.isBlank(value) || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}
