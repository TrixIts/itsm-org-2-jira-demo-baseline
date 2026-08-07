public with sharing class JiraFulfillerSearchIssuesAction {
  public class Request {
    @InvocableVariable(label='Project Keys')
    public List<String> projectKeys;

    @InvocableVariable(label='Status Category (open, done, all)')
    public String statusCategory;

    @InvocableVariable(label='Priority Names')
    public List<String> priorityNames;

    @InvocableVariable(label='Assignee Filter (me, accountId, or unassigned)')
    public String assigneeFilter;

    @InvocableVariable(label='Reporter Filter (accountId)')
    public String reporterFilter;

    @InvocableVariable(label='Text Query (summary contains)')
    public String textQuery;

    @InvocableVariable(label='Updated Within Days')
    public Integer updatedWithinDays;

    @InvocableVariable(label='Start At')
    public Integer startAt;

    @InvocableVariable(label='Max Results')
    public Integer maxResults;

    @InvocableVariable(label='Next Page Token')
    public String nextPageToken;
  }

  public class Response {
    @InvocableVariable(label='Is Success')
    public Boolean isSuccess;

    @InvocableVariable(label='Message')
    public String message;

    @InvocableVariable(label='Total Count')
    public Integer totalCount;

    @InvocableVariable(label='Returned Count')
    public Integer returnedCount;

    @InvocableVariable(label='Start At')
    public Integer startAt;

    @InvocableVariable(label='Next Start At')
    public Integer nextStartAt;

    @InvocableVariable(label='Has More')
    public Boolean hasMore;

    @InvocableVariable(label='Next Page Token')
    public String nextPageToken;

    @InvocableVariable(label='Issues Summary')
    public String issuesSummary;

    @InvocableVariable(label='First Jira Issue Key')
    public String firstJiraIssueKey;

    @InvocableVariable(label='Content Trust')
    public String contentTrust;

    @InvocableVariable(label='Error Type')
    public String errorType;

    @InvocableVariable(label='HTTP Status Code')
    public Integer statusCode;

    @InvocableVariable(label='Is Retryable')
    public Boolean isRetryable;
  }

  @InvocableMethod(
    label='Search Jira Issues (Fulfiller)'
    description='Runs a structured, scope-enforced Jira search across allowed projects with pagination and grouped summaries.'
    callout=true
  )
  public static List<Response> search(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request requestItem : requests) {
      Response responseItem = new Response();
      responseItem.contentTrust = JiraFulfillerSupport.CONTENT_TRUST;
      try {
        JiraFulfillerSupport.requirePermission(
          JiraFulfillerSupport.PERMISSION_SEARCH
        );
        JiraFulfillerSupport.SearchFilters filters = new JiraFulfillerSupport.SearchFilters();
        if (requestItem.projectKeys != null) {
          filters.projectKeys = requestItem.projectKeys;
        }
        filters.statusCategory = requestItem.statusCategory;
        if (requestItem.priorityNames != null) {
          filters.priorityNames = requestItem.priorityNames;
        }
        filters.assigneeFilter = requestItem.assigneeFilter;
        filters.reporterFilter = requestItem.reporterFilter;
        filters.textQuery = requestItem.textQuery;
        filters.updatedWithinDays = requestItem.updatedWithinDays;
        filters.startAt = requestItem.startAt == null ? 0 : requestItem.startAt;
        filters.maxResults = requestItem.maxResults;
        filters.nextPageToken = requestItem.nextPageToken;

        JiraFulfillerSupport.SearchResult result = JiraFulfillerSupport.search(
          filters
        );
        responseItem.isSuccess = true;
        responseItem.totalCount = result.totalCount;
        responseItem.returnedCount = result.returnedCount;
        responseItem.startAt = result.startAt;
        responseItem.nextStartAt = result.nextStartAt;
        responseItem.hasMore = result.hasMore;
        responseItem.nextPageToken = result.nextPageToken;
        responseItem.issuesSummary = result.issuesSummary;
        responseItem.firstJiraIssueKey = result.firstIssueKey;
        responseItem.message =
          'Found ' +
          result.totalCount +
          ' matching Jira issue(s); showing ' +
          result.returnedCount +
          '.' +
          (result.hasMore ? ' More results are available.' : '');
      } catch (Exception ex) {
        JiraDirectActionSupport.ErrorInfo errorInfo = JiraDirectActionSupport.toErrorInfo(
          ex
        );
        responseItem.isSuccess = false;
        responseItem.errorType = errorInfo.errorType;
        responseItem.statusCode = errorInfo.statusCode;
        responseItem.isRetryable = errorInfo.isRetryable;
        responseItem.totalCount = 0;
        responseItem.returnedCount = 0;
        responseItem.issuesSummary = '';
        responseItem.message = 'Jira search failed: ' + errorInfo.safeMessage;
      }
      responses.add(responseItem);
    }
    return responses;
  }
}
