<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import ContractAPI from 'dashboard/api/contracts';
import { useCompaniesStore } from 'dashboard/stores/companies';

const props = defineProps({
  company: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
});

const { t } = useI18n();
const companiesStore = useCompaniesStore();

// `billingType`/`billingAmount` vem do Contrato vinculado (disabled por
// padrao, so editaveis via o botao de lapis de cada um - ver `unlockedFields`
// abaixo). `implementationFee` continua livre, nao ha equivalente no
// Contrato pra ele hoje.
const TEXT_FIELDS = ['billingType', 'systemStartedOn'];
const NUMERIC_FIELDS = ['billingAmount', 'implementationFee'];

const BILLING_TYPE_OPTIONS = [
  { value: 'monthly', label: t('COMPANIES.DETAIL.PROFILE.BILLING.MONTHLY') },
  { value: 'annual', label: t('COMPANIES.DETAIL.PROFILE.BILLING.ANNUAL') },
];

const form = reactive({
  billingType: '',
  billingAmount: '',
  implementationFee: '',
  systemStartedOn: '',
});

const unlockedFields = reactive({ billingType: false, billingAmount: false });
const isPickingContract = ref(false);
const contractOptions = ref([]);

const uiFlags = computed(() => companiesStore.getUIFlags);
const isUpdating = computed(() => uiFlags.value.updatingItem);
// `projects_count` vem do serializer - com Projeto, a data vem sozinha de la
// (`Project#sync_system_started_on_to_company`); sem nenhum, continua
// editavel a mao (clientes sem Projeto, ver Company#system_started_on).
const hasProjects = computed(() => Number(props.company?.projectsCount || 0) > 0);

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

const contractLabel = computed(() => {
  const contract = props.company?.contract;
  if (!contract) return t('COMPANIES.DETAIL.PROFILE.CONTRACT.NONE');

  const companyNames = (contract.companyNames || []).join(', ');
  return companyNames || t('COMPANIES.DETAIL.PROFILE.CONTRACT.UNNAMED');
});

const isCurrentCompany = companyId => Number(props.company?.id) === companyId;

const syncForm = company => {
  [...TEXT_FIELDS, ...NUMERIC_FIELDS].forEach(field => {
    form[field] = company?.[field] || '';
  });
  unlockedFields.billingType = false;
  unlockedFields.billingAmount = false;
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

const fetchContracts = async query => {
  try {
    const {
      data: { payload },
    } = await ContractAPI.search(query || '');
    contractOptions.value = (payload || []).map(contract => ({
      value: contract.id,
      label:
        (contract.companies || []).map(c => c.name).join(', ') ||
        t('COMPANIES.DETAIL.PROFILE.CONTRACT.UNNAMED'),
    }));
  } catch {
    contractOptions.value = [];
  }
};

const openContractPicker = () => {
  isPickingContract.value = true;
  fetchContracts('');
};
const closeContractPicker = () => {
  isPickingContract.value = false;
};
const handleContractSearch = useDebounceFn(
  query => fetchContracts(query?.trim() || ''),
  300
);

const handleContractSelect = async value => {
  const companyId = Number(props.company.id);
  try {
    const updated = await companiesStore.update({
      id: companyId,
      contractId: Number(value),
    });
    if (isCurrentCompany(companyId)) syncForm(updated);
    useAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_ERROR'));
  } finally {
    closeContractPicker();
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

    <div class="flex flex-col w-full gap-1">
      <label class="text-sm text-n-slate-11">
        {{ t('COMPANIES.DETAIL.PROFILE.CONTRACT.LABEL') }}
      </label>
      <div v-if="!isPickingContract" class="flex items-center gap-2">
        <span class="text-sm text-n-slate-12">{{ contractLabel }}</span>
        <Button
          :label="
            company.contract
              ? t('COMPANIES.DETAIL.PROFILE.CONTRACT.CHANGE')
              : t('COMPANIES.DETAIL.PROFILE.CONTRACT.SELECT')
          "
          size="sm"
          variant="faded"
          slate
          @click="openContractPicker"
        />
      </div>
      <div v-else class="flex items-center gap-2">
        <ComboBox
          :options="contractOptions"
          :placeholder="t('COMPANIES.DETAIL.PROFILE.CONTRACT.SEARCH_PLACEHOLDER')"
          :search-placeholder="t('COMPANIES.DETAIL.PROFILE.CONTRACT.SEARCH_PLACEHOLDER')"
          use-api-results
          class="w-full max-w-xs [&>div>button]:h-8"
          @open="openContractPicker"
          @search="handleContractSearch"
          @update:model-value="handleContractSelect"
        />
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          size="sm"
          variant="link"
          slate
          @click="closeContractPicker"
        />
      </div>
    </div>

    <div class="grid w-full gap-4 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <label class="text-sm text-n-slate-11">
            {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.BILLING_TYPE') }}
          </label>
          <Button
            v-if="!unlockedFields.billingType"
            icon="i-lucide-pencil"
            size="xs"
            variant="ghost"
            slate
            @click="unlockedFields.billingType = true"
          />
        </div>
        <Select
          v-model="form.billingType"
          :options="BILLING_TYPE_OPTIONS"
          :disabled="isUpdating || !unlockedFields.billingType"
        />
      </div>
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <label class="text-sm text-n-slate-11">
            {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.BILLING_AMOUNT') }}
          </label>
          <Button
            v-if="!unlockedFields.billingAmount"
            icon="i-lucide-pencil"
            size="xs"
            variant="ghost"
            slate
            @click="unlockedFields.billingAmount = true"
          />
        </div>
        <Input
          v-model="form.billingAmount"
          type="number"
          :disabled="isUpdating || !unlockedFields.billingAmount"
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
      <div class="flex flex-col gap-1">
        <Input
          v-model="form.systemStartedOn"
          type="date"
          :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.SYSTEM_STARTED_ON')"
          :disabled="isUpdating || hasProjects"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
        <span v-if="hasProjects" class="text-xs text-n-slate-11">
          {{ t('COMPANIES.DETAIL.PROFILE.FIELDS.SYSTEM_STARTED_ON_FROM_PROJECT') }}
        </span>
      </div>
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
