# Setup

## Prerequisites

- Salesforce CLI with Agentforce commands
- Salesforce API version 67.0 or later
- Agentforce enabled in the target org
- Jira Cloud or Jira Service Management access
- A Salesforce Named Credential that can call the target Jira site

Use a dedicated integration principal with only the Jira permissions needed by the selected project. Store authentication only in Salesforce credentials.

## 1. Confirm the Target Org

```bash
sf config get target-org --json
```

If no target org is set:

```bash
sf org login web --alias <target-org>
sf config set target-org <target-org>
```

## 2. Deploy Connector Metadata

```bash
sf project deploy start --json \
  --manifest manifest/jira-agentforce-connector-package.xml \
  --target-org <target-org>
```

This deploys only the Apex actions, custom objects, custom permissions, permission sets, admin workspace, and tab. It does not deploy or activate an agent.

## 3. Configure Jira Authentication

Create a Named Credential and External Credential in Salesforce Setup. The Named Credential URL must reach the target Jira site, and its principal must be allowed to:

- read projects and issue types;
- read issue metadata and public comments;
- create issues;
- perform the fulfiller operations you intend to enable.

Grant the External Credential principal to the runtime users through a target-org-owned permission set. The credential API name and principal are org-local values, so this repository cannot safely prebuild that permission assignment.

Do not add credential metadata containing secrets to this repository.

## 4. Assign Setup Access

```bash
sf org assign permset --json \
  --name Jira_Connector_Mapping_Admin \
  --on-behalf-of <admin-username> \
  --target-org <target-org>
```

## 5. Create the Connector Profile

Open **Jira Connector Mapping** in Salesforce.

1. Enter the Named Credential API name.
2. Select **Load Jira Projects**.
3. Select the Jira project and issue type.
4. Confirm the browse base URL.
5. Select **Active profile** and **Active for Agentforce**.
6. Select **Employee default** on exactly one active profile.
7. Optionally enter a shared Jira customer reporter account ID and display name.
8. Save the profile.
9. Select **Sync Jira Fields**.
10. Enable only the mappings Agentforce may create, summarize, or update.

If the shared reporter account ID is blank, employee actions use the Named Credential principal returned by Jira.

## 6. Assign Runtime Access

Employee agent:

```bash
sf org assign permset --json \
  --name Jira_Agentforce_Runtime \
  --on-behalf-of <employee-agent-username> \
  --target-org <target-org>
```

Fulfiller agent:

```bash
sf org assign permset --json \
  --name Jira_Fulfiller_Runtime \
  --on-behalf-of <fulfiller-username> \
  --target-org <target-org>
```

Read-only variants are also included.

## 7. Validate the Connector

```bash
sf apex run test --json \
  --tests JiraDirectActionsTest,JiraFulfillerActionsTest,JiraConnectorMappingControllerTest \
  --target-org <target-org> \
  --wait 30
```

Run a connection health check and read-only smoke test before enabling writes.

## 8. Validate and Deploy Agent Source

```bash
sf agent validate authoring-bundle --json --api-name ItEmployeeAssistantV3
sf agent validate authoring-bundle --json --api-name IT_Fulfiller_Jira

sf project deploy start --json \
  --manifest manifest/jira-agentforce-agents-package.xml \
  --target-org <target-org>
```

## 9. Preview

```bash
sf agent preview start --json \
  --use-live-actions \
  --authoring-bundle ItEmployeeAssistantV3 \
  --target-org <target-org>
```

Repeat for `IT_Fulfiller_Jira`. Test every read path and each write confirmation gate. Do not confirm test writes unless the selected Jira project is safe for test data.

## 10. Publish and Activate

Publishing creates permanent runtime versions. Run these only after the target org owner approves:

```bash
sf agent publish authoring-bundle --json --api-name ItEmployeeAssistantV3 --target-org <target-org>
sf agent activate --json --api-name ItEmployeeAssistantV3 --target-org <target-org>

sf agent publish authoring-bundle --json --api-name IT_Fulfiller_Jira --target-org <target-org>
sf agent activate --json --api-name IT_Fulfiller_Jira --target-org <target-org>
```

After publishing, grant users access to each published agent in Salesforce Setup or through target-org-owned permission sets with the corresponding Agent Access entries. Agent access cannot be deployed before the target org has created the published Bot records.
