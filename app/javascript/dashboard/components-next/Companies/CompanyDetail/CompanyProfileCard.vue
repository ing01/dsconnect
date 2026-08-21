<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
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
});
const avatarPreviewUrl = ref('');
const isUploadingAvatar = ref(false);
const cnpjLookupState = ref('idle'); // idle | success | error

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
const hasChanges = computed(
  () =>
    form.name.trim() !== (props.company?.name || '').trim() ||
    form.domain.trim() !== (props.company?.domain || '').trim() ||
    form.description.trim() !== (props.company?.description || '').trim() ||
    FISCAL_FIELDS.some(
      field => (form[field] || '').trim() !== (props.company?.[field] || '')
    )
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
  cnpjLookupState.value = 'idle';
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
  } catch {
    cnpjLookupState.value = 'error';
  }
};
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
              :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.CNPJ')"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
              class="flex-1"
              @blur="handleCnpjLookup"
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
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.LEGAL_NAME')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.ie"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.IE')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.im"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.IM')"
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
          {{ t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.ERROR') }}
        </p>
      </div>

      <div class="flex flex-col items-start w-full gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.DETAIL.PROFILE.SECTIONS.ADDRESS') }}
        </span>
        <div class="grid w-full gap-4 sm:grid-cols-2">
          <Input
            v-model="form.addressZipCode"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_ZIP_CODE')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressStreet"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_STREET')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressNumber"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_NUMBER')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressComplement"
            :placeholder="
              t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_COMPLEMENT')
            "
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressNeighborhood"
            :placeholder="
              t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_NEIGHBORHOOD')
            "
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressCity"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_CITY')"
            :disabled="isUpdating"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="form.addressState"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS_STATE')"
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
