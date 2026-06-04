# Direct Jira Actions Setup And Test

## What This Uses
- Apex callouts go through the named credential configured in `Jira_Demo_Setting__mdt`.
- Agentforce targets direct Apex actions instead of the Jira Flow actions.
- Jira reporter resolution uses Salesforce `User.Username` mapped to Jira `accountId`.

## Configuration Metadata
The direct Jira actions read `Jira_Demo_Setting__mdt` records.

Default config records included in source:
- `NamedCredentialApiName = Jira_Named_Credential`
- `ProjectId = YOUR_JIRA_PROJECT_ID`
- `IssueTypeId = YOUR_JIRA_ISSUE_TYPE_ID`
- `ProjectKey = YOUR_JIRA_PROJECT_KEY`
- `OpenIssueJqlClause = statusCategory != Done ORDER BY updated DESC`
- `BrowseBaseUrl = https://your-domain.atlassian.net`

If your Jira project key or browse URL differs, update the corresponding `Jira_Demo_Setting__mdt` records after deployment.
For the full clone-and-configure workflow, see `docs/jira-agentforce-connector-package.md`.

## Reporter Mapping Records
Add one `Jira_Demo_Setting__mdt` record per demo user for reporter-based Jira create and lookup.

Use these field values:
- `SettingType__c = UserMapping`
- `SettingKey__c = <Salesforce Username>`
- `SettingValue__c = <Jira accountId>`
- `AuxValue__c = <optional Jira display name>`

Example:
- `SettingType__c = UserMapping`
- `SettingKey__c = scott@example.demo`
- `SettingValue__c = YOUR_JIRA_ACCOUNT_ID`
- `AuxValue__c = Scott Hendrix`

If no mapping exists for the running Salesforce username, the direct Jira create and "my open issues" actions will fail with a clear configuration message instead of silently guessing the reporter.

## Agentforce Smoke Tests
Use these after the new Apex classes and agent bundle are deployed and the agent version is published.

### Create Jira Issue
Prompt:
`Create a Jira issue for my laptop won't boot after the latest update. Make it high priority.`

Expected result:
- Agent calls the direct Jira create action.
- Response mentions the created Jira key, for example `IT-123`.
- Jira issue is visible in the configured Jira project with the mapped reporter.

### Get My Open Jira Issues
Prompt:
`What open Jira issues do I have right now?`

Expected result:
- Agent calls the direct reporter-based Jira search action.
- Response summarizes the caller's open Jira issues using the mapped Salesforce username.
- If no matching mapping exists, the response explains that the Jira reporter mapping is missing.

### Get Jira Issue By Key
Prompt:
`Give me an update on Jira issue IT-123.`

Expected result:
- Agent calls the direct Jira read action.
- Response includes the Jira status and summary returned from Jira.

### Update Jira Issue
Prompt:
`Update Jira issue IT-123 and change the summary to Laptop still won't boot after safe mode recovery.`

Expected result:
- Agent calls the direct Jira update action.
- Response confirms the Jira issue was updated successfully.

### Add Jira Comment
Prompt sequence:
1. `Add a comment to Jira issue IT-123 saying I am still blocked after trying the suggested steps.`
2. Confirm the exact comment text when the agent asks.

Expected result:
- Agent stores the exact Jira key.
- Agent confirms the exact comment text.
- Agent calls the direct Jira update action with `commentText`.
- Jira comment appears on the Jira issue.

## Recommended Validation Commands
Run these after deployment:

```bash
sf apex run test --target-org <target-org> --tests JiraDirectActionsTest --wait 30 --result-format human
sf agent validate authoring-bundle --api-name ItEmployeeAssistantV3 --target-org <target-org> --json
```
