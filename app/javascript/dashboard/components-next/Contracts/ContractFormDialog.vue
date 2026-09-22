<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ContractResponsibleField from 'dashboard/components-next/Contracts/ContractResponsibleField.vue';
import ContractCompaniesField from 'dashboard/components-next/Contracts/ContractCompaniesField.vue';
import { useProductGroupsStore } from 'dashboard/stores/productGroups';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const productGroupsStore = useProductGroupsStore();
const dialogRef = ref(null);
const editingId = ref(null);
const newGroupName = ref('');

const CONTRACT_TYPE_OPTIONS = [
  { value: 'monthly', label: t('CONTRACTS.FORM.CONTRACT_TYPE.MONTHLY') },
  { value: 'annual', label: t('CONTRACTS.FORM.CONTRACT_TYPE.ANNUAL') },
];

const productGroups = computed(() => productGroupsStore.getProductGroups);

const emptyLine = () => ({
  id: null,
  productGroupId: '',
  unitValue: '',
  licensesQty: 1,
  implementationFee: '',
});

const form = reactive({
  responsibleContactId: '',
  responsibleName: '',
  contractType: '',
  companies: [],
  lines: [emptyLine()],
  totalValueMode: 'auto',
  totalValue: '',
});

// IDs de linhas ja salvas que o usuario removeu durante a edicao - precisam
// ir no payload como `_destroy: true` (nested attributes do Rails), senao a
// linha so some da tela mas continua no banco entrando na soma do total.
const removedLineIds = ref([]);

// `licensesQty` e' so informativo - nao entra na conta do valor total
// (confirmado com a Ingrid: quantidade de licencas nunca influencia o valor).
const computedTotal = computed(() =>
  form.lines.reduce((total, line) => {
    const unit = Number(line.unitValue) || 0;
    const fee = Number(line.implementationFee) || 0;
    return total + unit + fee;
  }, 0)
);

const isEditing = computed(() => Boolean(editingId.value));
const isFormInvalid = computed(
  () =>
    !form.contractType ||
    !form.companies.length ||
    form.lines.some(line => !line.productGroupId || !line.unitValue)
);

const resetForm = () => {
  editingId.value = null;
  form.responsibleContactId = '';
  form.responsibleName = '';
  form.contractType = '';
  form.companies = [];
  form.lines = [emptyLine()];
  form.totalValueMode = 'auto';
  form.totalValue = '';
  newGroupName.value = '';
  removedLineIds.value = [];
};

const open = (contract = null) => {
  productGroupsStore.get();
  if (contract) {
    editingId.value = contract.id;
    form.responsibleContactId = contract.responsibleContactId || '';
    form.responsibleName = contract.responsibleContact?.name || '';
    form.contractType = contract.contractType || '';
    form.companies = contract.companies || [];
    form.lines = contract.contractProductGroups?.length
      ? contract.contractProductGroups.map(line => ({
          id: line.id,
          productGroupId: line.productGroupId,
          unitValue: line.unitValue,
          licensesQty: line.licensesQty,
          implementationFee: line.implementationFee || '',
        }))
      : [emptyLine()];
    form.totalValueMode = contract.totalValueMode || 'auto';
    form.totalValue = contract.totalValue || '';
    removedLineIds.value = [];
  } else {
    resetForm();
  }
  dialogRef.value?.open();
};

const handleResponsibleSelect = contact => {
  form.responsibleName = contact?.name || '';
};

const addLine = () => form.lines.push(emptyLine());
const removeLine = index => {
  if (form.lines.length === 1) return;
  const [removed] = form.lines.splice(index, 1);
  if (removed?.id) removedLineIds.value.push(removed.id);
};

// Pre-preenche o valor da linha com o valor do Grupo de Produtos escolhido -
// o usuario ainda pode editar `line.unitValue` livremente depois (fica
// guardado por linha, nao amarrado ao grupo pra sempre).
const handleGroupSelect = line => {
  const group = productGroups.value.find(
    candidate => candidate.id === Number(line.productGroupId)
  );
  if (group) line.unitValue = group.computedValue;
};

const handleCreateGroup = async () => {
  const name = newGroupName.value.trim();
  if (!name) return;
  try {
    await productGroupsStore.create({ name });
    newGroupName.value = '';
  } catch {
    useAlert(t('PRODUCT_GROUPS.MESSAGES.CREATE_ERROR'));
  }
};

const handleConfirm = () => {
  if (isFormInvalid.value) return;

  emit('submit', {
    id: editingId.value,
    responsibleContactId: form.responsibleContactId || null,
    contractType: form.contractType,
    companyIds: form.companies.map(company => Number(company.id)),
    totalValueMode: form.totalValueMode,
    totalValue: form.totalValueMode === 'manual' ? form.totalValue : null,
    contractProductGroupsAttributes: [
      ...form.lines.map(line => ({
        id: line.id || undefined,
        productGroupId: line.productGroupId,
        unitValue: line.unitValue,
        licensesQty: line.licensesQty,
        implementationFee: line.implementationFee || null,
      })),
      ...removedLineIds.value.map(id => ({ id, _destroy: true })),
    ],
  });
};

const closeDialog = () => dialogRef.value?.close();
const onSuccess = () => {
  resetForm();
  closeDialog();
};

defineExpose({ dialogRef, onSuccess, open });
</script>

<template>
  <Dialog ref="dialogRef" width="3xl" overflow-y-auto @confirm="handleConfirm" @close="resetForm">
    <div class="flex flex-col gap-6">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ isEditing ? t('CONTRACTS.FORM.EDIT_TITLE') : t('CONTRACTS.FORM.CREATE_TITLE') }}
      </span>

      <div class="grid w-full gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-slate-12">{{ t('CONTRACTS.FORM.RESPONSIBLE.LABEL') }}</label>
          <ContractResponsibleField
            v-model="form.responsibleContactId"
            :responsible-name="form.responsibleName"
            :disabled="isLoading"
            @select="handleResponsibleSelect"
          />
        </div>
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-slate-12">{{ t('CONTRACTS.FORM.CONTRACT_TYPE.LABEL') }}</label>
          <Select v-model="form.contractType" :options="CONTRACT_TYPE_OPTIONS" :disabled="isLoading" />
        </div>
      </div>

      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">{{ t('CONTRACTS.FORM.COMPANIES.LABEL') }}</label>
        <ContractCompaniesField v-model="form.companies" :disabled="isLoading" />
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">{{ t('CONTRACTS.FORM.PRODUCTS.LABEL') }}</label>
          <div class="flex items-center gap-2">
            <input
              v-model="newGroupName"
              type="text"
              :placeholder="t('CONTRACTS.FORM.PRODUCTS.NEW_PLACEHOLDER')"
              class="h-9 px-3 text-sm rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 focus:border-n-brand focus:outline-none w-64"
              @keyup.enter="handleCreateGroup"
            />
            <Button
              :label="t('CONTRACTS.FORM.PRODUCTS.NEW_BUTTON')"
              size="sm"
              variant="faded"
              slate
              class="flex-shrink-0 whitespace-nowrap"
              :disabled="!newGroupName.trim()"
              @click="handleCreateGroup"
            />
          </div>
        </div>

        <div
          v-for="(line, index) in form.lines"
          :key="index"
          class="grid grid-cols-[1.4fr_1fr_0.8fr_1fr_auto] gap-3 items-end p-3 rounded-lg border border-n-weak bg-n-alpha-1"
        >
          <div class="flex flex-col gap-1.5">
            <span class="text-xs font-medium text-n-slate-11">{{ t('CONTRACTS.FORM.PRODUCTS.PRODUCT') }}</span>
            <select
              v-model="line.productGroupId"
              class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
              @change="handleGroupSelect(line)"
            >
              <option value="" disabled>{{ t('CONTRACTS.FORM.PRODUCTS.SELECT_PLACEHOLDER') }}</option>
              <option v-for="group in productGroups" :key="group.id" :value="group.id">{{ group.name }}</option>
            </select>
          </div>
          <div class="flex flex-col gap-1.5">
            <span class="text-xs font-medium text-n-slate-11">{{ t('CONTRACTS.FORM.PRODUCTS.UNIT_VALUE') }}</span>
            <Input v-model="line.unitValue" type="number" custom-input-class="h-9 text-sm" />
          </div>
          <div class="flex flex-col gap-1.5">
            <span
              class="text-xs font-medium text-n-slate-11"
              :title="t('CONTRACTS.FORM.PRODUCTS.LICENSES_QTY_HELP')"
            >
              {{ t('CONTRACTS.FORM.PRODUCTS.LICENSES_QTY') }}
            </span>
            <Input v-model="line.licensesQty" type="number" custom-input-class="h-9 text-sm" />
          </div>
          <div class="flex flex-col gap-1.5">
            <span class="text-xs font-medium text-n-slate-11">{{ t('CONTRACTS.FORM.PRODUCTS.IMPLEMENTATION_FEE') }}</span>
            <Input v-model="line.implementationFee" type="number" custom-input-class="h-9 text-sm" />
          </div>
          <Button
            icon="i-lucide-trash-2"
            size="sm"
            variant="ghost"
            ruby
            :disabled="form.lines.length === 1"
            @click="removeLine(index)"
          />
        </div>
        <Button
          :label="t('CONTRACTS.FORM.PRODUCTS.ADD_LINE')"
          size="sm"
          variant="faded"
          slate
          class="self-start"
          @click="addLine"
        />
      </div>

      <div class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak bg-n-alpha-1">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-12">{{ t('CONTRACTS.FORM.TOTAL_VALUE.LABEL') }}</span>
          <label class="flex items-center gap-1 text-xs text-n-slate-11">
            <input
              type="checkbox"
              :checked="form.totalValueMode === 'manual'"
              @change="form.totalValueMode = $event.target.checked ? 'manual' : 'auto'"
            />
            {{ t('CONTRACTS.FORM.TOTAL_VALUE.MANUAL_TOGGLE') }}
          </label>
        </div>
        <Input
          v-if="form.totalValueMode === 'manual'"
          v-model="form.totalValue"
          type="number"
          custom-input-class="h-9 text-sm"
        />
        <span v-else class="text-lg font-semibold text-n-slate-12">
          {{ computedTotal.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }) }}
        </span>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="link"
          type="reset"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click="closeDialog"
        />
        <Button
          :label="t('CONTRACTS.FORM.SAVE')"
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
