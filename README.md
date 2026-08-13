# Portable Jira Agentforce

A source-org-neutral Salesforce DX package for connecting Agentforce to Jira Cloud or Jira Service Management.

## Included

- **IT Employee Assistant (Jira)** — creates issues, checks exact issues, lists the configured employee reporter's open issues, and adds confirmed public comments.
- **IT Fulfiller (Jira)** — searches queues, investigates issues, creates issues, performs allowlisted field updates, comments, assigns, and transitions.
- **Jira Connector Mapping** — discovers projects, issue types, Jira fields, and the authenticated Jira identity through the target org's Named Credential.
- Apex REST actions, profile and mapping objects, custom permissions, runtime permission sets, audit records, and tests.

## Portability Guarantees

This repository does not ship:

- Named Credential secrets or Jira API tokens
- Jira site URLs, cloud IDs, project IDs, issue type IDs, account IDs, or custom field IDs
- Salesforce usernames or reporter mappings
- Bot, BotVersion, generated planner, preview trace, or published-version snapshots
- generated External Service metadata or source-org Flows
- managed ITSM, service catalog, Slack, Okta, GitHub, Box, or change-request dependencies

The target org selects its own Jira settings in the **Jira Connector Mapping** workspace after deployment.

## Install

1. Authenticate the target Salesforce org.

```bash
sf org login web --alias <target-org>
sf config set target-org <target-org>
```

2. Deploy the connector only.

```bash
sf project deploy start --json \
  --manifest manifest/jira-agentforce-connector-package.xml \
  --target-org <target-org>
```

3. Create the Jira Named Credential and assign `Jira_Connector_Mapping_Admin` to the setup administrator.

4. Open **Jira Connector Mapping**, enter the Named Credential API name, load projects, select the project and issue type, mark the profile active, and mark exactly one profile as **Employee Default**.

5. Sync Jira fields and review the allowed mappings.

6. Run the connector tests.

```bash
sf apex run test --json \
  --tests JiraDirectActionsTest,JiraFulfillerActionsTest,JiraConnectorMappingControllerTest \
  --target-org <target-org> \
  --wait 30
```

7. Validate and deploy the agents.

```bash
sf agent validate authoring-bundle --json --api-name ItEmployeeAssistantV3
sf agent validate authoring-bundle --json --api-name IT_Fulfiller_Jira

sf project deploy start --json \
  --manifest manifest/jira-agentforce-agents-package.xml \
  --target-org <target-org>
```

Publishing and activation are separate, explicit steps. See [Setup](docs/setup.md).

## Configuration Model

`Jira_Connector_Profile__c` is the primary runtime configuration source. The admin workspace fills it from the Jira instance connected to the Named Credential.

Employee reporter resolution uses:

1. an optional Salesforce username mapping in `Jira_Demo_Setting__mdt`;
2. an optional shared reporter account ID on the employee-default profile;
3. the authenticated Named Credential principal returned by Jira `/rest/api/3/myself`.

Custom metadata remains available only for backwards-compatible user mappings and legacy direct-action configuration. No custom metadata records are included in the deployment manifest.

## Documentation

- [Setup](docs/setup.md)
- [Configuration and identity](docs/configuration.md)
- [Validation and tests](docs/testing.md)
- [Agent and package specification](docs/portable-jira-agentforce-spec.md)

## License

MIT. See `LICENSE` and `NOTICE`.
