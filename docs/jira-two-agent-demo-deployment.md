# Jira Agentforce Two-Agent Demo

This package delivers a Jira-backed Agentforce frontend with two employee-type
agents:

- `Jira_Employee_Assistant` — create, read, list, comment, and allowlisted
  employee updates.
- `IT_Fulfiller_Jira` — multi-project queue analysis, investigation, create,
  allowlisted field updates, comments, assignment, and transitions.

The package intentionally excludes OAuth tokens, connection metadata, generated
published versions, Salesforce Incident, ServiceNow, Slack, Okta, collaboration,
managed prompt, and RAG dependencies.

## Prerequisites

- Salesforce API 66.0 or later with Agentforce employee agents enabled.
- An active Salesforce Jira OAuth connection available to agents.
- Jira permissions appropriate for the operations enabled in each permission
  set.
- Jira project id, project key, issue type id, and Jira browse URL.
- Jira account ids for any reporter mappings.

The managed Jira connection URL must have this shape:

```text
https://api.atlassian.com/ex/jira/<cloud-id>
```

The Apex runtime appends `/rest/api/3/...`; do not append `/rest/api/3` to the
connection URL.

## Package

Use:

```text
manifest/jira-agentforce-two-agent-demo-package.xml
```

It contains only the two authoring bundles and their Jira runtime dependencies.

## Validate before deployment

From the Salesforce project root:

```bash
sf agent validate authoring-bundle --json --api-name Jira_Employee_Assistant
sf agent validate authoring-bundle --json --api-name IT_Fulfiller_Jira

sf project deploy start --json \
  --manifest manifest/jira-agentforce-two-agent-demo-package.xml \
  --target-org TARGET_ORG \
  --dry-run \
  --test-level RunSpecifiedTests \
  --tests JiraDirectActionsTest \
  --tests JiraFulfillerActionsTest \
  --wait 30
```

Resolve every missing dependency or test failure before a real deployment.

## Deploy metadata

Run only after approving deployment to the target org:

```bash
sf project deploy start --json \
  --manifest manifest/jira-agentforce-two-agent-demo-package.xml \
  --target-org TARGET_ORG \
  --test-level RunSpecifiedTests \
  --tests JiraDirectActionsTest \
  --tests JiraFulfillerActionsTest \
  --wait 30
```

This deploys editable `AiAuthoringBundle` source. It does not publish or activate
either agent.

## Configure one Jira project

In **Setup → Custom Metadata Types → Jira Demo Setting**, replace every
placeholder before testing:

- `NamedCredentialApiName` — the Jira connection **Developer Name**, for example
  `JiraV21Jira_SM`.
- `ProjectId` — Jira numeric project id.
- `ProjectKey` — Jira key such as `IT`.
- `IssueTypeId` — Jira issue type id used for create.
- `BrowseBaseUrl` — browser URL such as `https://example.atlassian.net`.
- `OpenIssueJqlClause` — optional additional open-issue clause.
- Jira field keys and allowed option-id lists used by the demo.
- Shared reporter and Salesforce-user-to-Jira-account mappings if the Jira
  connection requires them.

Never commit real OAuth tokens, client secrets, or passwords.

## Configure multiple Jira projects

For each project, create one `Jira_Connector_Profile__c` record:

- `Connector_Key__c`
- `Route_Key__c`
- `Named_Credential_Api_Name__c`
- `Project_Id__c`
- `Project_Key__c`
- `Issue_Type_Id__c`
- `Browse_Base_Url__c`
- `Active__c = true`
- `Is_Active_For_Agentforce__c = true`

For each field the fulfiller may update or summarize, create a
`Jira_Field_Mapping__c` record with the same connector key. Set
`Enabled__c = true`, and set `Allow_Agent_Update__c = true` only for fields the
agent is allowed to change. See
[`it-fulfiller-jira-setup.md`](it-fulfiller-jira-setup.md) for transforms and the
two-phase confirmation model.

Sanitized CSV starting points are available at:

- `data/jira-agentforce-demo/jira-connector-profile.template.csv`
- `data/jira-agentforce-demo/jira-field-mapping.template.csv`

Replace every `YOUR_*` value and verify the connection developer name before
loading these records with Data Loader or your normal Salesforce data process.

## Permissions

Assign:

- `Jira_Agentforce_Runtime` to users running `Jira_Employee_Assistant`.
- `Jira_Fulfiller_Runtime` to users running the write-capable fulfiller.
- `Jira_Fulfiller_Read_Only` instead when the fulfiller must not mutate Jira.

Also grant those users access to the external credential principal created by
the managed Jira OAuth connection.

## Publish and activate

Publishing creates permanent agent versions. Run these commands only after
metadata deployment, Jira configuration, permission assignment, and explicit
approval:

```bash
sf agent publish authoring-bundle --json \
  --api-name Jira_Employee_Assistant \
  --target-org TARGET_ORG
sf agent publish authoring-bundle --json \
  --api-name IT_Fulfiller_Jira \
  --target-org TARGET_ORG

sf agent activate --json \
  --api-name Jira_Employee_Assistant \
  --target-org TARGET_ORG
sf agent activate --json \
  --api-name IT_Fulfiller_Jira \
  --target-org TARGET_ORG
```

## Smoke tests

Use controlled Jira records and live actions:

```bash
sf agent preview start --json \
  --authoring-bundle Jira_Employee_Assistant \
  --use-live-actions \
  --target-org TARGET_ORG

sf agent preview start --json \
  --authoring-bundle IT_Fulfiller_Jira \
  --use-live-actions \
  --target-org TARGET_ORG
```

Test at minimum:

1. Employee create, exact-key lookup, reporter search, blocked unconfirmed write,
   confirmed comment, and confirmed allowlisted field update.
2. Fulfiller queue search, detail, create, two-phase field update, comment,
   assignee search/assignment, and transition.
3. Out-of-scope Jira project keys, non-allowlisted fields, changed confirmation
   values, expired confirmation tokens, and retryable Jira errors.
