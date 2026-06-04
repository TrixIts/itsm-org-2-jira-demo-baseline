# Security Policy

## Supported Scope

This repository is a demo baseline for a Salesforce Agentforce Jira connector.
Security reports should relate to the source metadata, Apex code, Agent Script
examples, setup documentation, or public packaging guidance in this repo.

## Reporting A Vulnerability

Please do not open a public issue for a suspected vulnerability.

Report privately to the repository owner through GitHub's private vulnerability
reporting feature if it is enabled. If private reporting is not enabled, contact
the owner through the public GitHub organization profile and include only enough
detail to establish contact. Share exploit details privately after a secure
channel is established.

## Secrets And Sensitive Data

Do not commit or submit:

- Jira API tokens, OAuth secrets, passwords, private keys, or session tokens.
- Salesforce org credentials or scratch org auth files.
- Real Jira account IDs mapped to real Salesforce usernames.
- Production customer, employee, incident, or ticket data.

Use placeholders such as `Jira_Named_Credential`,
`YOUR_JIRA_PROJECT_ID`, and `YOUR_JIRA_ACCOUNT_ID` in reusable examples.

## Responsible Disclosure

The project maintainers will make a reasonable effort to acknowledge reports,
validate impact, and publish fixes or mitigation guidance. This project is
provided under the MIT License without warranty.
