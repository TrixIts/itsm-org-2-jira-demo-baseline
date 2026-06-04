# Contributing

Thanks for your interest in improving this Jira Agentforce demo baseline.

## Development Guidelines

- Keep changes focused on the Jira connector, Agentforce wiring, setup docs, or clearly labeled reference-agent improvements.
- Do not commit credentials, API tokens, OAuth secrets, session files, org-specific user mappings, or production customer data.
- Replace org-specific names, usernames, Jira account IDs, Jira project IDs, custom field IDs, and endpoint names with placeholders when adding reusable examples.
- Prefer source-deployable Salesforce metadata and Salesforce CLI commands that work from a clean clone.
- Document new setup requirements in `README.md` or `docs/jira-agentforce-connector-package.md`.

## Validation

Before opening a pull request, run the most relevant checks for your change:

```bash
sf project deploy validate --manifest manifest/jira-agentforce-connector-package.xml --target-org <target-org> --json
sf apex run test --tests JiraDirectActionsTest,ConnectedTicketActionsTest,JiraConnectorMappingControllerTest --target-org <target-org> --wait 30 --result-format human
```

If you change the reference Agent Script bundle, also validate it in an org that has the required Agentforce dependencies:

```bash
sf agent validate authoring-bundle --api-name ItEmployeeAssistantV3 --target-org <target-org> --json
```

## Pull Request Checklist

- The change is scoped and documented.
- No secrets or real personal identifiers are included.
- Placeholder values are obvious and documented.
- Tests or validation steps are listed in the pull request.
- Deployment-impacting changes identify any required target-org setup.
