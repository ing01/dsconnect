<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';

import Policy from 'dashboard/components/policy.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CompaniesDetailsLayout from 'dashboard/components-next/Companies/CompaniesDetailsLayout.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import CompanyCustomAttributes from 'dashboard/components-next/Companies/CompanyDetail/CompanyCustomAttributes.vue';
import CompanyContactsSidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyContactsSidebar.vue';
import CompanyHistorySidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyHistorySidebar.vue';
import CompanyNotesSidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyNotesSidebar.vue';
import CompanyTicketsSidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyTicketsSidebar.vue';
import CompanyCredentialsSidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyCredentialsSidebar.vue';
import CompanyCredentialFormDialog from 'dashboard/components-next/Companies/CompanyDetail/CompanyCredentialFormDialog.vue';
import ConfirmCredentialDeleteDialog from 'dashboard/components-next/Companies/CompanyDetail/ConfirmCredentialDeleteDialog.vue';
import CompanyProfileCard from 'dashboard/components-next/Companies/CompanyDetail/CompanyProfileCard.vue';
import ConfirmCompanyDeleteDialog from 'dashboard/components-next/Companies/CompanyDetail/ConfirmCompanyDeleteDialog.vue';
import CreateNewContactDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateNewContactDialog.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';
import { usePolicy } from 'dashboard/composables/usePolicy';

const route = useRoute();
const router = useRouter();
const store = useStore();
const companiesStore = useCompaniesStore();
const { t } = useI18n();
const { checkPermissions } = usePolicy();

const canManageCredentials = computed(() =>
  checkPermissions(['administrator', 'client_credentials_manage'])
);

const confirmDeleteDialogRef = ref(null);
const credentialFormDialogRef = ref(null);
const confirmDeleteCredentialDialogRef = ref(null);
const createContactDialogRef = ref(null);
const selectedCandidate = ref(null);
const selectedCredential = ref(null);
const activeTab = ref('profile');

const companyId = computed(() => Number(route.params.companyId));
const company = computed(() => companiesStore.getRecord(companyId.value));
const companyContacts = computed(() => companiesStore.companyContacts);
const companyContactsMeta = computed(() => companiesStore.companyContactsMeta);
const companyConversations = computed(
  () => companiesStore.companyConversations || []
);
const companyNotes = computed(() => companiesStore.companyNotes || []);
const companyTickets = computed(() => companiesStore.companyTickets || []);
const companyCredentials = computed(
  () => companiesStore.companyCredentials || []
);
const contactSearchResults = computed(
  () => companiesStore.contactSearchResults
);
const uiFlags = computed(() => companiesStore.getUIFlags);

const isFetchingCompany = computed(() => uiFlags.value.fetchingItem);
const isFetchingContacts = computed(() => uiFlags.value.fetchingContacts);
const isFetchingConversations = computed(
  () => uiFlags.value.fetchingConversations
);
const isFetchingNotes = computed(() => uiFlags.value.fetchingNotes);
const isFetchingTickets = computed(() => uiFlags.value.fetchingTickets);
const isFetchingCredentials = computed(
  () => uiFlags.value.fetchingCredentials
);
const isSavingCredential = computed(
  () => uiFlags.value.creatingCredential || uiFlags.value.updatingCredential
);
const isDeletingCredential = computed(() => uiFlags.value.deletingCredential);
const isSearchingContacts = computed(() => uiFlags.value.searchingContacts);
const isManagingContacts = computed(
  () => uiFlags.value.creatingContact || uiFlags.value.removingContact
);
const isDeletingCompany = computed(() => uiFlags.value.deletingItem);
const hasCompany = computed(() => Boolean(company.value?.id));
const showInitialLoadingState = computed(
  () =>
    !hasCompany.value && (isFetchingCompany.value || isFetchingContacts.value)
);

const breadcrumbItems = computed(() => [
  { label: t('COMPANIES.HEADER') },
  ...(hasCompany.value
    ? [{ label: company.value?.name || t('COMPANIES.UNNAMED') }]
    : []),
]);

const tabOptions = computed(() => [
  { key: 'PROFILE', value: 'profile' },
  { key: 'ATTRIBUTES', value: 'attributes' },
  { key: 'CONTACTS', value: 'contacts' },
  { key: 'HISTORY', value: 'history' },
  { key: 'NOTES', value: 'notes' },
  { key: 'TICKETS', value: 'tickets' },
  ...(canManageCredentials.value
    ? [{ key: 'CREDENTIALS', value: 'credentials' }]
    : []),
]);

const tabs = computed(() =>
  tabOptions.value.map(tab => ({
    label: {
      profile: t('COMPANIES.DETAIL.SIDEBAR.TABS.PROFILE'),
      attributes: t('COMPANIES.DETAIL.SIDEBAR.TABS.ATTRIBUTES'),
      notes: t('COMPANIES.DETAIL.SIDEBAR.TABS.NOTES'),
      history: t('COMPANIES.DETAIL.SIDEBAR.TABS.HISTORY'),
      contacts: `${t('COMPANIES.DETAIL.SIDEBAR.TABS.CONTACTS')} (${Number(companyContactsMeta.value.totalCount || 0)})`,
      tickets: t('COMPANIES.DETAIL.SIDEBAR.TABS.TICKETS'),
      credentials: t('COMPANIES.DETAIL.SIDEBAR.TABS.CREDENTIALS'),
    }[tab.value],
    value: tab.value,
  }))
);

const activeTabIndex = computed(() =>
  tabOptions.value.findIndex(tab => tab.value === activeTab.value)
);

const goToCompaniesIndex = () => {
  router.push({
    name: 'companies_dashboard_index',
    params: { accountId: route.params.accountId },
    query: { page: '1' },
  });
};

const goToCompaniesList = () => {
  if (window.history.state?.back) {
    router.back();
    return;
  }
  goToCompaniesIndex();
};

const loadCompanyContactsPage = async page => {
  if (!companyId.value) return;
  await companiesStore.getCompanyContacts(companyId.value, page);
};

const openDeleteCompanyDialog = () => {
  confirmDeleteDialogRef.value?.dialogRef.open();
};

const clearSelectedCandidate = () => {
  selectedCandidate.value = null;
};

const loadTabData = tab => {
  if (!companyId.value) return;
  if (tab === 'notes') companiesStore.getCompanyNotes(companyId.value);
  if (tab === 'history') {
    companiesStore.getCompanyConversations(companyId.value);
  }
  if (tab === 'tickets') companiesStore.getCompanyTickets(companyId.value);
  if (tab === 'credentials' && canManageCredentials.value) {
    companiesStore.getCompanyCredentials(companyId.value);
  }
};

const handleTabChange = tab => {
  activeTab.value = tab.value;
  loadTabData(tab.value);
};

const handleContactSearch = async query => {
  await companiesStore.searchCompanyContactCandidates({
    companyId: companyId.value,
    search: query,
  });
};

const handleConfirmContactSelection = async () => {
  const candidate = selectedCandidate.value;
  if (!candidate) return;

  const isReassigning =
    candidate.company?.id && candidate.company.id !== companyId.value;
  const message = isReassigning
    ? t('COMPANIES.DETAIL.CONTACTS.MESSAGES.REASSIGN_SUCCESS')
    : t('COMPANIES.DETAIL.CONTACTS.MESSAGES.ADD_SUCCESS');

  try {
    await companiesStore.attachContactToCompany(companyId.value, candidate.id);
    useAlert(message);
    clearSelectedCandidate();
  } catch {
    const errorMessage = isReassigning
      ? t('COMPANIES.DETAIL.CONTACTS.MESSAGES.REASSIGN_ERROR')
      : t('COMPANIES.DETAIL.CONTACTS.MESSAGES.ADD_ERROR');
    useAlert(errorMessage);
  }
};

const handleRemoveContact = async contactId => {
  const currentPage = Number(companyContactsMeta.value.page || 1);
  const nextPage =
    currentPage > 1 && companyContacts.value.length === 1
      ? currentPage - 1
      : currentPage;

  try {
    await companiesStore.removeContactFromCompany(
      companyId.value,
      contactId,
      nextPage
    );
    useAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.REMOVE_SUCCESS'));
  } catch {
    useAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.REMOVE_ERROR'));
  }
};

const openCreateContactDialog = () => {
  createContactDialogRef.value?.dialogRef.open();
};

const handleCreateContact = async contact => {
  try {
    const created = await store.dispatch('contacts/create', contact);
    createContactDialogRef.value?.onSuccess();
    await companiesStore.attachContactToCompany(companyId.value, created.id);
    useAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.CREATE_SUCCESS'));
  } catch (error) {
    if (error instanceof DuplicateContactException) {
      const i18nPrefix = 'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION';
      if (error.data.includes('email')) {
        useAlert(t(`${i18nPrefix}.EMAIL_ADDRESS_DUPLICATE`));
      } else if (error.data.includes('phone_number')) {
        useAlert(t(`${i18nPrefix}.PHONE_NUMBER_DUPLICATE`));
      }
    } else if (error instanceof ExceptionWithMessage) {
      useAlert(error.data);
    } else {
      useAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.CREATE_ERROR'));
    }
  }
};

const openAddCredentialDialog = () => {
  credentialFormDialogRef.value?.open();
};

const openEditCredentialDialog = credential => {
  credentialFormDialogRef.value?.open(credential);
};

const handleCreateCredential = async payload => {
  try {
    await companiesStore.createCredential(companyId.value, payload);
    useAlert(t('COMPANIES.DETAIL.CREDENTIALS.MESSAGES.CREATE_SUCCESS'));
    credentialFormDialogRef.value?.onSuccess();
  } catch {
    useAlert(t('COMPANIES.DETAIL.CREDENTIALS.MESSAGES.CREATE_ERROR'));
  }
};

const handleUpdateCredential = async ({ id, payload }) => {
  try {
    await companiesStore.updateCredential(companyId.value, id, payload);
    useAlert(t('COMPANIES.DETAIL.CREDENTIALS.MESSAGES.UPDATE_SUCCESS'));
    credentialFormDialogRef.value?.onSuccess();
  } catch {
    useAlert(t('COMPANIES.DETAIL.CREDENTIALS.MESSAGES.UPDATE_ERROR'));
  }
};

const openDeleteCredentialDialog = credential => {
  selectedCredential.value = credential;
  confirmDeleteCredentialDialogRef.value?.dialogRef.open();
};

const handleDeleteCredential = async () => {
  if (!selectedCredential.value) return;

  try {
    await companiesStore.deleteCredential(
      companyId.value,
      selectedCredential.value.id
    );
    useAlert(t('COMPANIES.DETAIL.CREDENTIALS.MESSAGES.DELETE_SUCCESS'));
    confirmDeleteCredentialDialogRef.value?.dialogRef.close();
    selectedCredential.value = null;
  } catch {
    useAlert(t('COMPANIES.DETAIL.CREDENTIALS.MESSAGES.DELETE_ERROR'));
  }
};

const handleDeleteCompany = async () => {
  try {
    await companiesStore.delete(companyId.value);
    useAlert(t('COMPANIES.DETAIL.DELETE.MESSAGES.SUCCESS'));
    confirmDeleteDialogRef.value?.dialogRef.close();
    goToCompaniesIndex();
  } catch {
    useAlert(t('COMPANIES.DETAIL.DELETE.MESSAGES.ERROR'));
  }
};

watch(
  companyId,
  async id => {
    companiesStore.resetCompanyDetailState();
    clearSelectedCandidate();
    activeTab.value = 'profile';
    if (!id) return;
    await Promise.allSettled([
      companiesStore.show(id),
      companiesStore.getCompanyContacts(id),
    ]);
  },
  { immediate: true }
);

onBeforeUnmount(() => {
  companiesStore.resetCompanyDetailState();
});
</script>

<template>
  <CompaniesDetailsLayout
    :breadcrumb-items="breadcrumbItems"
    @back="goToCompaniesList"
  >
    <div
      v-if="showInitialLoadingState"
      class="flex flex-col items-center justify-center gap-3 py-24 text-n-slate-11"
    >
      <Spinner />
      <span class="text-sm">{{ t('COMPANIES.DETAIL.LOADING') }}</span>
    </div>

    <div
      v-else-if="!hasCompany"
      class="flex flex-col items-center justify-center gap-3 px-6 py-24 text-center rounded-2xl border border-n-weak bg-n-solid-2"
    >
      <span class="text-lg font-medium text-n-slate-12">
        {{ t('COMPANIES.DETAIL.EMPTY_STATE.TITLE') }}
      </span>
      <p class="max-w-md text-sm text-n-slate-11">
        {{ t('COMPANIES.DETAIL.EMPTY_STATE.SUBTITLE') }}
      </p>
    </div>

    <div v-else class="flex flex-col gap-6">
      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        @tab-changed="handleTabChange"
      />

      <div v-if="activeTab === 'profile'" class="flex flex-col gap-6">
        <CompanyProfileCard
          :company="company"
          :is-loading="isFetchingCompany"
        />

        <Policy :permissions="['administrator']">
          <section
            class="flex flex-col items-start w-full gap-4 pt-6 border-t border-n-strong"
          >
            <div class="flex flex-col gap-2">
              <h6 class="text-base font-medium text-n-slate-12">
                {{ t('COMPANIES.DETAIL.DELETE.SECTION_TITLE') }}
              </h6>
              <span class="text-sm text-n-slate-11">
                {{ t('COMPANIES.DETAIL.DELETE.SECTION_DESCRIPTION') }}
              </span>
            </div>
            <Button
              :label="t('COMPANIES.DETAIL.DELETE.BUTTON')"
              color="ruby"
              :disabled="isDeletingCompany"
              @click="openDeleteCompanyDialog"
            />
          </section>
        </Policy>
      </div>

      <CompanyCustomAttributes
        v-else-if="activeTab === 'attributes'"
        :company="company"
      />
      <CompanyContactsSidebar
        v-else-if="activeTab === 'contacts'"
        :company="company"
        :contacts="companyContacts"
        :meta="companyContactsMeta"
        :is-loading="isFetchingContacts"
        :is-busy="isManagingContacts"
        :search-results="contactSearchResults"
        :is-searching="isSearchingContacts"
        :selected-contact="selectedCandidate"
        @cancel-contact-selection="clearSelectedCandidate"
        @confirm-contact-selection="handleConfirmContactSelection"
        @create-contact="openCreateContactDialog"
        @search="handleContactSearch"
        @select-contact="contact => (selectedCandidate = contact)"
        @remove-contact="handleRemoveContact"
        @update:current-page="loadCompanyContactsPage"
      />
      <CompanyHistorySidebar
        v-else-if="activeTab === 'history'"
        :conversations="companyConversations"
        :is-loading="isFetchingConversations"
      />
      <CompanyNotesSidebar
        v-else-if="activeTab === 'notes'"
        :notes="companyNotes"
        :is-loading="isFetchingNotes"
      />
      <CompanyTicketsSidebar
        v-else-if="activeTab === 'tickets'"
        :tickets="companyTickets"
        :is-loading="isFetchingTickets"
      />
      <CompanyCredentialsSidebar
        v-else-if="activeTab === 'credentials' && canManageCredentials"
        :credentials="companyCredentials"
        :is-loading="isFetchingCredentials"
        @add="openAddCredentialDialog"
        @edit="openEditCredentialDialog"
        @delete="openDeleteCredentialDialog"
      />
    </div>

    <ConfirmCompanyDeleteDialog
      ref="confirmDeleteDialogRef"
      :company="company"
      :is-loading="isDeletingCompany"
      @confirm="handleDeleteCompany"
    />
    <CreateNewContactDialog
      ref="createContactDialogRef"
      @create="handleCreateContact"
    />
    <CompanyCredentialFormDialog
      v-if="canManageCredentials"
      ref="credentialFormDialogRef"
      :is-loading="isSavingCredential"
      @create="handleCreateCredential"
      @update="handleUpdateCredential"
    />
    <ConfirmCredentialDeleteDialog
      v-if="canManageCredentials"
      ref="confirmDeleteCredentialDialogRef"
      :is-loading="isDeletingCredential"
      @confirm="handleDeleteCredential"
    />
  </CompaniesDetailsLayout>
</template>
