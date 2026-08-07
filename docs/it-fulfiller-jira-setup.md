# IT Fulfiller (Jira) — Setup & Configuration Companion

This companion covers configuration specific to the **IT Fulfiller (Jira)** agent (`IT_Fulfiller_Jira`) and its hardened multi-project runtime (`JiraFulfillerSupport` + `JiraFulfiller*Action` classes). It builds on the connector model documented in `jira-agentforce-connector-package.md`.

## Components delivered

- Agent bundle: `force-app/main/default/aiAuthoringBundles/IT_Fulfiller_Jira/`
- Runtime support: `JiraFulfillerSupport`
- Actions (invocable Apex): `JiraFulfillerSearchIssuesAction`, `JiraFulfillerGetIssueDetailAction`, `JiraFulfillerCreateIssueAction`, `JiraFulfillerPrepareFieldUpdateAction`, `JiraFulfillerApplyFieldUpdateAction`, `JiraFulfillerAddCommentAction`, `JiraFulfillerGetTransitionsAction`, `JiraFulfillerTransitionIssueAction`, `JiraFulfillerSearchAssigneeAction`, `JiraFulfillerAssignIssueAction`
- Shared helpers added to `JiraIntegrationSupport`: `sendRequestVia`, `sendRequestRawVia`, `escapeJql`, `adfToText`
- Custom permissions: `Jira_Fulfiller_Search`, `Jira_Fulfiller_Read`, `Jira_Fulfiller_Create`, `Jira_Fulfiller_Field_Update`, `Jira_Fulfiller_Comment`, `Jira_Fulfiller_Assign`, `Jira_Fulfiller_Transition`
- Permission sets: `Jira_Fulfiller_Runtime` (write-capable), `Jira_Fulfiller_Read_Only`
- Tests: `JiraFulfillerActionsTest`
- Reused objects: `Jira_Connector_Profile__c`, `Jira_Field_Mapping__c`, `Jira_Integration_Transaction__c`

## Multi-project configuration

Each Jira project the agent can work with is a `Jira_Connector_Profile__c` record. The agent only sees profiles where **both** `Active__c` and `Is_Active_For_Agentforce__c` are `true`.

Per profile, set:

| Field                              | Purpose                                                             |
| ---------------------------------- | ------------------------------------------------------------------- |
| `Connector_Key__c`                 | Stable key used to select this project on create (`connectorKey`).  |
| `Route_Key__c`                     | Friendly route selector on create (e.g. `incident`, `request`).     |
| `Named_Credential_Api_Name__c`     | Named Credential for this Jira site (must exist and be authorized). |
| `Project_Id__c` / `Project_Key__c` | Jira project id (for create) and key (for scope validation).        |
| `Issue_Type_Id__c`                 | Issue type used when creating in this project.                      |
| `Browse_Base_Url__c`               | HTTPS base used to build issue URLs.                                |

Issue keys are validated against the set of active `Project_Key__c` values. Keys outside that set are rejected with a `SCOPE` error before any read or write.

**Single-project fallback:** if no Agentforce-active connector profiles exist, the runtime falls back to the legacy single-project `Jira_Demo_Setting__mdt` config (`NamedCredentialApiName`, `ProjectId`, `IssueTypeId`, `ProjectKey`, `BrowseBaseUrl`). In that mode only `summary` and `priority` are updatable by default.

## Allowlisting fields for "update any field"

"Update any field" means any Jira field an administrator has explicitly enabled. For each updatable field, add a `Jira_Field_Mapping__c` record with:

- `Connector_Key__c` = the profile's connector key
- `Enabled__c` = `true`
- `Allow_Agent_Update__c` = `true`
- `Backend_Field_Key__c` = the Jira field key (e.g. `summary`, `priority`, `customfield_10004`)
- `Canonical_Field__c` = a friendly alias the agent can use (e.g. `summary`, `priority`, `impact`)
- `Backend_Field_Label__c` = label shown in previews
- `Transform_Type__c` = one of:
  - `Direct` — send the raw string
  - `Option Id` — send `{ "id": <mapped id> }`; supply the alias→id map in `Transform_Config_JSON__c`
  - `User Mapping` — resolve a Salesforce username to a Jira accountId via the existing user-mapping metadata
  - (blank) — `priority` is automatically sent as `{ "name": <value> }`

Fields with `Use_In_Summary__c = true` are also included in the issue-detail summary.

Any field not allowlisted is rejected in the preview step; the agent tells the fulfiller an administrator must enable it. There is no unrestricted arbitrary-field write.

## Confirmation model

- **Field updates** are two-phase. `prepare_jira_field_update` validates the allowlist/scope/options, checks the issue is not closed, and returns an exact preview plus a short-lived (15-minute) single-use token stored as a `Pending` `Jira_Integration_Transaction__c`. `apply_jira_field_update` refuses to run without a matching, unexpired, unconsumed token for the same issue.
- **Comments, transitions, and assignments** require `confirmedByEmployee = true` plus exact-value confirmation (issue key, and comment text / transition id / assignee account id) validated in Apex.
- **Create** requires `confirmedByEmployee = true` and reuses a correlation key for idempotency.

## Permissions

Assign `Jira_Fulfiller_Runtime` to the agent's running user for full fulfillment, or `Jira_Fulfiller_Read_Only` for read-only fulfillers. Each action enforces its own custom permission, so removing a single permission cleanly disables that capability.

## Named Credential prerequisites

Every `Named_Credential_Api_Name__c` referenced by an active profile (and the legacy `NamedCredentialApiName`) must name an authorized Salesforce Jira OAuth connection or Named Credential. For the managed Jira connector, use the connection's **Developer Name** (for example, `JiraV21Jira_SM`). Its base URL must stop before `/rest/api/3`, because the Apex runtime appends `/rest/api/3/...` to each call. Authorize the connection and grant its principal to the Agentforce running users before publishing either agent.

## Analysis modes (instruction-only, no new Apex)

A capability-hardening pass (see `IT_Fulfiller_Jira-Hardening-Addendum.md`) adds reasoning-driven work products on top of the existing actions. No new Apex or backing logic was added; the agent reasons only over data the current actions return plus context the fulfiller supplies in conversation.

**Case workbench (`issue_investigation`).** After `get_jira_issue_detail` runs, the agent persists the individual grounded facts (key, summary, status, priority, resolution/closed, reporter, assignee, description, mapped fields, recent comments, recent history, URL). It can then produce, on request:

- Case brief (short grounded summary)
- Fact vs. assessment triage (confirmed Jira facts separated from fulfiller hypothesis)
- Missing-information checklist (labels anything not returned by Jira as `Unknown`)
- Next-best-action recommendation (routes to the matching write action when chosen)
- Handoff / escalation summary
- Requester update draft (review-only until routed through `add_jira_comment`)
- Internal note draft (review-only, same routing)
- Proposed field changes as a draft `changesJson` (applied only via `prepare_jira_field_update` + confirmed `apply_jira_field_update`)

**Fulfiller context capture.** Operational context the fulfiller states in conversation — goal, business impact, affected users, urgency rationale, evidence, work already completed, blockers/constraints, desired next step — is captured via LLM slot-filling into `case_context` and clearly treated as fulfiller input, never as Jira data.

**Queue analytics (`queue_analysis`).** On request the agent adds a page-scoped analytics section (counts by status/priority/assignee, notable issues, recommended drill-downs) computed only from the rows in the returned page. It always distinguishes the returned page (`returnedCount`) from total matching (`totalCount`) and offers to page further before drawing broader conclusions.

### Limits of instruction-only analytics

- Analytics are limited to the rows in a single returned page. The agent does not compute full-dataset aggregates, cross-issue rollups, or trends that would require server-side queries.
- The agent never invents SLA status, ticket age/staleness, or root cause. Age is stated only when grounded in a returned `updated`/history value; otherwise it is reported as not returned by Jira.
- Drafts (comments, notes, field changes) are never auto-applied. Every mutation retains its existing exact-value confirmation and, for field updates, the two-phase preview token.
- All Jira content remains untrusted external data; drafts derived from it are treated as data and embedded instructions are never followed.

## Deployment (requires separate approval)

This build stops at local validation. When approved to deploy, deploy only the scoped dependencies (the fulfiller classes, custom permissions, permission sets, and the `IT_Fulfiller_Jira` bundle), then run `JiraFulfillerActionsTest`, live-preview against controlled Jira records, and re-confirm before publishing/activating.
