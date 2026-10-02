<script setup>
/**
 * Cadastro de clientes/leads do Comercial - acesso restrito via permissao
 * `commercial_manage` (ver crm.routes.js e Crm::ClientPolicy no backend).
 * De proposito SEPARADO de Companies: nem todo lead vira cliente pagante.
 */
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CrmClientsAPI from 'dashboard/api/crmClients';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();

const isLoading = ref(true);
const clients = ref([]);
const searchQuery = ref('');
const isFormOpen = ref(false);
const editingId = ref(null);
const isSaving = ref(false);

const emptyForm = () => ({
  name: '',
  cnpj: '',
  contact_name: '',
  phone: '',
  email: '',
  notes: '',
  trade_name: '',
  state_registration: '',
  address_street: '',
  address_number: '',
  address_complement: '',
  address_neighborhood: '',
  city: '',
  state: '',
  zip_code: '',
  representative_name: '',
  representative_cpf: '',
  representative_birth_date: '',
  representative_phone: '',
  representative_address_street: '',
  representative_address_number: '',
  representative_address_complement: '',
  representative_neighborhood: '',
  representative_city: '',
  representative_state: '',
  representative_zip_code: '',
});
const form = ref(emptyForm());
const showContractData = ref(false);

const fetchClients = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmClientsAPI.get({ search: searchQuery.value || undefined });
    clients.value = data;
  } catch {
    useAlert(t('CRM.CLIENTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openNew = () => {
  editingId.value = null;
  form.value = emptyForm();
  isFormOpen.value = true;
};

const openEdit = client => {
  editingId.value = client.id;
  form.value = {
    ...emptyForm(),
    ...client,
  };
  isFormOpen.value = true;
};

const closeForm = () => {
  isFormOpen.value = false;
};

const save = async () => {
  isSaving.value = true;
  try {
    if (editingId.value) {
      await CrmClientsAPI.update(editingId.value, { crm_client: form.value });
    } else {
      await CrmClientsAPI.create({ crm_client: form.value });
    }
    isFormOpen.value = false;
    fetchClients();
  } catch {
    useAlert(t('CRM.CLIENTS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const remove = async client => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('CRM.CLIENTS.DELETE_CONFIRM'))) return;
  try {
    await CrmClientsAPI.delete(client.id);
    fetchClients();
  } catch {
    useAlert(t('CRM.CLIENTS.DELETE_ERROR'));
  }
};

onMounted(fetchClients);
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <ReportHeader :header-title="t('CRM.CLIENTS.HEADER')" />
    <p class="mb-4 text-sm text-n-slate-11">{{ t('CRM.CLIENTS.DESCRIPTION') }}</p>

    <div class="flex items-center justify-between gap-3 mb-4">
      <Input
        v-model="searchQuery"
        :placeholder="t('CRM.CLIENTS.SEARCH')"
        class="max-w-xs"
        @keyup.enter="fetchClients"
      />
      <Button :label="t('CRM.CLIENTS.NEW')" icon="i-lucide-plus" @click="openNew" />
    </div>

    <div v-if="isFormOpen" class="flex flex-col gap-3 p-4 mb-4 rounded-xl border border-n-weak bg-n-solid-2">
      <div class="grid grid-cols-2 gap-3">
        <Input v-model="form.name" :label="t('CRM.CLIENTS.FIELDS.NAME')" />
        <Input v-model="form.cnpj" :label="t('CRM.CLIENTS.FIELDS.CNPJ')" />
        <Input v-model="form.contact_name" :label="t('CRM.CLIENTS.FIELDS.CONTACT_NAME')" />
        <Input v-model="form.phone" :label="t('CRM.CLIENTS.FIELDS.PHONE')" />
        <Input v-model="form.email" :label="t('CRM.CLIENTS.FIELDS.EMAIL')" />
      </div>
      <textarea
        v-model="form.notes"
        :placeholder="t('CRM.CLIENTS.FIELDS.NOTES')"
        rows="2"
        class="w-full p-2 text-sm rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12"
      />

      <button
        class="self-start text-xs text-n-brand"
        @click="showContractData = !showContractData"
      >
        {{ t('CRM.CLIENTS.CONTRACT_DATA_SECTION') }} {{ showContractData ? '▲' : '▼' }}
      </button>

      <div v-if="showContractData" class="grid grid-cols-3 gap-3">
        <Input v-model="form.trade_name" :label="t('CRM.CLIENTS.FIELDS.TRADE_NAME')" size="sm" />
        <Input v-model="form.state_registration" :label="t('CRM.CLIENTS.FIELDS.STATE_REGISTRATION')" size="sm" />
        <Input v-model="form.address_street" :label="t('CRM.CLIENTS.FIELDS.ADDRESS_STREET')" size="sm" />
        <Input v-model="form.address_number" :label="t('CRM.CLIENTS.FIELDS.ADDRESS_NUMBER')" size="sm" />
        <Input v-model="form.address_complement" :label="t('CRM.CLIENTS.FIELDS.ADDRESS_COMPLEMENT')" size="sm" />
        <Input v-model="form.address_neighborhood" :label="t('CRM.CLIENTS.FIELDS.ADDRESS_NEIGHBORHOOD')" size="sm" />
        <Input v-model="form.city" :label="t('CRM.CLIENTS.FIELDS.CITY')" size="sm" />
        <Input v-model="form.state" :label="t('CRM.CLIENTS.FIELDS.STATE')" size="sm" />
        <Input v-model="form.zip_code" :label="t('CRM.CLIENTS.FIELDS.ZIP_CODE')" size="sm" />
        <Input v-model="form.representative_name" :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_NAME')" size="sm" />
        <Input v-model="form.representative_cpf" :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_CPF')" size="sm" />
        <Input
          v-model="form.representative_birth_date"
          type="date"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_BIRTH_DATE')"
          size="sm"
        />
        <Input v-model="form.representative_phone" :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_PHONE')" size="sm" />
        <Input
          v-model="form.representative_address_street"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_STREET')"
          size="sm"
        />
        <Input
          v-model="form.representative_address_number"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_NUMBER')"
          size="sm"
        />
        <Input
          v-model="form.representative_address_complement"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_COMPLEMENT')"
          size="sm"
        />
        <Input
          v-model="form.representative_neighborhood"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_NEIGHBORHOOD')"
          size="sm"
        />
        <Input v-model="form.representative_city" :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_CITY')" size="sm" />
        <Input v-model="form.representative_state" :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_STATE')" size="sm" />
        <Input
          v-model="form.representative_zip_code"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ZIP_CODE')"
          size="sm"
        />
      </div>

      <div class="flex gap-2 justify-end">
        <Button variant="faded" color="slate" :label="t('CRM.CLIENTS.FORM.CANCEL')" @click="closeForm" />
        <Button :label="t('CRM.CLIENTS.FORM.SAVE')" :is-loading="isSaving" @click="save" />
      </div>
    </div>

    <p v-if="!isLoading && !clients.length" class="text-sm text-n-slate-11">
      {{ t('CRM.CLIENTS.EMPTY') }}
    </p>

    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-left text-n-slate-11 border-b border-n-weak">
          <th class="py-2">{{ t('CRM.CLIENTS.TABLE.NAME') }}</th>
          <th class="py-2">{{ t('CRM.CLIENTS.TABLE.CNPJ') }}</th>
          <th class="py-2">{{ t('CRM.CLIENTS.TABLE.CONTACT') }}</th>
          <th class="py-2">{{ t('CRM.CLIENTS.TABLE.PHONE') }}</th>
          <th class="py-2">{{ t('CRM.CLIENTS.TABLE.ACTIONS') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="client in clients" :key="client.id" class="border-b border-n-weak">
          <td class="py-2 font-medium text-n-slate-12">{{ client.name }}</td>
          <td class="py-2">{{ client.cnpj }}</td>
          <td class="py-2">{{ client.contact_name }}</td>
          <td class="py-2">{{ client.phone }}</td>
          <td class="py-2">
            <button class="mr-3 text-n-brand" @click="openEdit(client)">
              <i class="i-lucide-pencil size-4" />
            </button>
            <button class="text-n-ruby-9" @click="remove(client)">
              <i class="i-lucide-trash-2 size-4" />
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
