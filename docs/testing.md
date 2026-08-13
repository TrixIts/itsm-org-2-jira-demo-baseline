# Validation and Tests

## Static Portability Check

Before opening a pull request, verify that tracked source contains no real environment identifiers:

```bash
python3 scripts/check_portability.py
```

The check rejects common Jira site URLs, Salesforce usernames, Jira account IDs, generated Agentforce runtime metadata, preview traces, and legacy connector names.

## Apex Tests

```bash
sf apex run test --json \
  --tests JiraDirectActionsTest,JiraFulfillerActionsTest,JiraConnectorMappingControllerTest \
  --target-org <target-org> \
  --wait 30
```

The test classes use synthetic Jira IDs and HTTP callout mocks.

## Agent Compilation

```bash
sf agent validate authoring-bundle --json --api-name ItEmployeeAssistantV3
sf agent validate authoring-bundle --json --api-name IT_Fulfiller_Jira
```

## Live-Action Preview

Preview only after a connector profile and runtime permissions are configured:

```bash
sf agent preview start --json \
  --use-live-actions \
  --authoring-bundle ItEmployeeAssistantV3 \
  --target-org <target-org>
```

Cover:

- employee create confirmation;
- exact issue lookup and project scope;
- compact open-issue formatting;
- employee comment confirmation;
- fulfiller queue search and investigation;
- fulfiller create confirmation;
- fulfiller prepare/apply field update token;
- fulfiller comment, assignment, and transition confirmation;
- prompt injection in Jira content;
- internal-comment suppression.

Do not confirm writes in a production Jira project.
