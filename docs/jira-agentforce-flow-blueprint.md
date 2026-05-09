# Jira + Agentforce Flow Blueprint

This blueprint is the recommended pattern when the customer wants Jira to remain the primary backend while Agentforce remains the employee-facing experience in Slack, Teams, voice, or Salesforce channels.

## Recommended Operating Model

- Jira is the system of record for the ticket.
- Salesforce `Incident` is an optional shadow record used for Agentforce context, analytics, routing, or demo visibility.
- Mule owns cross-system correlation and translation logic.
- Agentforce should lead user responses with the Jira key, not the Salesforce incident id.

## Flows Added

### `Create_Jira_Issue`

Purpose:
- Create a Jira incident directly through the generated `JiraV2.createIssue` external connector action.
- Accept Salesforce-side context from Agentforce or other orchestration and map it into Jira fields.

Current contract in the flow:
- Inputs:
  - `inp_JiraSummary`
  - `inp_JiraDescription`
  - `inp_IncidentPriority`
  - `inp_JiraUrgencyOptionId`
  - `inp_JiraImpactOptionId`
  - `inp_JiraSeverityOptionId`
  - `inp_RequesterEmail`
  - `inp_Channel`
  - `inp_SourceReference`
- Outputs:
  - `out_IsSuccess`
  - `out_Message`

Connector notes:
- The flow uses the live action shape retrieved from the org:
  - action name: `JiraV2.createIssue`
  - connection: `JiraV21Jira_SM`
  - project id: `10001`
  - issue type id: `10001` (`[System] Incident`)
- The flow currently maps Jira custom fields by option id because that is the least ambiguous connector input shape.
- After saving in Flow Builder, Salesforce serializes the accepted custom-field paths as:
  - `customfieldx5f10043.id` for `Urgency`
  - `customfieldx5f10004.id` for `Impact`
  - `customfieldx5f10048.id` for `Severity`
- That Builder-generated `x5f` form is the safe source of truth for local metadata. Hand-authoring plain `customfield_10043.id` or `customfield_10043` paths can deploy, but may reopen as invalid in Flow Builder.

### `Sync_Jira_Update_To_Incident`

Purpose:
- Accept a Jira update payload from Mule.
- Update the related Salesforce `Incident` shadow record.
- Keep Agentforce-visible status fresh enough for follow-up conversations.

Why this flow is autolaunched:
- A Jira webhook should hit Mule.
- Mule should translate the raw Jira payload into Salesforce-safe values.
- Mule should then invoke this flow with the correlated `Incident` Id.
- This avoids polling and avoids forcing Salesforce to interpret Jira workflow semantics directly.

Current contract in the flow:
- Inputs:
  - `inp_IncidentId`
  - `inp_IncidentStatus`
  - `inp_IncidentPriority`
  - `inp_JiraIssueKey`
  - `inp_JiraSummary`
  - `inp_JiraAssignee`
  - `inp_JiraResolution`
  - `inp_JiraUrgency`
  - `inp_JiraImpact`
  - `inp_JiraSeverity`
  - `inp_JiraUpdatedAt`
  - `inp_JiraLatestComment`
- Outputs:
  - `out_IsSuccess`
  - `out_Message`

### `Update_Jira_Issue`

Purpose:
- Update a Jira issue directly through the generated `JiraV2.updateIssue` external connector action.
- Use the same Builder-accepted custom field serialization pattern as the create flow for Impact, Urgency, and Severity.

Current contract in the flow:
- Inputs:
  - `inp_JiraIssueIdOrKey`
  - `inp_JiraSummary`
  - `inp_JiraImpactOptionId`
  - `inp_JiraUrgencyOptionId`
  - `inp_JiraSeverityOptionId`
- Outputs:
  - `out_IsSuccess`
  - `out_Message`

### `Get_Jira_Issues`

Purpose:
- Query Jira issues directly through the generated `JiraV2.getIssues` external connector action.
- Provide a first reusable lookup wrapper that returns whether the query succeeded.

Current contract in the flow:
- Inputs:
  - none yet; the first implementation uses the saved Builder filter shell from the captured `JIRA_TEST` flow
- Outputs:
  - `out_IsSuccess`
  - `out_Message`

### Agentforce field mapping

Confirmed Jira custom fields from live metadata:
- `customfield_10043` = `Urgency`
- `customfield_10004` = `Impact`
- `customfield_10048` = `Severity`

Confirmed Builder-safe update paths from live Flow save:
- `summary`
- `customfieldx5f10043.id`
- `customfieldx5f10004.id`
- `customfieldx5f10048.id`
- `labels[$EachItem]` is also supported by the connector, but is not yet wired into the reusable update flow

Allowed option ids:
- Urgency:
  - `10020` = `Critical`
  - `10021` = `High`
  - `10022` = `Medium`
  - `10023` = `Low`
- Impact:
  - `10000` = `Extensive / Widespread`
  - `10001` = `Significant / Large`
  - `10002` = `Moderate / Limited`
  - `10003` = `Minor / Localized`
- Severity:
  - `10028` = `Sev-0`
  - `10029` = `Sev-1`
  - `10030` = `Sev-2`
  - `10031` = `Sev-3`

Recommended upstream mapping contract:
- Translate Salesforce `Incident` values to these Jira option ids before invoking `Create_Jira_Issue`.
- When reading issue details back into Agentforce, prefer the human-readable `.value` from Jira for customer responses.

## How Agentforce Should Use This

### Ticket creation

Agentforce should call `Create_Jira_Issue` when the employee explicitly wants a ticket created or the issue is urgent/blocking.

Reply pattern:
- lead with the Jira key
- optionally mention the Salesforce incident shadow record only if it exists and is useful

Example response shape:
- "Your Jira ticket `IT-1234` is created. I also created Salesforce incident context for internal tracking."

### Ticket updates and status checks

Preferred pattern:
- Agentforce reads Jira status through a Mule-backed action when the employee explicitly asks for the latest status.
- The synced Salesforce `Incident` is a fast local shadow, not the source of truth.

That means the agent can still provide updates:
- best case: check Jira live through Mule and answer directly
- fallback: answer from the latest synced Salesforce shadow note and say it is the latest synced update

### Comments, reopen, and transitions

For this customer model, comments and reopen behavior should target Jira first.

Recommended follow-on flows or actions:
- `Add_Jira_Comment`
- `Transition_Jira_Issue`
- `Get_Jira_Issue_Status`

Then optionally sync the Salesforce incident shadow after the Jira action succeeds.

## Edge Cases To Handle

### 1. Jira create succeeds, Incident shadow fails

Handled by orchestration design:
- return the connector success payload to the caller
- tell the user the Jira ticket exists
- keep any Salesforce shadow-write as a separate follow-on step if needed

### 2. Incident exists, but webhook arrives with no correlation

Handled by process design:
- Mule must store correlation between Jira issue id/key and Salesforce `Incident` id
- if correlation is missing, do not guess; route to an ops queue or retry process

### 3. Duplicate Jira webhook events

Recommended handling in Mule:
- dedupe on Jira issue id + event timestamp + changelog id
- only invoke the sync flow once per logical change

### 4. Out-of-order webhook delivery

Recommended handling in Mule:
- compare the incoming Jira update timestamp to the last processed timestamp in Mule state
- drop stale updates before invoking the flow

### 5. Jira workflow values do not match Salesforce picklists

Do not map raw Jira values inside Flow.

Instead:
- Mule translates Jira workflow states to valid Salesforce `Incident.Status` values
- Mule translates Jira priority values to valid Salesforce `Incident.Priority` values

### 6. Sensitive comments or internal-only Jira notes

Do not sync all comment bodies blindly.

Recommended:
- sync only customer-safe comment text or a summary
- skip internal/private notes unless the business explicitly wants them exposed

### 7. Attachments

Do not treat attachment sync as part of the base flow.

Recommended:
- keep attachments as a later phase because file movement, auth, and retention rules are usually separate

### 8. Agentforce answers from stale shadow data

Recommended response policy:
- if sync freshness is uncertain, the agent should say it can check Jira live
- do not overstate certainty from shadow data alone

## Deployment and Build Notes

1. Keep `Create_Jira_Issue` as the outbound Jira create action.
2. Have Mule persist the Jira-to-Incident correlation.
3. Configure Jira webhook -> Mule -> `Sync_Jira_Update_To_Incident`.
4. Add a dedicated Jira query flow next, using a retrieved live connector action shape from Flow Builder.
5. Add a Jira update or comment flow next, also using a retrieved live connector action shape from Flow Builder.
6. Expose the create flow to Agentforce as a flow-backed action, or wrap it in your agent action layer.

### Current capture status

- Captured from live Builder save:
  - `JiraV2.createIssue`
  - `JiraV2.updateIssue`
- Not yet captured from a Builder-saved flow:
  - `JiraV2.getIssues`

`JiraV2.getIssues` now has a valid saved filter shell from Builder, but output resource mapping still needs a dedicated reusable flow design if you want Agentforce-friendly structured outputs rather than just the raw connector action result.

The first reusable query flow therefore acts as a clean wrapper around the Builder-accepted `getIssues` action shell instead of attempting to parse the returned collection in metadata. A second refinement is still needed if you want the flow itself to emit issue key, summary, status, or issue count as individual output variables.

### `Get_Jira_Issue_By_Key`

Purpose:
- Look up a Jira issue by exact Jira key, which is the safest Agentforce lookup path when an employee asks for a ticket update.
- Avoid ambiguous broad searches by requiring a specific Jira key such as `IT-123`.

Current contract in the flow:
- Inputs:
  - `inp_JiraIssueKey`
- Outputs:
  - `out_IsSuccess`
  - `out_Message`

Design note:
- This flow uses an exact-key filter strategy rather than a generic search strategy.
- Because the connector result collection still isn’t cleanly assignable to formal flow outputs in metadata, the flow currently acts as an exact-match wrapper around the lookup action rather than exposing parsed Jira fields.

The Jira external service registration metadata currently materializes only the project-and-issue-type-specific create object schema, so the read/update flow contracts still need to be captured from a saved Flow Builder action.

## Official References

- Salesforce Help: [Third-Party Connectors in Flow](https://help.salesforce.com/s/articleView?id=platform.automate_flow_ref_third_party_connectors.htm&type=5)
- Salesforce Help: [Use MuleSoft for Flow](https://help.salesforce.com/s/articleView?id=platform.automate_concepts_use_mulesoft_for_flow.htm&language=en_US&type=5)
- Salesforce Developers: [Subscribe to Platform Event Messages with Flows](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_subscribe_flow.htm)

The platform event reference is included because, if you later want to remove the direct Mule-to-Flow invocation, a platform-event-driven sync path is the next cleanest event pattern.
