<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CompanyModulesField from 'dashboard/components-next/Companies/CompanyDetail/CompanyModulesField.vue';
import CompanyCategoryField from 'dashboard/components-next/Companies/CompanyDetail/CompanyCategoryField.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';

const props = defineProps({
  company: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
});

const { t } = useI18n();
const companiesStore = useCompaniesStore();

const FISCAL_FIELDS = [
  'legalName',
  'cnpj',
  'ie',
  'im',
  'addressZipCode',
  'addressStreet',
  'addressNumber',
  'addressComplement',
  'addressNeighborhood',
  'addressCity',
  'addressState',
];

const CLIENT_LEVEL_OPTIONS = [1, 2, 3, 4, 5].map(level => ({
  value: level,
  label: t(`COMPANIES.DETAIL.PROFILE.LEVEL.L${level}`),
}));

const form = reactive({
  name: '',
  domain: '',
  description: '',
  legalName: '',
  cnpj: '',
  ie: '',
  im: '',
  addressZipCode: '',
  addressStreet: '',
  addressNumber: '',
  addressComplement: '',
  addressNeighborhood: '',
  addressCity: '',
  addressState: '',
  clientLevel: 1,
  companyCategoryId: 0,
  campaignOptIn: false,
  systemModuleIds: [],
});
const avatarPreviewUrl = ref('');
const isUploadingAvatar = ref(false);
const cnpjLookupState = ref('idle'); // idle | success | error
const cnpjLookupErrorMessage = ref('');

const uiFlags = computed(() => companiesStore.getUIFlags);
const isUpdating = computed(() => uiFlags.value.updatingItem);
const isAvatarBusy = computed(
  () =>
    isUploadingAvatar.value || uiFlags.value.deletingAvatar || isUpdating.value
);

const displayName = computed(
  () => props.company?.name || t('COMPANIES.UNNAMED')
);
const avatarSource = computed(
  () => avatarPreviewUrl.value || props.company?.avatarUrl || ''
);
const isFormInvalid = computed(() => !form.name.trim());
const companyModuleIds = computed(() =>
  (props.company?.systemModules || []).map(m => m.id)
);
const sameModuleSelection = computed(() => {
  const current = [...form.systemModuleIds].map(Number).sort();
  const original = [...companyModuleIds.value].sort();
  return (
    current.length === original.length &&
    current.every((id, index) => id === original[index])
  );
});
const hasChanges = computed(
  () =>
    form.name.trim() !== (props.company?.name || '').trim() ||
    form.domain.trim() !== (props.company?.domain || '').trim() ||
    form.description.trim() !== (props.company?.description || '').trim() ||
    FISCAL_FIELDS.some(
      field => (form[field] || '').trim() !== (props.company?.[field] || '')
    ) ||
    form.clientLevel !== Number(props.company?.clientLevel || 1) ||
    (form.companyCategoryId || 0) !==
      (props.company?.companyCategoryId || 0) ||
    form.campaignOptIn !== Boolean(props.company?.campaignOptIn) ||
    !sameModuleSelection.value
);
const isLookingUpCnpj = computed(() => uiFlags.value.lookingUpCnpj);

const summary = computed(() => {
  const { createdAt, lastActivityAt } = props.company || {};
  return [
    createdAt &&
      t('COMPANIES.DETAIL.PROFILE.CREATED_AT', {
        date: dynamicTime(createdAt),
      }),
    lastActivityAt &&
      t('COMPANIES.DETAIL.PROFILE.LAST_ACTIVE', {
        date: dynamicTime(lastActivityAt),
      }),
  ]
    .filter(Boolean)
    .join(' • ');
});

const syncForm = company => {
  form.name = company?.name || '';
  form.domain = company?.domain || '';
  form.description = company?.description || '';
  FISCAL_FIELDS.forEach(field => {
    form[field] = company?.[field] || '';
  });
  form.clientLevel = Number(company?.clientLevel || 1);
  form.companyCategoryId = company?.companyCategoryId || 0;
  form.campaignOptIn = Boolean(company?.campaignOptIn);
  form.systemModuleIds = (company?.systemModules || []).map(m => m.id);
  cnpjLookupState.value = 'idle';
  cnpjLookupErrorMessage.value = '';
};

const isCurrentCompany = companyId => Number(props.company?.id) === companyId;

watch(
  () => [
    props.company?.id,
    props.company?.name,
    props.company?.domain,
    props.company?.description,
    props.company?.avatarUrl,
    ...FISCAL_FIELDS.map(field => props.company?.[field]),
    props.company?.clientLevel,
    props.company?.companyCategoryId,
    props.company?.campaignOptIn,
    JSON.stringify(props.company?.systemModules || []),
  ],
  () => {
    avatarPreviewUrl.value = '';
    syncForm(props.company);
  },
  { immediate: true }
);

const handleAvatarUpload = async ({ file, url }) => {
  avatarPreviewUrl.value = url;
  isUploadingAvatar.value = true;
  try {
    await companiesStore.update({ id: props.company.id, avatar: file });
    useAlert(t('COMPANIES.DETAIL.AVATAR.UPLOAD_SUCCESS'));
  } catch {
    avatarPreviewUrl.value = '';
    useAlert(t('COMPANIES.DETAIL.AVATAR.UPLOAD_ERROR'));
  } finally {
    isUploadingAvatar.value = false;
  }
};

const handleAvatarDelete = async () => {
  try {
    await companiesStore.deleteCompanyAvatar(props.company.id);
    avatarPreviewUrl.value = '';
    useAlert(t('COMPANIES.DETAIL.AVATAR.DELETE_SUCCESS'));
  } catch {
    useAlert(t('COMPANIES.DETAIL.AVATAR.DELETE_ERROR'));
  }
};

const handleUpdateCompany = async () => {
  const companyId = Number(props.company.id);

  try {
    const updated = await companiesStore.update({
      id: companyId,
      name: form.name.trim(),
      domain: form.domain.trim() || null,
      description: form.description.trim() || null,
      ...FISCAL_FIELDS.reduce((attrs, field) => {
        attrs[field] = form[field].trim() || null;
        return attrs;
      }, {}),
      clientLevel: form.clientLevel,
      companyCategoryId: form.companyCategoryId || null,
      campaignOptIn: form.campaignOptIn,
      systemModuleIds: form.systemModuleIds,
    });
    if (!isCurrentCompany(companyId)) return;

    syncForm(updated);
    useAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_SUCCESS'));
  } catch {
    if (!isCurrentCompany(companyId)) return;

    syncForm(props.company);
    useAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_ERROR'));
  }
};

const handleCnpjLookup = async () => {
  const digitsOnly = form.cnpj.replace(/\D/g, '');
  if (digitsOnly.length !== 14) return;

  try {
    const data = await companiesStore.lookupCnpj(digitsOnly);
    form.cnpj = data.cnpj;
    form.legalName = data.legalName || form.legalName;
    if (!form.name.trim()) form.name = data.name || '';
    form.addressZipCode = data.addressZipCode || form.addressZipCode;
    form.addressStreet = data.addressStreet || form.addressStreet;
    form.addressNumber = data.addressNumber || form.addressNumber;
    form.addressComplement = data.addressComplement || form.addressComplement;
    form.addressNeighborhood =
      data.addressNeighborhood || form.addressNeighborhood;
    form.addressCity = data.addressCity || form.addressCity;
    form.addressState = data.addressState || form.addressState;
    cnpjLookupState.value = 'success';
  } catch (error) {
    cnpjLookupErrorMessage.value =
      error.message || t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.ERROR');
    cnpjLookupState.value = 'error';
  }
};

const debouncedCnpjLookup = debounce(handleCnpjLookup, 400);

watch(
  () => form.cnpj,
  value => {
    if (value.replace(/\D/g, '').length === 14) debouncedCnpjLookup();
  }
);
</script>

<template>
  <div v-if="isLoading && !company?.id" class="text-sm text-n-slate-11">
    {{ t('COMPANIES.DETAIL.LOADING') }}
  </div>

  <div v-else-if="company?.id" class="flex flex-col items-start gap-8 pb-6">
    <div class="flex flex-col items-start gap-3">
      <Avatar
        :name="displayName"
        :src="avatarSource"
        :size="72"
        :allow-upload="!isAvatarBusy"
        hide-offline-status
        @upload="handleAvatarUpload"
        @delete="handleAvatarDelete"
      />

      <div class="flex flex-col gap-1">
        <h3 class="text-base font-medium text-n-slate-12">
          {{ displayName }}
        </h3>
        <span class="text-sm leading-6 text-n-slate-11">{{ summary }}</span>
        <p
          v-if="isUploadingAvatar || uiFlags.deletingAvatar"
          class="text-sm text-n-slate-11"
        >
          {{ t('COMPANIES.DETAIL.AVATAR.UPDATING') }}
        </p>
      </div>
    </div>

    <div class="flex flex-col items-start w-full gap-6">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('COMPANIES.DETAIL.PROFILE.TITLE') }}
      </span>

      <div class="grid w-full gap-4 sm:grid-cols-2">
        <Input
          v-model="form.name"
          :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')"
          :disabled="isUpdating"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
        <Input
          v-model="form.domain"
          :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')"
          :disabled="isUpdating"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
      </div>

      <div class="flex flex-col items-start w-full gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.DETAIL.PROFILE.SECTIONS.FISCAL') }}
        </span>
        <div class="grid w-full gap-4 sm:grid-cols-2">
          <div class="flex items-end gap-1">
            <Input
              v-model="form.cnpj"
              :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.CNPJ')"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
              class="flex-1"
            />
            <Button
              :label="t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.BUTTON')"
              size="sm"
              variant="faded"
              color="slate"
              :is-loading="isLookingUpCnpj"
              :disabled="isUpdating || form.cnpj.replace(/\D/g, '').length !== 14"
              @click="handleCnpjLookup"
            />
          </div>
          <Input
            v-model="form.legalName"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.LEGAL_NAME')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.ie"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.IE')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.im"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.IM')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
        </div>
        <p
          v-if="cnpjLookupState === 'success'"
          class="text-xs text-n-teal-11"
        >
          {{ t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.SUCCESS') }}
        </p>
        <p v-else-if="cnpjLookupState === 'error'" class="text-xs text-n-ruby-11">
          {{ cnpjLookupErrorMessage }}
        </p>
      </div>

      <div class="flex flex-col items-start w-full gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.DETAIL.PROFILE.SECTIONS.CLASSIFICATION') }}
        </span>
        <div class="grid w-full gap-4 sm:grid-cols-2">
          <div class="flex flex-col gap-1">
            <label class="flex items-center gap-1 text-sm text-n-slate-11">
              {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.CLIENT_LEVEL') }}
              <span
                v-tooltip="t('COMPANIES.DETAIL.PROFILE.LEVEL.HELP')"
                class="cursor-help i-lucide-circle-help size-3.5 text-n-slate-10"
              />
            </label>
            <Select
              v-model="form.clientLevel"
              :options="CLIENT_LEVEL_OPTIONS"
              :disabled="isUpdating"
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-sm text-n-slate-11">
              {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.CATEGORY') }}
            </label>
            <CompanyCategoryField
              v-model="form.companyCategoryId"
              :disabled="isUpdating"
            />
          </div>
        </div>
        <div class="flex items-center gap-2">
          <input
            id="campaign-opt-in"
            v-model="form.campaignOptIn"
            type="checkbox"
            :disabled="isUpdating"
          />
          <label for="campaign-opt-in" class="text-sm text-n-slate-11">
            {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.CAMPAIGN_OPT_IN') }}
          </label>
        </div>
        <div class="flex flex-col w-full gap-1">
          <label class="text-sm text-n-slate-11">
            {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.MODULES') }}
          </label>
          <CompanyModulesField
            v-model="form.systemModuleIds"
            :disabled="isUpdating"
          />
        </div>
      </div>

      <div class="flex flex-col items-start w-full gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.DETAIL.PROFILE.SECTIONS.ADDRESS') }}
        </span>
        <div class="grid w-full gap-4 sm:grid-cols-2">
          <Input
            v-model="form.addressZipCode"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_ZIP_CODE')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressStreet"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_STREET')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressNumber"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_NUMBER')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressComplement"
            :label="
              t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_COMPLEMENT')
            "
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressNeighborhood"
            :label="
              t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_NEIGHBORHOOD')
            "
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressCity"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_CITY')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressState"
            :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_STATE')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
        </div>
      </div>

      <TextArea
        v-model="form.description"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')"
        :disabled="isUpdating"
        :max-length="280"
        class="w-full"
        show-character-count
        auto-height
      />

      <Button
        :label="t('COMPANIES.DETAIL.PROFILE.ACTIONS.SAVE')"
        size="sm"
        :is-loading="isUpdating"
        :disabled="isUpdating || isFormInvalid || !hasChanges"
        @click="handleUpdateCompany"
      />
    </div>
  </div>
</template>
