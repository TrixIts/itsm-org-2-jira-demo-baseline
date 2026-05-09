# IT Employee Assistant Agent Script Migration

This note records how the legacy Builder-based IT Employee Assistant was translated into the new Agent Script bundle at `force-app/main/default/aiAuthoringBundles/ItEmployeeAssistant/ItEmployeeAssistant.agent`.

## Legacy Inventory

The legacy source of truth is `force-app/main/default/genAiPlannerBundles/ItEmployeeAssistant/ItEmployeeAssistant.genAiPlannerBundle`.

The legacy assistant was organized around these Builder topics:

- `SoftwareManagement`
- `CloudAndInfrastructureManagement`
- `FacilitiesManagement`
- `EmployeeRequestManagement`
- `ITSecurityManagement`
- `CollaborationManagement`
- `Escalation`
- `NetworkManagement`
- `HardwareManagement`
- `EmployeeLifecycleManagement`
- `PolicyQueryManagement`
- `ComplianceManagement`

The legacy bundle used one repeated domain workflow across most IT topics:

1. Search knowledge first.
2. Confirm whether knowledge solved the issue.
3. Search eligible service catalog items.
4. For a matching catalog item, either launch a complex request flow or collect simple attributes and create a service request.
5. If the issue still is not classified, ask whether to create an incident.
6. Only create the incident after explicit employee confirmation.

`EmployeeRequestManagement` added a separate follow-up workflow for:

- ticket lookup and disambiguation
- ticket summaries
- reopen requests
- ticket comments
- strict confirmation before reopen or comment actions

## Agent Script Design

The new Agent Script bundle keeps the same topic coverage, but it uses a code-first hub-and-spoke structure:

- `start_agent topic_router` routes to domain-specific topics, ticket follow-up, policy query, escalation, or clarification.
- Each domain topic sets the active domain metadata and transitions into `shared_service_request_intake`.
- `shared_service_request_intake` centralizes the repeated knowledge, service-catalog, launch-card, incident, and hardware-asset behavior.
- `ticket_followup` isolates all existing-ticket logic so it no longer acts as the universal front door.
- `policy_query` preserves the dedicated policy-answer prompt behavior.
- `escalation` is intentionally employee-agent-safe in the first pass and documents that live-transfer wiring remains a later messaging-oriented step.

## Legacy-To-Agent Script Topic Mapping

- `SoftwareManagement` -> `software_domain` -> `shared_service_request_intake`
- `CloudAndInfrastructureManagement` -> `cloud_infrastructure_domain` -> `shared_service_request_intake`
- `FacilitiesManagement` -> `facilities_domain` -> `shared_service_request_intake`
- `ITSecurityManagement` -> `it_security_domain` -> `shared_service_request_intake`
- `CollaborationManagement` -> `collaboration_domain` -> `shared_service_request_intake`
- `NetworkManagement` -> `network_domain` -> `shared_service_request_intake`
- `HardwareManagement` -> `hardware_domain` -> `shared_service_request_intake`
- `EmployeeLifecycleManagement` -> `employee_lifecycle_domain` -> `shared_service_request_intake`
- `ComplianceManagement` -> `compliance_domain` -> `shared_service_request_intake`
- `EmployeeRequestManagement` -> `ticket_followup`
- `PolicyQueryManagement` -> `policy_query`
- `Escalation` -> `escalation`

## Managed Action Mapping

The first pass preserves managed dependencies where possible.

Shared intake actions:

- `EmployeeCopilot__AnswerQuestionsWithKnowledge` -> `standardInvocableAction://EmployeeCopilot__AnswerQuestionsWithKnowledge`
- `svc_emp_intelligence__GetEligibleServiceCatalogItems` -> `standardInvocableAction://svc_emp_intelligence__GetEligibleServiceCatalogItems`
- `svc_emp_intelligence__GetSvcCatalogAttributes` -> `standardInvocableAction://svc_emp_intelligence__GetSvcCatalogAttributes`
- `svc_emp_intelligence__CreateServiceCatalogRequest` -> `standardInvocableAction://svc_emp_intelligence__CreateServiceCatalogRequest`
- `sc_enterprise_catalog__GetProductLaunchCard` -> `standardInvocableAction://sc_enterprise_catalog__GetProductLaunchCard`
- `svc_emp_intelligence__CreateIncidentForEmployee` -> `standardInvocableAction://svc_emp_intelligence__CreateIncidentForEmployee`
- `svc_emp_intelligence__GetCurrentAssignedAssetDetails` -> deferred from the first live-preview-safe Agent Script cut because the target flow is not present in `ITSM Org 2`

Ticket follow-up actions:

- `EmployeeCopilot__IdentifyRecordByName` -> `standardInvocableAction://EmployeeCopilot__IdentifyRecordByName`
- `svc_emp_intelligence__GetRelevantTicketsByDescription` -> `flow://svc_emp_intelligence__GetRelevantTicketsByDescription`
- `svc_emp_intelligence__SummarizeTicketForEmployee` -> `generatePromptResponse://svc_emp_intelligence__SummarizeTicketForEmployee`
- `svc_emp_intelligence__ReopenTicket` -> `flow://svc_emp_intelligence__ReopenTicket`
- `svc_emp_intelligence__AddCommentToTicket` -> `flow://svc_emp_intelligence__AddCommentToTicket`

Policy action:

- `svc_emp_intelligence__AnswerPolicyQuestions` -> `generatePromptResponse://svc_emp_intelligence__AnswerPolicyQuestions`

## Schema Notes Used In The Port

The migration relied on the schema files that live under the legacy bundle, especially:

- `plannerActions/AnswerQuestionsWithKnowledge_16jHp000000CdPY/input/schema.json`
- `plannerActions/AnswerQuestionsWithKnowledge_16jHp000000CdPY/output/schema.json`
- `localActions/SoftwareManagement_16jHp000000CdPY/GetEligibleServiceCatalogItems_179Hp0000004RY8/input/schema.json`
- `localActions/SoftwareManagement_16jHp000000CdPY/GetSvcCatalogAttributes_179Hp0000004RY8/input/schema.json`
- `localActions/SoftwareManagement_16jHp000000CdPY/CreateServiceCatalogRequest_179Hp0000004RY8/output/schema.json`
- `localActions/SoftwareManagement_16jHp000000CdPY/CreateIncidentForEmployee_179Hp0000004RY8/output/schema.json`
- `localActions/HardwareManagement_16jHp000000CdPY/GetCurrentAssignedAssetDetails_179Hp0000004RY6/output/schema.json`
- `localActions/EmployeeRequestManagement_16jHp000000CdPY/GetRelevantTicketsByDescription_179Hp0000004RYB/input/schema.json`
- `localActions/EmployeeRequestManagement_16jHp000000CdPY/AddCommentToTicket_179Hp0000004RYB/input/schema.json`
- `localActions/EmployeeRequestManagement_16jHp000000CdPY/ReopenTicket_179Hp0000004RYB/input/schema.json`
- `localActions/PolicyQueryManagement_16jHp000000CdPY/AnswerPolicyQuestions_179Hp0000004RY4/input/schema.json`

## Important Follow-Up Gaps

- The legacy Builder bundle depended heavily on managed actions that are not repo-local metadata. The first-pass Agent Script bundle assumes those targets are callable from Agent Script and leaves final target validation to CLI validation and org testing.
- Live preview confirmed that `svc_emp_intelligence__GetCurrentAssignedAssetDetails` is not available in `ITSM Org 2`, so assigned-hardware lookup was removed from the first-pass bundle to keep live preview unblocked.
- After removing the missing hardware action, live preview hit an org/runtime prerequisite: `ITSM Org 2` has the `Einstein Agent User` profile and the required permission sets (`AgentforceServiceAgentBase`, `AgentforceServiceAgentUser`, `EinsteinGPTPromptTemplateUser`), but no actual active user on that profile. That blocks service-agent-style live preview setup in the org today.
- The legacy bundle was messaging-oriented in several places. The new bundle is intentionally `AgentforceEmployeeAgent` first, so messaging-only context fields were not carried over into the first Agent Script version.
- The legacy bundle contains a `"<Replace with site name>"` placeholder for the launch-card flow. The Agent Script version intentionally treats `siteName` as optional until a real employee-surface source is decided.
- `EmployeeRequestManagement` formatting behavior in the legacy bundle depended on prompt prose and opaque managed output formats. The new `ticket_followup` topic preserves the behavior at the topic level, but true deterministic single-ticket versus multi-ticket branching will require either a structured search result contract or a repo-owned adapter action.
- The managed prompt actions use legacy input names that include `Input:` prefixes. Those names were preserved in the first pass because they appear in the legacy action schemas and are likely required by the managed targets.
