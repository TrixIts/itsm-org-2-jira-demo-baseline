# Future-State ITSM Agent Script Migration Checklist

This document turns the imported strategy plan into a working checklist for this project.

## Goal
Build a future-state ITSM/HR demo where:
- Salesforce remains the conversation and orchestration layer
- Confluence is the grounded knowledge source
- Jira Service Management is the primary ticket backend
- Salesforce `Incident` creation stays optional for demos
- new-org builder-based agents are ported into `Agent Script`

## Working Decisions
- [ ] Confirm Jira Service Management Free is acceptable for the showcase and capture the limits that matter to this build.
- [ ] Treat `Agent Script` as the target source of truth for agent behavior in this project.
- [ ] Keep knowledge grounding Salesforce-managed, with Confluence as the content source.
- [ ] Design Jira as the primary ticket backend, with Mule for Flow first and Apex/direct API only where needed.
- [ ] Keep Salesforce `Incident` creation behind an explicit demo-only toggle.

## Phase 0: Project Baseline
- [ ] Keep this project as the source of truth for the second-org implementation.
- [ ] Verify org connectivity and required package or license prerequisites.
- [ ] Inventory what exists out of the box in the target org before building anything new.
- [ ] Record the source-of-truth decision: `Agent Script` over legacy builder metadata.

## Phase 1: Inventory and Port OOTB Agents
- [ ] Identify which out-of-box ITSM or HR agents in the new org are still builder-based.
- [ ] Document each candidate agent's topics, actions, routing behavior, and dependencies.
- [ ] Choose which agents must be ported for the showcase.
- [ ] Create `Agent Script` equivalents for the selected agents.
- [ ] Preserve useful user-facing behavior while modernizing the implementation model.

### Reference Assets
- [ ] Review the existing Agent Script reference: `IT_Service_Employee_AgentScript.agent`
- [ ] Review current behavior references from legacy bot and planner metadata.
- [ ] Reuse patterns from current flows only after removing org-specific assumptions.

## Phase 2: Separate Salesforce-Native vs Jira/Confluence Responsibilities
- [ ] Keep employee identity lookup in Salesforce.
- [ ] Keep the Omni or messaging front door in Salesforce.
- [ ] Keep password reset, provisioning, and onboarding orchestration in Salesforce.
- [ ] Replace knowledge answer behavior with a Confluence-grounded action.
- [ ] Replace incident or ticket creation with Jira-backed actions.
- [ ] Replace issue lookup and summarization with Jira-backed actions.
- [ ] Define which behaviors remain demo-only, especially Salesforce `Incident` shadow writes.

## Phase 3: Design the Knowledge Architecture
- [ ] Validate whether the target org has the required Data Cloud, retriever, or grounding capabilities.
- [ ] Validate the preferred Confluence connector path.
- [ ] Define the fallback ingest or indexing approach if the preferred connector is unavailable.
- [ ] Decide how citations are surfaced in agent responses.
- [ ] Define fallback behavior when grounded retrieval cannot answer the question.

## Phase 4: Stand Up the Jira Integration Boundary
- [ ] Define the Jira integration contract the agent will rely on.
- [ ] Start with Mule for Flow for simple create, retrieve, update, and comment operations.
- [ ] Decide which Jira behaviors require Apex or direct API instead.
- [ ] Identify advanced needs such as ADF formatting, transitions, attachments, retries, async behavior, observability, and webhooks.
- [ ] Define how errors from Jira are translated into agent-safe responses.

## Phase 5: Add Backend Mode and Data Mapping
- [ ] Create backend mode metadata such as `ITSM_Backend_Mode__mdt`.
- [ ] Define supported modes: `JiraOnly`, `SalesforceOnly`, and `DualWrite`.
- [ ] Define Jira request type mapping metadata.
- [ ] Define priority, urgency, and status translation metadata.
- [ ] Decide whether a durable Jira-to-Salesforce correlation object is needed.

## Phase 6: Refactor Agent Actions Around Backend-Agnostic Contracts
- [ ] Define a backend-agnostic action catalog for the agent.
- [ ] Create or plan actions such as:
  - [ ] `Search_Knowledge_From_Confluence_Grounding`
  - [ ] `Create_Jira_Request`
  - [ ] `Find_Jira_Request`
  - [ ] `Summarize_Jira_Request`
  - [ ] `Create_Demo_Salesforce_Incident`
  - [ ] `Create_Ticket_With_Selected_Backend`
- [ ] Preserve the expected conversation behavior:
  - [ ] search knowledge first
  - [ ] confirm whether knowledge solved the issue
  - [ ] require explicit consent before ticket creation
  - [ ] support follow-up status checks and summaries

## Phase 7: Optional Dual-Write for Demos
- [ ] Create Jira first and treat the Jira key as primary.
- [ ] Only create Salesforce `Incident` when demo mode is enabled.
- [ ] Store cross-system references where practical.
- [ ] Keep the user-facing response simple and lead with the Jira identifier.

## Phase 8: End-to-End Validation
- [ ] Validate a knowledge question answered from Confluence-grounded retrieval.
- [ ] Validate escalation from unresolved issue to Jira ticket creation.
- [ ] Validate follow-up status retrieval and Jira summarization.
- [ ] Validate optional Salesforce `Incident` shadow-write behavior.
- [ ] Validate that provisioning and password reset flows still work alongside the Jira-backed design.

## Reuse Guidance
### Reuse First
- [ ] `Reset_Okta_Password.flow-meta.xml` as the cleanest initial flow pattern to borrow.
- [ ] Employee lookup, provisioning, and routing flows as references only after review.
- [ ] Existing external integration patterns as architectural examples, not drop-in assets.

### Review Before Reuse
- [ ] Draft flows such as `Lookup_Employee_Details`, `Provision_Dropbox_via_Okta`, and `Add_Employee_to_Slack_Channels`.
- [ ] Slack and Okta flow assets for org-specific connection details.

### Do Not Port Blindly
- [ ] Managed-package ITSM incident behavior tied to `svc_itsm_intelligence__*`
- [ ] Legacy bot or planner metadata as deployable runtime source
- [ ] Org-specific auth and identity setup copied without review
- [ ] Old console or `Incident` UI assets unless the demo explicitly needs them

## Expected Build Areas
### Flow Work
- [ ] `Create_Jira_Request`
- [ ] `Get_Jira_Request`
- [ ] `Update_Jira_Request`
- [ ] `Search_Jira_Request`
- [ ] `Create_Demo_Salesforce_Incident`
- [ ] `Create_Ticket_By_Backend_Mode`

### Apex Work
- [ ] `JiraClient`
- [ ] `JiraRequestMapper`
- [ ] `JiraIssueFormatter`
- [ ] `JiraErrorTranslator`
- [ ] `JiraWebhookController`
- [ ] `JiraInvocableActions`

### Metadata and Configuration Work
- [ ] Jira Named Credential or External Credential if direct API is used
- [ ] backend toggle custom metadata
- [ ] Jira request-type mapping metadata
- [ ] priority, urgency, and status translation metadata
- [ ] optional correlation object for Jira-to-Salesforce linkage

## Main Risks
- [ ] JSM Free may be fine for a showcase but too limited for anything more serious.
- [ ] The target org may not have the exact grounding capabilities required for the preferred Confluence path.
- [ ] Current source material has drift between legacy builder metadata and newer Agent Script direction.
- [ ] Some integration setup in the older project is incomplete or org-specific.
- [ ] Dual-write adds demo value but should remain optional.

## Suggested First Execution Pass
- [ ] Inventory builder-based agents in the new org that should be ported to `Agent Script`.
- [ ] Validate Agentforce and grounding capabilities in the new org.
- [ ] Design the Jira integration contract and split Mule-for-Flow versus Apex responsibilities.
- [ ] Define backend mode metadata and Jira field mapping.
- [ ] Refactor the first employee-facing agent to backend-agnostic actions.
- [ ] Add optional Salesforce `Incident` shadow-write mode.
- [ ] Run end-to-end tests for knowledge, ticketing, and demo mode.
