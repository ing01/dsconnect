<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import Input from 'dashboard/components-next/input/Input.vue';
import ContactCompaniesField from 'dashboard/components-next/Contacts/ContactCompaniesField.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';

const props = defineProps({
  contactData: {
    type: Object,
    default: null,
  },
  isDetailsView: {
    type: Boolean,
    default: false,
  },
  isNewContact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const { currentAccount, isCloudFeatureEnabled } = useAccount();

const FORM_CONFIG = {
  NAME: { field: 'name' },
  EMAIL_ADDRESS: { field: 'email' },
  PHONE_NUMBER: { field: 'phoneNumber' },
  COMPANY_NAME: { field: 'additionalAttributes.companyName' },
};

const defaultState = {
  id: 0,
  name: '',
  email: '',
  companyIds: [],
  phoneNumber: '',
  additionalAttributes: {
    description: '',
    companyName: '',
    countryCode: '',
    country: '',
    city: '',
  },
};

const state = reactive({ ...defaultState });
// Display-only ({id, name} pairs) for the company chips - `state.companyIds`
// is the id-only field that actually gets sent to the API.
const selectedCompanies = ref([]);

// Sobrenome, pais, cidade e biografia nao sao mais editados na tela, mas seguem
// no state (vindos do contato) para nao serem apagados ao salvar.
const validationRules = {
  name: { required },
  email: { email },
};

const v$ = useVuelidate(validationRules, state);

const isFormInvalid = computed(() => v$.value.$invalid);
const hasCompaniesFeature = computed(
  () =>
    currentAccount.value?.id && isCloudFeatureEnabled(FEATURE_FLAGS.COMPANIES)
);
const showCompanyField = computed(
  () =>
    hasCompaniesFeature.value &&
    (selectedCompanies.value.length > 0 ||
      !state.additionalAttributes.companyName)
);

const emitContactUpdate = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('update', state);
};

const prepareStateBasedOnProps = () => {
  if (props.isNewContact) {
    return; // Added to prevent state update for new contact form
  }

  const {
    id,
    name = '',
    email: emailAddress,
    phoneNumber,
    companies = [],
    additionalAttributes = {},
  } = props.contactData || {};
  const {
    description = '',
    companyName = '',
    countryCode = '',
    country = '',
    city = '',
  } = additionalAttributes || {};

  selectedCompanies.value = companies || [];
  Object.assign(state, {
    id,
    name,
    companyIds: (companies || []).map(company => Number(company.id)),
    email: emailAddress,
    phoneNumber,
    additionalAttributes: {
      description,
      companyName,
      countryCode,
      country,
      city,
    },
  });
};

const editDetailsForm = computed(() =>
  Object.keys(FORM_CONFIG).map(key => ({
    key,
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
  }))
);

const isValidationField = key => {
  const field = FORM_CONFIG[key]?.field;
  return ['name', 'email'].includes(field);
};

const getValidationKey = key => {
  return FORM_CONFIG[key]?.field;
};

// Creates a computed property for two-way form field binding
const getFormBinding = key => {
  const field = FORM_CONFIG[key]?.field;
  if (!field) return null;

  return computed({
    get: () => {
      // Handle nested vs non-nested fields
      const [base, nested] = field.split('.');
      // Example: 'email' → state.email
      // Example: 'additionalAttributes.city' → state.additionalAttributes.city
      return (nested ? state[base][nested] : state[base])?.toString() || '';
    },

    set: async value => {
      // Handle nested vs non-nested fields
      const [base, nested] = field.split('.');
      if (nested) {
        state[base][nested] = value;
      } else {
        // Example: email = "test@example.com"
        state[base] = value;
      }

      await emitContactUpdate();
    },
  });
};

const getMessageType = key => {
  return isValidationField(key) && v$.value[getValidationKey(key)]?.$error
    ? 'error'
    : 'info';
};

const handleCompaniesUpdate = async companies => {
  selectedCompanies.value = companies;
  state.companyIds = companies.map(company => Number(company.id));
  await emitContactUpdate();
};

const resetValidation = () => {
  v$.value.$reset();
};

const resetForm = () => {
  Object.assign(state, defaultState);
  selectedCompanies.value = [];
};

watch(
  () => props.contactData?.id,
  id => {
    if (id) prepareStateBasedOnProps();
  },
  { immediate: true }
);

// Expose state to parent component for avatar upload
defineExpose({
  state,
  resetValidation,
  isFormInvalid,
  resetForm,
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE') }}
      </span>
      <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
        <template v-for="item in editDetailsForm" :key="item.key">
          <PhoneNumberInput
            v-if="item.key === 'PHONE_NUMBER'"
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :show-border="isDetailsView"
          />
          <ContactCompaniesField
            v-else-if="item.key === 'COMPANY_NAME' && showCompanyField"
            :model-value="selectedCompanies"
            @update:model-value="handleCompaniesUpdate"
          />
          <Input
            v-else
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :message-type="getMessageType(item.key)"
            :custom-input-class="`h-8 !pt-1 !pb-1 ${
              !isDetailsView
                ? '[&:not(.error,.focus)]:!outline-transparent'
                : ''
            }`"
            class="w-full"
            @input="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
            @blur="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
          />
        </template>
      </div>
    </div>
  </div>
</template>
