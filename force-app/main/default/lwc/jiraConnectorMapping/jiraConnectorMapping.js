import { LightningElement, track } from 'lwc';
import getJiraIssueTypes from '@salesforce/apex/JiraConnectorMappingController.getJiraIssueTypes';
import getJiraProjects from '@salesforce/apex/JiraConnectorMappingController.getJiraProjects';
import getSalesforceFields from '@salesforce/apex/JiraConnectorMappingController.getSalesforceFields';
import getSalesforceObjects from '@salesforce/apex/JiraConnectorMappingController.getSalesforceObjects';
import getWorkspace from '@salesforce/apex/JiraConnectorMappingController.getWorkspace';
import saveMapping from '@salesforce/apex/JiraConnectorMappingController.saveMapping';
import saveProfile from '@salesforce/apex/JiraConnectorMappingController.saveProfile';
import syncFields from '@salesforce/apex/JiraConnectorMappingController.syncFields';

const TRANSFORM_OPTIONS = [
    { label: 'Direct', value: 'Direct' },
    { label: 'Option Id', value: 'Option Id' },
    { label: 'ADF Document', value: 'ADF Document' },
    { label: 'User Mapping', value: 'User Mapping' },
    { label: 'Default Value', value: 'Default Value' }
];

const SOURCE_TYPE_OPTIONS = [
    { label: 'Agentforce field', value: 'Agentforce Field' },
    { label: 'Salesforce field', value: 'Salesforce Field' },
    { label: 'Constant/default', value: 'Constant' },
    { label: 'System context', value: 'System Context' }
];

const DIRECTION_OPTIONS = [
    { label: 'Salesforce to Jira', value: 'Salesforce to Jira' },
    { label: 'Jira to Salesforce', value: 'Jira to Salesforce' },
    { label: 'Bidirectional', value: 'Bidirectional' }
];

export default class JiraConnectorMapping extends LightningElement {
    @track workspace;
    @track draft = {};
    @track profileDraft = {};
    @track projectOptions = [];
    @track issueTypeOptions = [];
    @track salesforceObjectOptions = [];
    @track sourceFieldOptions = [];

    errorMessage = '';
    fieldSearch = '';
    isLoading = false;
    isSaving = false;
    isSavingProfile = false;
    selectedCanonicalKey = 'summary';
    selectedConnectorKey = '';

    transformOptions = TRANSFORM_OPTIONS;
    sourceTypeOptions = SOURCE_TYPE_OPTIONS;
    directionOptions = DIRECTION_OPTIONS;

    connectedCallback() {
        this.loadWorkspace();
    }

    async loadWorkspace(connectorKey = this.selectedConnectorKey) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            this.workspace = await getWorkspace({ connectorKey });
            this.selectedConnectorKey = this.workspace.connectorKey;
            this.salesforceObjectOptions = this.workspace.salesforceObjectOptions || [];
            this.sourceFieldOptions = this.workspace.sourceFieldOptions || [];
            this.ensureSelectedField();
            this.resetProfileDraft();
            this.resetDraftFromSelected();
            this.loadSalesforceObjects();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSync() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const savedWorkspace = await saveProfile({ input: { ...this.profileDraft } });
            this.selectedConnectorKey = savedWorkspace.connectorKey;
            this.workspace = await syncFields({ connectorKey: this.selectedConnectorKey });
            this.selectedConnectorKey = this.workspace.connectorKey;
            this.sourceFieldOptions = this.workspace.sourceFieldOptions || [];
            this.ensureSelectedField();
            this.resetProfileDraft();
            this.resetDraftFromSelected();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave() {
        this.isSaving = true;
        this.errorMessage = '';
        try {
            this.workspace = await saveMapping({
                input: {
                    ...this.draft,
                    connectorKey: this.selectedConnectorKey
                }
            });
            this.resetDraftFromSelected();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    async handleDisable() {
        this.draft = {
            ...this.draft,
            backendFieldKey: '',
            enabled: false,
            useForCreate: false,
            useForLookup: false,
            useInSummary: false,
            allowAgentUpdate: false,
            askUserIfMissing: false
        };
        await this.handleSave();
    }

    handleRefresh() {
        this.loadWorkspace();
    }

    handleProfileSelect(event) {
        this.selectedConnectorKey = event.detail.value;
        this.fieldSearch = '';
        this.loadWorkspace(this.selectedConnectorKey);
    }

    handleProfileDraftChange(event) {
        const { name, type, checked, value } = event.target;
        this.profileDraft = {
            ...this.profileDraft,
            [name]: type === 'checkbox' ? checked : value
        };
    }

    handleNewProfile() {
        const current = this.workspace?.selectedProfile || {};
        this.profileDraft = {
            connectorKey: '',
            name: '',
            namedCredentialApiName: current.namedCredentialApiName || this.workspace?.namedCredentialApiName || '',
            projectId: '',
            projectKey: '',
            projectName: '',
            issueTypeId: '',
            issueTypeName: '',
            browseBaseUrl: current.browseBaseUrl || '',
            openIssueJqlClause: current.openIssueJqlClause || 'statusCategory != Done ORDER BY updated DESC',
            active: true
        };
    }

    async handleSaveProfile() {
        this.isSavingProfile = true;
        this.errorMessage = '';
        try {
            this.workspace = await saveProfile({ input: { ...this.profileDraft } });
            this.selectedConnectorKey = this.workspace.connectorKey;
            this.fieldSearch = '';
            this.sourceFieldOptions = this.workspace.sourceFieldOptions || [];
            this.ensureSelectedField();
            this.resetProfileDraft();
            this.resetDraftFromSelected();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSavingProfile = false;
        }
    }

    handleCanonicalSelect(event) {
        this.selectedCanonicalKey = event.currentTarget.dataset.key;
        this.resetDraftFromSelected();
    }

    handleBackendSelect(event) {
        this.draft = {
            ...this.draft,
            backendFieldKey: event.currentTarget.dataset.key,
            enabled: true
        };
    }

    handleFieldSearch(event) {
        this.fieldSearch = event.target.value;
    }

    handleDraftChange(event) {
        const { name, type, checked, value } = event.target;
        this.draft = {
            ...this.draft,
            [name]: type === 'checkbox' ? checked : value
        };
    }

    async handleLoadJiraProjects() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            this.projectOptions = await getJiraProjects({
                namedCredentialApiName: this.profileDraft.namedCredentialApiName
            });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleProjectChange(event) {
        const projectId = event.detail.value;
        const selectedProject = this.projectOptions.find((option) => option.value === projectId);
        this.profileDraft = {
            ...this.profileDraft,
            projectId,
            projectKey: selectedProject?.description || this.profileDraft.projectKey,
            projectName: selectedProject?.label?.replace(/\s+\([^)]+\)$/, '') || this.profileDraft.projectName,
            issueTypeId: '',
            issueTypeName: ''
        };
        await this.loadIssueTypes();
    }

    async loadIssueTypes() {
        if (!this.profileDraft.projectId) {
            this.issueTypeOptions = [];
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        try {
            this.issueTypeOptions = await getJiraIssueTypes({
                namedCredentialApiName: this.profileDraft.namedCredentialApiName,
                projectId: this.profileDraft.projectId
            });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleIssueTypeChange(event) {
        const issueTypeId = event.detail.value;
        const selectedIssueType = this.issueTypeOptions.find((option) => option.value === issueTypeId);
        this.profileDraft = {
            ...this.profileDraft,
            issueTypeId,
            issueTypeName: selectedIssueType?.label || this.profileDraft.issueTypeName
        };
    }

    async handleSalesforceObjectChange(event) {
        const objectApiName = event.detail.value;
        const selectedObject = this.salesforceObjectOptions.find((option) => option.value === objectApiName);
        this.profileDraft = {
            ...this.profileDraft,
            salesforceObjectApiName: objectApiName,
            salesforceObjectLabel: selectedObject?.label?.replace(/\s+\([^)]+\)$/, '') || ''
        };
        await this.loadSalesforceFields(objectApiName);
    }

    handleSourceFieldChange(event) {
        const fieldApiName = event.detail.value;
        const selectedField = this.sourceFieldOptions.find((option) => option.value === fieldApiName);
        this.draft = {
            ...this.draft,
            sourceType: 'Salesforce Field',
            sourceObjectApiName: this.profileDraft.salesforceObjectApiName,
            sourceFieldApiName: fieldApiName,
            sourceFieldLabel: selectedField?.label?.replace(/\s+\([^)]+\)$/, '') || fieldApiName
        };
    }

    async loadSalesforceObjects() {
        if (this.salesforceObjectOptions.length > 0) {
            return;
        }
        try {
            this.salesforceObjectOptions = await getSalesforceObjects();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    async loadSalesforceFields(objectApiName = this.profileDraft.salesforceObjectApiName) {
        if (!objectApiName) {
            this.sourceFieldOptions = [];
            return;
        }
        try {
            this.sourceFieldOptions = await getSalesforceFields({ objectApiName });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    ensureSelectedField() {
        if (!this.workspace?.canonicalFields?.length) {
            return;
        }
        const hasSelected = this.workspace.canonicalFields.some((field) => field.key === this.selectedCanonicalKey);
        if (!hasSelected) {
            this.selectedCanonicalKey = this.workspace.canonicalFields[0].key;
        }
    }

    resetDraftFromSelected() {
        const mapping = this.selectedMapping;
        if (!mapping) {
            return;
        }
        this.draft = {
            connectorKey: this.selectedConnectorKey,
            canonicalField: mapping.canonicalField,
            backendFieldKey: mapping.backendFieldKey || '',
            enabled: Boolean(mapping.enabled),
            useForCreate: Boolean(mapping.useForCreate),
            useForLookup: Boolean(mapping.useForLookup),
            useInSummary: Boolean(mapping.useInSummary),
            allowAgentUpdate: Boolean(mapping.allowAgentUpdate),
            askUserIfMissing: Boolean(mapping.askUserIfMissing),
            transformType: mapping.transformType || 'Direct',
            defaultValue: mapping.defaultValue || '',
            notes: mapping.notes || '',
            sourceType: mapping.sourceType || 'Agentforce Field',
            sourceObjectApiName: mapping.sourceObjectApiName || this.profileDraft.salesforceObjectApiName || '',
            sourceFieldApiName: mapping.sourceFieldApiName || '',
            sourceFieldLabel: mapping.sourceFieldLabel || '',
            direction: mapping.direction || 'Salesforce to Jira',
            transformConfigJson: mapping.transformConfigJson || ''
        };
    }

    resetProfileDraft() {
        const profile = this.workspace?.selectedProfile;
        if (!profile) {
            return;
        }
        this.profileDraft = {
            connectorKey: profile.connectorKey || '',
            name: profile.name || '',
            namedCredentialApiName: profile.namedCredentialApiName || '',
            projectId: profile.projectId || '',
            projectKey: profile.projectKey || '',
            projectName: profile.projectName || '',
            issueTypeId: profile.issueTypeId || '',
            issueTypeName: profile.issueTypeName || '',
            browseBaseUrl: profile.browseBaseUrl || '',
            openIssueJqlClause: profile.openIssueJqlClause || '',
            active: profile.active !== false,
            salesforceObjectApiName: profile.salesforceObjectApiName || '',
            salesforceObjectLabel: profile.salesforceObjectLabel || '',
            routeKey: profile.routeKey || '',
            activeForAgentforce: profile.activeForAgentforce === true
        };
    }

    get hasWorkspace() {
        return Boolean(this.workspace);
    }

    get showEmptyCatalog() {
        return this.hasWorkspace && this.backendFields.length === 0;
    }

    get healthMessages() {
        return this.workspace?.healthMessages || [];
    }

    get hasHealthMessages() {
        return this.healthMessages.length > 0;
    }

    get profileOptions() {
        return (this.workspace?.profiles || []).map((profile) => ({
            label: `${profile.name} (${profile.projectKey || profile.projectId} / ${profile.issueTypeName || profile.issueTypeId})`,
            value: profile.connectorKey
        }));
    }

    get hasMultipleProfiles() {
        return this.profileOptions.length > 1;
    }

    get hasProjectOptions() {
        return this.projectOptions.length > 0;
    }

    get hasIssueTypeOptions() {
        return this.issueTypeOptions.length > 0;
    }

    get connectorSubtitle() {
        if (!this.workspace) {
            return 'Loading connector state';
        }
        return `${this.workspace.connectorKey} · ${this.workspace.projectName || this.workspace.projectKey || 'Project not set'} · ${
            this.workspace.issueTypeName || this.workspace.issueTypeId || 'Issue type not set'
        }`;
    }

    get lastSyncLabel() {
        if (!this.workspace?.lastSyncAt) {
            return 'Not synced yet';
        }
        return new Intl.DateTimeFormat(undefined, {
            dateStyle: 'medium',
            timeStyle: 'short'
        }).format(new Date(this.workspace.lastSyncAt));
    }

    get canonicalFields() {
        return (this.workspace?.canonicalFields || []).map((field) => {
            const mapping = this.mappingByCanonical.get(field.key);
            const isSelected = field.key === this.selectedCanonicalKey;
            return {
                ...field,
                mappedLabel: mapping?.backendFieldLabel || mapping?.backendFieldKey || 'Unmapped',
                enabled: Boolean(mapping?.enabled),
                cardClass: `contract-card ${isSelected ? 'contract-card_selected' : ''} ${
                    mapping?.enabled ? 'contract-card_mapped' : ''
                }`
            };
        });
    }

    get backendFields() {
        const search = (this.fieldSearch || '').trim().toLowerCase();
        return (this.workspace?.backendFields || [])
            .filter((field) => {
                if (!search) {
                    return true;
                }
                return `${field.label} ${field.fieldKey} ${field.schemaType}`.toLowerCase().includes(search);
            })
            .map((field) => {
                const isSelected = field.fieldKey === this.draft.backendFieldKey;
                return {
                    ...field,
                    rowClass: `backend-row ${isSelected ? 'backend-row_selected' : ''}`,
                    statusClass: `field-status field-status_${(field.status || 'active').toLowerCase().replace(/\s+/g, '-')}`,
                    requiredLabel: field.required ? 'Required' : 'Optional',
                    typeLabel: field.schemaType || 'unknown',
                    operationLabel: field.operations || 'read metadata'
                };
            });
    }

    get selectedCanonical() {
        return (this.workspace?.canonicalFields || []).find((field) => field.key === this.selectedCanonicalKey);
    }

    get selectedMapping() {
        return (this.workspace?.mappings || []).find((mapping) => mapping.canonicalField === this.selectedCanonicalKey);
    }

    get selectedBackendLabel() {
        if (!this.draft.backendFieldKey) {
            return 'No Jira field selected';
        }
        const backendField = (this.workspace?.backendFields || []).find((field) => field.fieldKey === this.draft.backendFieldKey);
        return backendField?.label || this.draft.backendFieldKey;
    }

    get selectedProfileLabel() {
        const profile = this.workspace?.selectedProfile;
        if (!profile) {
            return 'No profile selected';
        }
        return `${profile.name} · ${profile.projectKey || profile.projectId} · ${profile.issueTypeName || profile.issueTypeId}`;
    }

    get payloadPreview() {
        return this.workspace?.payloadPreview || '{}';
    }

    get summaryPreview() {
        return this.workspace?.summaryPreview || '';
    }

    get mappedCount() {
        return (this.workspace?.mappings || []).filter((mapping) => mapping.enabled && mapping.backendFieldKey).length;
    }

    get activeFieldCount() {
        return (this.workspace?.backendFields || []).filter((field) => field.status !== 'Missing').length;
    }

    get newFieldCount() {
        return (this.workspace?.backendFields || []).filter((field) => field.status === 'New').length;
    }

    get requiredGapCount() {
        const mappedBackendKeys = new Set(
            (this.workspace?.mappings || [])
                .filter((mapping) => mapping.enabled && mapping.backendFieldKey)
                .map((mapping) => mapping.backendFieldKey)
        );
        return (this.workspace?.backendFields || []).filter((field) => field.required && !mappedBackendKeys.has(field.fieldKey)).length;
    }

    get mappingByCanonical() {
        const mappings = new Map();
        (this.workspace?.mappings || []).forEach((mapping) => mappings.set(mapping.canonicalField, mapping));
        return mappings;
    }

    get saveDisabled() {
        return this.isSaving || !this.draft.canonicalField;
    }

    get saveProfileDisabled() {
        return (
            this.isSavingProfile ||
            !this.profileDraft.name ||
            !this.profileDraft.namedCredentialApiName ||
            !this.profileDraft.projectId ||
            !this.profileDraft.issueTypeId
        );
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (Array.isArray(error?.body?.pageErrors) && error.body.pageErrors.length > 0) {
            return error.body.pageErrors.map((entry) => entry.message).join(', ');
        }
        if (Array.isArray(error?.body?.output?.errors) && error.body.output.errors.length > 0) {
            return error.body.output.errors.map((entry) => entry.message).join(', ');
        }
        if (Array.isArray(error?.body?.output?.fieldErrors)) {
            return error.body.output.fieldErrors.map((entry) => entry.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unexpected connector error.';
    }
}
