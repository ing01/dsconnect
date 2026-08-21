<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['create']);

const { t } = useI18n();
const companiesStore = useCompaniesStore();
const dialogRef = ref(null);
const cnpjLookupState = ref('idle'); // idle | success | error

const form = reactive({
  name: '',
  domain: '',
  description: '',
  cnpj: '',
  legalName: '',
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

const uiFlags = computed(() => companiesStore.getUIFlags);
const isLookingUpCnpj = computed(() => uiFlags.value.lookingUpCnpj);
const isFormInvalid = computed(() => !form.name.trim());

const resetForm = () => {
  form.name = '';
  form.domain = '';
  form.description = '';
  form.cnpj = '';
  form.legalName = '';
  form.ie = '';
  form.im = '';
  form.addressZipCode = '';
  form.addressStreet = '';
  form.addressNumber = '';
  form.addressComplement = '';
  form.addressNeighborhood = '';
  form.addressCity = '';
  form.addressState = '';
  cnpjLookupState.value = 'idle';
};

const open = (company = {}) => {
  form.name = company.name || '';
  form.domain = company.domain || '';
  form.description = company.description || '';
  dialogRef.value?.open();
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

const debouncedCnpjLookup = debounce(handleCnpjLookup, 400);

watch(
  () => form.cnpj,
  value => {
    if (value.replace(/\D/g, '').length === 14) debouncedCnpjLookup();
  }
);

const handleConfirm = () => {
  if (isFormInvalid.value) return;

  emit('create', {
    name: form.name.trim(),
    domain: form.domain.trim() || null,
    description: form.description.trim() || null,
    cnpj: form.cnpj.trim() || null,
    legalName: form.legalName.trim() || null,
    ie: form.ie.trim() || null,
    im: form.im.trim() || null,
    addressZipCode: form.addressZipCode.trim() || null,
    addressStreet: form.addressStreet.trim() || null,
    addressNumber: form.addressNumber.trim() || null,
    addressComplement: form.addressComplement.trim() || null,
    addressNeighborhood: form.addressNeighborhood.trim() || null,
    addressCity: form.addressCity.trim() || null,
    addressState: form.addressState.trim() || null,
  });
};

const closeDialog = () => {
  dialogRef.value?.close();
};

const onSuccess = () => {
  resetForm();
  closeDialog();
};

defineExpose({ dialogRef, onSuccess, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    overflow-y-auto
    @confirm="handleConfirm"
    @close="resetForm"
  >
    <div class="flex flex-col gap-6">
      <div class="flex flex-col items-start gap-2">
        <span class="py-1 text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.CREATE.TITLE') }}
        </span>
        <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            v-model="form.name"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
            autofocus
          />
          <Input
            v-model="form.domain"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
          />
        </div>
        <div class="flex items-end w-full gap-1">
          <Input
            v-model="form.cnpj"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.CNPJ')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
            class="flex-1"
            @blur="handleCnpjLookup"
          />
          <Button
            :label="t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.BUTTON')"
            size="sm"
            variant="faded"
            color="slate"
            :is-loading="isLookingUpCnpj"
            :disabled="isLoading || form.cnpj.replace(/\D/g, '').length !== 14"
            @click="handleCnpjLookup"
          />
        </div>
        <p v-if="cnpjLookupState === 'success'" class="text-xs text-n-teal-11">
          {{ t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.SUCCESS') }}
        </p>
        <p
          v-else-if="cnpjLookupState === 'error'"
          class="text-xs text-n-ruby-11"
        >
          {{ t('COMPANIES.DETAIL.PROFILE.CNPJ_LOOKUP.ERROR') }}
        </p>
      </div>
      <TextArea
        v-model="form.description"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')"
        :disabled="isLoading"
        :max-length="280"
        class="w-full"
        show-character-count
        auto-height
      />
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
          :label="t('COMPANIES.CREATE.ACTIONS.SAVE')"
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
