<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';

const props = defineProps({
  company: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
});

const { t } = useI18n();
const companiesStore = useCompaniesStore();

const TEXT_FIELDS = ['billingType', 'licenseExpiresOn', 'systemStartedOn'];
const NUMERIC_FIELDS = ['billingAmount', 'implementationFee'];

const BILLING_TYPE_OPTIONS = [
  { value: 'monthly', label: t('COMPANIES.DETAIL.PROFILE.BILLING.MONTHLY') },
  { value: 'annual', label: t('COMPANIES.DETAIL.PROFILE.BILLING.ANNUAL') },
];

const form = reactive({
  billingType: '',
  billingAmount: '',
  implementationFee: '',
  licenseExpiresOn: '',
  systemStartedOn: '',
});

const uiFlags = computed(() => companiesStore.getUIFlags);
const isUpdating = computed(() => uiFlags.value.updatingItem);

const hasChanges = computed(
  () =>
    TEXT_FIELDS.some(
      field => (form[field] || '') !== (props.company?.[field] || '')
    ) ||
    NUMERIC_FIELDS.some(
      field =>
        (Number(form[field]) || null) !==
        (Number(props.company?.[field]) || null)
    )
);

const monthlyEquivalent = computed(() => {
  const amount = Number(form.billingAmount);
  if (form.billingType !== 'annual' || !amount) return '';
  return (amount / 12).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  });
});

const isCurrentCompany = companyId => Number(props.company?.id) === companyId;

const syncForm = company => {
  [...TEXT_FIELDS, ...NUMERIC_FIELDS].forEach(field => {
    form[field] = company?.[field] || '';
  });
};

watch(
  () => [
    props.company?.id,
    ...TEXT_FIELDS.map(field => props.company?.[field]),
    ...NUMERIC_FIELDS.map(field => props.company?.[field]),
  ],
  () => syncForm(props.company),
  { immediate: true }
);

const handleUpdateCompany = async () => {
  const companyId = Number(props.company.id);

  try {
    const updated = await companiesStore.update({
      id: companyId,
      billingType: form.billingType || null,
      licenseExpiresOn: form.licenseExpiresOn || null,
      systemStartedOn: form.systemStartedOn || null,
      billingAmount: form.billingAmount !== '' ? Number(form.billingAmount) : null,
      implementationFee:
        form.implementationFee !== '' ? Number(form.implementationFee) : null,
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
</script>

<template>
  <div v-if="isLoading && !company?.id" class="text-sm text-n-slate-11">
    {{ t('COMPANIES.DETAIL.LOADING') }}
  </div>

  <div v-else-if="company?.id" class="flex flex-col items-start w-full gap-4">
    <span class="text-sm font-medium text-n-slate-12">
      {{ t('COMPANIES.DETAIL.PROFILE.SECTIONS.CONTRACT') }}
    </span>
    <div class="grid w-full gap-4 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <label class="text-sm text-n-slate-11">
          {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.BILLING_TYPE') }}
        </label>
        <Select
          v-model="form.billingType"
          :options="BILLING_TYPE_OPTIONS"
          :disabled="isUpdating"
        />
      </div>
      <div class="flex flex-col gap-1">
        <Input
          v-model="form.billingAmount"
          type="number"
          :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.BILLING_AMOUNT')"
          :disabled="isUpdating"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
        <span v-if="monthlyEquivalent" class="text-xs text-n-slate-11">
          {{
            t('COMPANIES.DETAIL.PROFILE.BILLING.MONTHLY_EQUIVALENT', {
              amount: monthlyEquivalent,
            })
          }}
        </span>
      </div>
      <Input
        v-model="form.implementationFee"
        type="number"
        :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.IMPLEMENTATION_FEE')"
        :disabled="isUpdating"
        custom-input-class="h-8 !pt-1 !pb-1"
      />
      <Input
        v-model="form.licenseExpiresOn"
        type="date"
        :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.LICENSE_EXPIRES_ON')"
        :disabled="isUpdating"
        custom-input-class="h-8 !pt-1 !pb-1"
      />
      <Input
        v-model="form.systemStartedOn"
        type="date"
        :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.SYSTEM_STARTED_ON')"
        :disabled="isUpdating"
        custom-input-class="h-8 !pt-1 !pb-1"
      />
    </div>

    <Button
      :label="t('COMPANIES.DETAIL.PROFILE.ACTIONS.SAVE')"
      size="sm"
      :is-loading="isUpdating"
      :disabled="isUpdating || !hasChanges"
      @click="handleUpdateCompany"
    />
  </div>
</template>
