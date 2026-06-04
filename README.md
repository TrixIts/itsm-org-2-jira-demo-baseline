# ITSM Org 2 Jira Agentforce Demo Baseline

This Salesforce DX repo packages a Jira-backed Agentforce demo baseline. It is intended to help another Salesforce org clone the project, deploy the portable Jira connector pieces, configure its own Jira credentials/project metadata, and reuse the included Agent Script examples for Jira ticket creation and follow-up.

The repo is Jira-focused, but it also contains a reference employee assistant agent that was developed in a broader ITSM demo org. Treat the core Jira manifest as the portable package and the full agent as implementation guidance unless the target org has the same managed ITSM/service catalog dependencies.

## What's In This Repo

### Portable Jira Connector Package

Use `manifest/jira-agentforce-connector-package.xml` for the reusable Jira package. It includes:

- Direct Agentforce Apex actions for Jira create, issue lookup, reporter-based open issue search, update, and comment.
- Admin-managed connected-ticket Apex actions that use runtime Jira profile and field mapping records.
- Jira connector custom objects for profiles, discovered Jira fields, and canonical-to-Jira field mappings.
- `Jira_Demo_Setting__mdt` custom metadata for direct-action configuration and reporter mappings.
- The `jiraConnectorMapping` LWC admin workspace and `Jira Connector Mapping` tab.
- Runtime/admin permission sets for Agentforce users and connector administrators.

Detailed setup is in `docs/jira-agentforce-connector-package.md`.

### Reference Agent

The reference Agent Script bundle is:

```text
force-app/main/default/aiAuthoringBundles/ItEmployeeAssistantV3/
```

It demonstrates how an employee-facing IT assistant can route employees across IT topics and invoke Jira-backed actions. The optional manifest is:

```text
manifest/jira-agentforce-reference-agent-package.xml
```

Do not assume this full agent deploys cleanly to a different org without dependency review. It references non-Jira managed actions for service catalog, knowledge, Salesforce ticket follow-up, collaboration onboarding, and Okta/GitHub workflows.

### Legacy/Alternative Jira Flow Material

Some generated Flow and External Service metadata remains in the repo from the original org's Jira connector experiments. Those files reference the old `JiraV21Jira_SM` External Service/Named Credential and are intentionally excluded from the portable Jira manifest.

If the target org wants a Flow/External Service approach, regenerate those connector assets in that org instead of reusing the old generated metadata directly.

## Agent Capabilities

The packaged Jira actions support these Agentforce capabilities:

- Create Jira issues from an employee's current IT problem, with summary, description, priority, impact, urgency, severity, requester context, and source/channel details.
- Return the created Jira key, Jira id, and browse URL when configured.
- Look up a Jira issue by exact key and summarize status, priority, resolution, assignee/reporter, recent comments, and recent field-history changes.
- Find the current employee's open Jira issues by mapping their Salesforce username to a Jira `accountId`.
- Update Jira issue fields such as summary and configured option fields.
- Add employee-approved comments to existing Jira issues.
- Fail clearly when required setup is missing, especially Named Credential configuration or reporter mappings.

The reference `ItEmployeeAssistantV3` agent adds broader demo behavior:

- Routes employee requests across IT domains such as hardware, software, cloud infrastructure, facilities, security, networking, policy, ticket follow-up, and escalation.
- Treats Jira as the operational ticketing source of truth for new operational IT issues.
- Optionally creates a Salesforce Incident shadow record after Jira creation when the target org has the managed ITSM action dependencies.
- Handles existing Jira issue follow-up and requires explicit confirmation before comments or ticket changes.

## Key Files And Directories

| Path | Purpose |
| --- | --- |
| `manifest/jira-agentforce-connector-package.xml` | Core portable Jira connector deployment manifest. |
| `manifest/jira-agentforce-reference-agent-package.xml` | Optional reference agent manifest. |
| `docs/jira-agentforce-connector-package.md` | End-to-end setup, configuration, deploy, permission, and smoke-test guide. |
| `docs/direct-jira-actions-setup-and-test.md` | Direct Apex action configuration and test notes. |
| `docs/jira-agentforce-flow-blueprint.md` | Historical/architectural notes for the Flow and External Service approach. |
| `force-app/main/default/classes/Jira*Action.cls` | Direct invocable Apex actions exposed to Agentforce. |
| `force-app/main/default/classes/JiraIntegrationSupport.cls` | Shared direct-action Jira REST helpers and response formatting. |
| `force-app/main/default/classes/ConnectedTicket*.cls` | Admin-managed connected-ticket invocable action layer. |
| `force-app/main/default/classes/JiraTicketGateway.cls` | Jira REST gateway for admin-managed connector profiles. |
| `force-app/main/default/classes/JiraMappingResolver.cls` | Resolves canonical Agentforce ticket fields into Jira payload fields. |
| `force-app/main/default/lwc/jiraConnectorMapping/` | Admin UI for Jira profile/field mapping configuration. |
| `force-app/main/default/objects/Jira_*` | Jira connector profile, field catalog, and mapping objects. |
| `force-app/main/default/customMetadata/Jira_Demo_Setting.*` | Placeholder direct-action settings and example reporter mapping. |
| `force-app/main/default/permissionsets/Jira_Agentforce_Runtime.permissionset-meta.xml` | Runtime Apex access for Agentforce users. |
| `force-app/main/default/permissionsets/Jira_Connector_Mapping_Admin.permissionset-meta.xml` | Admin access to mapping UI and mapping objects. |

## Configuration Model

The direct Apex actions read `Jira_Demo_Setting__mdt` records:

- `NamedCredentialApiName`
- `ProjectId`
- `IssueTypeId`
- `ProjectKey`
- `BrowseBaseUrl`
- `OpenIssueJqlClause`
- one `UserMapping` record per Salesforce username that should map to a Jira reporter account id

The admin-managed connector actions read:

- `Jira_Connector_Profile__c`
- `Jira_Connector_Field__c`
- `Jira_Field_Mapping__c`

Use direct actions when the Jira field shape is stable and you want source-controlled config. Use the admin-managed action layer when admins need to sync Jira fields and adjust mappings at runtime.

## Quick Start

1. Authenticate the target Salesforce org.

```bash
sf org login web --alias <target-org>
sf config set target-org <target-org>
```

2. Create a Salesforce Named Credential for Jira in the target org. The placeholder name used by this repo is `Jira_Named_Credential`.

3. Update the placeholder `Jira_Demo_Setting__mdt` records with the target Jira project id, issue type id, project key, browse URL, and reporter mappings.

4. Deploy the portable connector package.

```bash
sf project deploy start --manifest manifest/jira-agentforce-connector-package.xml --target-org <target-org> --json
```

5. Assign permission sets.

```bash
sf org assign permset --name Jira_Agentforce_Runtime --target-org <target-org> --on-behalf-of <agent-or-employee-username> --json
sf org assign permset --name Jira_Connector_Mapping_Admin --target-org <target-org> --on-behalf-of <admin-username> --json
```

6. Run tests.

```bash
sf apex run test --tests JiraDirectActionsTest,ConnectedTicketActionsTest,JiraConnectorMappingControllerTest --target-org <target-org> --wait 30 --result-format human
```

7. Validate the optional reference agent only after dependency review.

```bash
sf agent validate authoring-bundle --api-name ItEmployeeAssistantV3 --target-org <target-org> --json
```

Do not publish, activate, or deploy to an org until the target org owner confirms they want that step.

## Security And Portability Notes

- No Jira API tokens or OAuth secrets should be committed to source. Configure secrets only through Salesforce credential setup.
- Real Salesforce usernames and Jira account IDs were replaced with placeholder custom metadata.
- The default custom metadata values are examples. Replace every `YOUR_*` placeholder before production use.
- Legacy generated External Service metadata may contain org-specific connector names and should not be treated as portable.
- Jira custom field ids and option ids differ by site/project. Confirm them in the target Jira project before using the reference agent's hardcoded option descriptions.

## License And Project Terms

This project is available under the MIT License. See `LICENSE` for the full terms.

Additional public-project guidance:

- `NOTICE`: trademark, affiliation, and project-scope notice.
- `CONTRIBUTING.md`: contribution guidelines and validation checklist.
- `SECURITY.md`: vulnerability reporting and secrets-handling policy.
- `CODE_OF_CONDUCT.md`: participation expectations.

## Documentation Index

- `docs/jira-agentforce-connector-package.md`: primary install and setup guide.
- `docs/direct-jira-actions-setup-and-test.md`: direct Apex action test scenarios.
- `docs/jira-agentforce-flow-blueprint.md`: Flow/External Service architecture notes and historical context.
- `docs/future-state-itsm-agent-script-migration-plan.md`: broader migration notes for the ITSM Agent Script direction.
