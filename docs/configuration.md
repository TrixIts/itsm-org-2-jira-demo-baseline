# Configuration and Identity

## Connector Profiles

Each `Jira_Connector_Profile__c` record identifies:

- the Named Credential API name;
- Jira project and issue type;
- browse base URL;
- open-issue JQL suffix;
- Agentforce activation and route settings;
- optional shared employee reporter.

The setup workspace discovers project IDs, issue type IDs, and Jira fields from the connected Jira instance. These values are runtime records, not source-controlled metadata.

## Employee Default

Exactly one active Agentforce profile must have `Employee_Default__c = true`.

Employee actions fail closed when:

- no employee-default profile exists;
- multiple employee-default profiles exist;
- the Named Credential, project ID, or issue type ID is missing;
- an issue is outside the configured project;
- reporter scope cannot be verified.

## Reporter Resolution

Employee actions resolve Jira reporter identity in this order:

1. A `Jira_Demo_Setting__mdt` user mapping matching the Salesforce username.
2. `Shared_Reporter_Account_Id__c` on the employee-default profile.
3. The Jira account returned by `/rest/api/3/myself` for the Named Credential principal.

A shared Jira Service Management customer can be used as the employee reporter without making that customer a licensed JSM agent. Jira licensing and permissions should still be confirmed with the Jira administrator.

## Fulfiller Identity

Fulfiller actions authenticate with the Named Credential on the selected connector profile. Jira records the integration principal as the actor for comments, assignments, field updates, and transitions.

Use a dedicated fulfiller integration principal when audit attribution or separation from the employee reporter is required.

## Custom Fields

Impact, urgency, severity, and other Jira custom fields are optional.

- The portable employee agent does not assume these fields exist.
- The fulfiller agent can use fields only after they are discovered and allowlisted in `Jira_Field_Mapping__c`.
- No `customfield_*` IDs or option IDs are included in source.

## Legacy Custom Metadata

`Jira_Demo_Setting__mdt` remains in the package for backwards compatibility and optional Salesforce-user mappings. The package does not deploy custom metadata records.

New installations should use connector profiles for site, project, issue type, and reporter settings.
