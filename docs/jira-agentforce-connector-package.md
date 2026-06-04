# Jira Agentforce Connector Package

This package contains the portable Jira pieces used by Agentforce:

- Direct Jira Apex actions for create, lookup, reporter-based open issue search, update, and comment.
- Admin-managed connected-ticket Apex actions backed by Jira connector profile and mapping records.
- Jira connector custom objects, custom metadata settings, admin LWC, tab, and permission sets.
- A reference Agent Script implementation in `ItEmployeeAssistantV3` that shows how the actions are wired into an employee assistant.

The source has been sanitized for clone-and-configure use. Real user mappings and the org-specific named credential `JiraV21Jira_SM` were replaced with placeholders.

## Important Files

- `manifest/jira-agentforce-connector-package.xml` deploys the portable connector runtime, mapping admin UI, and config metadata.
- `manifest/jira-agentforce-reference-agent-package.xml` deploys only the reference `ItEmployeeAssistantV3` authoring bundle.
- `force-app/main/default/classes/Jira*Action.cls` are the direct Agentforce invocable actions.
- `force-app/main/default/classes/ConnectedTicket*` and `JiraMappingResolver.cls` are the admin-managed connector action layer.
- `force-app/main/default/customMetadata/Jira_Demo_Setting.*.md-meta.xml` contains default direct-action configuration and an example reporter mapping.
- `force-app/main/default/lwc/jiraConnectorMapping` is the admin mapping workspace.

The older Flow and External Service files that reference `JiraV21Jira_SM` are intentionally excluded from the portable manifest. Those files were generated from one org's External Service connection and should be regenerated in the target org if you choose the Flow/External Service pattern instead of the Apex-first package.

## Prerequisites

- Salesforce CLI with a target org that supports Agentforce and API v66.0.
- A Jira Cloud site and an API token or OAuth setup approved for REST API access.
- A Salesforce Named Credential that points to the Jira Cloud base URL.
- At least one Jira project id, project key, issue type id, and Jira account id for reporter mapping.

Do not commit Jira API tokens, OAuth secrets, or real user-to-account mappings to source.

## Clone And Deploy

1. Clone the repo and authenticate to the target org.

```bash
sf org login web --alias <target-org>
sf config set target-org <target-org>
```

2. Create a Named Credential in the target org.

Recommended placeholder API name:

```text
Jira_Named_Credential
```

Set the URL to your Jira Cloud root, for example:

```text
https://your-domain.atlassian.net
```

Use your org's approved authentication model. For a quick sandbox setup, Jira Cloud basic auth usually uses the Jira user's email address plus an Atlassian API token. Configure that in Salesforce credential setup, not in source.

3. Update the Jira config custom metadata before deploying, or deploy the placeholders and update them in Setup afterward.

| SettingKey__c | Placeholder | Replace With |
| --- | --- | --- |
| `NamedCredentialApiName` | `Jira_Named_Credential` | Named Credential API name in the target org |
| `ProjectId` | `YOUR_JIRA_PROJECT_ID` | Jira project id, not the project key |
| `IssueTypeId` | `YOUR_JIRA_ISSUE_TYPE_ID` | Jira issue type id used for creates |
| `ProjectKey` | `YOUR_JIRA_PROJECT_KEY` | Jira project key, for example `IT` |
| `BrowseBaseUrl` | `https://your-domain.atlassian.net` | Jira Cloud browse base URL |
| `OpenIssueJqlClause` | `statusCategory != Done ORDER BY updated DESC` | Optional JQL tail for open issue searches |

4. Replace the example reporter mapping.

The direct create and "my open issues" actions map Salesforce usernames to Jira account IDs through `Jira_Demo_Setting__mdt` records:

- `SettingType__c = UserMapping`
- `SettingKey__c = <Salesforce username>`
- `SettingValue__c = <Jira accountId>`
- `AuxValue__c = <optional display name>`

The included `Jira_Demo_Setting.Example_User_Mapping` record is only a template. Replace `user@example.com` and `YOUR_JIRA_ACCOUNT_ID` with target-org values, or add one record per Agentforce user.

5. Deploy the connector package.

```bash
sf project deploy start --manifest manifest/jira-agentforce-connector-package.xml --target-org <target-org> --json
```

6. Assign permission sets.

Assign `Jira_Agentforce_Runtime` to the Agentforce running user or the employee users who will invoke the actions. Assign `Jira_Connector_Mapping_Admin` only to admins who should manage field mappings.

```bash
sf org assign permset --name Jira_Agentforce_Runtime --target-org <target-org> --on-behalf-of <agent-or-employee-username> --json
sf org assign permset --name Jira_Connector_Mapping_Admin --target-org <target-org> --on-behalf-of <admin-username> --json
```

7. Run tests.

```bash
sf apex run test --tests JiraDirectActionsTest,ConnectedTicketActionsTest,JiraConnectorMappingControllerTest --target-org <target-org> --wait 30 --result-format human
```

## Configure The Mapping UI

The direct actions only need `Jira_Demo_Setting__mdt`. The admin-managed connected-ticket actions additionally use connector profiles, discovered Jira fields, and mapping policy records.

After deploying:

1. Open the `Jira Connector Mapping` tab.
2. Create or update a connector profile with:
   - Connector key, for example `DefaultJira`
   - Named Credential API name
   - Jira project id and key
   - Issue type id and name
   - Browse base URL
3. Sync Jira fields.
4. Map canonical Agentforce fields such as summary, description, impact, urgency, severity, source reference, and channel to Jira fields.
5. Mark the profile active for Agentforce.

Use the admin-managed actions when you want runtime-editable field mappings. Use the direct actions when the Jira payload shape is stable and source-controlled.

## Agent Script Wiring

The full reference agent is `force-app/main/default/aiAuthoringBundles/ItEmployeeAssistantV3/ItEmployeeAssistantV3.agent`. It is not part of the core deploy manifest because it also references managed IT Service and knowledge actions that may not exist in another org.

For a portable agent, copy only the Jira action definitions and topic instructions you need. The essential Apex targets are:

- `apex://JiraCreateIssueAction`
- `apex://JiraGetIssueByKeyAction`
- `apex://JiraGetMyOpenIssuesAction`
- `apex://JiraUpdateIssueAction`

Minimal create-action pattern:

```agentscript
actions:
  create_jira_issue:
    description: "Create a Jira issue directly through Jira REST."
    inputs:
      jiraSummary: string
        is_required: True
      jiraDescription: string
        is_required: True
      jiraPriority: string
      jiraUrgencyOptionId: string
      jiraImpactOptionId: string
      jiraSeverityOptionId: string
      requesterEmail: string
      channel: string
      sourceReference: string
      reporterSalesforceUsername: string
    outputs:
      isSuccess: boolean
        is_used_by_planner: True
      message: string
        is_used_by_planner: True
      jiraIssueKey: string
        is_used_by_planner: True
      jiraIssueId: string
        is_used_by_planner: True
      jiraIssueUrl: string
        is_used_by_planner: True
    target: "apex://JiraCreateIssueAction"
```

Minimal follow-up targets:

```agentscript
actions:
  get_jira_issue_by_key:
    target: "apex://JiraGetIssueByKeyAction"
  get_my_open_jira_issues:
    target: "apex://JiraGetMyOpenIssuesAction"
  update_jira_issue:
    target: "apex://JiraUpdateIssueAction"
```

When adapting the reference agent, remove or replace org-specific managed targets such as `svc_emp_intelligence__*`, `EmployeeCopilot__*`, and any hardcoded RAG feature config IDs unless the target org has those same dependencies.

## Optional Reference Agent Deploy

Deploy the full reference agent only after confirming all its non-Jira dependencies exist in the target org:

```bash
sf agent validate authoring-bundle --api-name ItEmployeeAssistantV3 --target-org <target-org> --json
sf project deploy start --manifest manifest/jira-agentforce-reference-agent-package.xml --target-org <target-org> --json
```

Do not publish or activate the agent until validation and live-action preview pass and the org owner approves deployment.

## Smoke Tests

After config and permissions are set, preview the agent or invoke the actions from Flow/Agentforce with these scenarios:

- Create: "Create a Jira issue for my laptop not booting after the latest update."
- Lookup: "Give me an update on Jira issue `<PROJECTKEY>-123`."
- My open issues: "What open Jira issues do I have?"
- Comment: "Add a comment to Jira issue `<PROJECTKEY>-123` saying I am still blocked."

Expected behavior:

- Creates return a Jira key and optional browse URL.
- Lookups summarize Jira status, priority, resolution, recent comments, and recent history.
- Reporter-based searches fail clearly when the Salesforce username has no Jira account mapping.
- Updates require at least one field change or comment before calling Jira.
