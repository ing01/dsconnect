<script setup>
/**
 * Cadastro de clientes/leads do Comercial - acesso restrito via permissao
 * `commercial_manage` (ver crm.routes.js e Crm::ClientPolicy no backend).
 * De proposito SEPARADO de Companies: nem todo lead vira cliente pagante.
 */
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CrmClientsAPI from 'dashboard/api/crmClients';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { BRAZIL_STATES, fetchCitiesByUf } from '../brazilLocations';
import { formatBrPhone } from '../crmPhoneMask';

const { t } = useI18n();

// Mesma tipografia do label do componente `Input` - usado nos poucos campos
// que aqui sao <select> em vez de <Input>, pra letra nao ficar diferente.
const FIELD_LABEL_CLASS = 'flex flex-col gap-1 text-heading-3 text-n-slate-12';
const SELECT_CLASS =
  'h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none';

// UF -> lista de cidades (API do IBGE) - cache compartilhado pelos 3
// contextos de UF/Cidade desta tela (cliente, representante no cadastro e
// representante na troca), pra nao buscar a mesma UF tres vezes.
const citiesByUf = ref({});
const ensureCities = async uf => {
  if (!uf || citiesByUf.value[uf]) return;
  citiesByUf.value[uf] = await fetchCitiesByUf(uf);
};

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
  representative_mobile: '',
  representative_address_street: '',
  representative_address_number: '',
  representative_address_complement: '',
  representative_neighborhood: '',
  representative_city: '',
  representative_state: '',
  representative_zip_code: '',
  extra_representatives: [],
});
const form = ref(emptyForm());
const showContractData = ref(false);

watch(() => form.value.state, ensureCities);
watch(() => form.value.representative_state, ensureCities);

// Celular/telefone do representante com mascara - formata enquanto digita e
// ja corta no tamanho certo, pra nao deixar passar numero maior/menor nem
// digitado errado.
const representativePhoneMasked = computed({
  get: () => form.value.representative_phone,
  set: value => {
    form.value.representative_phone = formatBrPhone(value, { mobile: false });
  },
});
const representativeMobileMasked = computed({
  get: () => form.value.representative_mobile,
  set: value => {
    form.value.representative_mobile = formatBrPhone(value, { mobile: true });
  },
});

const addExtraRepresentative = () => {
  form.value.extra_representatives.push({
    name: '',
    cpf: '',
    birth_date: '',
    phone: '',
    address: '',
  });
};

const removeExtraRepresentative = index => {
  form.value.extra_representatives.splice(index, 1);
};

const fetchClients = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmClientsAPI.get({
      search: searchQuery.value || undefined,
    });
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

// "Mudanca de representante" - um painel PROPRIO, separado do form de
// edicao geral: so' os dados do representante NOVO, em branco (nunca
// pre-preenchido com o antigo, pra nao editar por engano em vez de
// substituir). Ao salvar, o servidor atualiza o cliente E regenera todos os
// contratos ja gerados para ele (ver Crm::Contracts::RegenerationService).
const emptyRepresentativeForm = () => ({
  representative_name: '',
  representative_cpf: '',
  representative_birth_date: '',
  representative_phone: '',
  representative_mobile: '',
  representative_address_street: '',
  representative_address_number: '',
  representative_address_complement: '',
  representative_neighborhood: '',
  representative_city: '',
  representative_state: '',
  representative_zip_code: '',
});
const representativeChangeClient = ref(null);
const representativeForm = ref(emptyRepresentativeForm());
const isChangingRepresentative = ref(false);

watch(() => representativeForm.value.representative_state, ensureCities);

const repChangePhoneMasked = computed({
  get: () => representativeForm.value.representative_phone,
  set: value => {
    representativeForm.value.representative_phone = formatBrPhone(value, {
      mobile: false,
    });
  },
});
const repChangeMobileMasked = computed({
  get: () => representativeForm.value.representative_mobile,
  set: value => {
    representativeForm.value.representative_mobile = formatBrPhone(value, {
      mobile: true,
    });
  },
});

const openChangeRepresentative = client => {
  representativeChangeClient.value = client;
  representativeForm.value = emptyRepresentativeForm();
};

const closeChangeRepresentative = () => {
  representativeChangeClient.value = null;
};

const saveRepresentativeChange = async () => {
  isChangingRepresentative.value = true;
  try {
    const { data } = await CrmClientsAPI.changeRepresentative(
      representativeChangeClient.value.id,
      representativeForm.value
    );
    const total = data.results.length;
    const ok = data.results.filter(result => result.status === 'ok').length;
    const failed = data.results.filter(result => result.status === 'error');

    useAlert(t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.SUCCESS', { ok, total }));
    if (failed.length) {
      useAlert(
        t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.PARTIAL_ERROR', {
          errors: failed.map(result => result.error).join('; '),
        })
      );
    }
    closeChangeRepresentative();
    fetchClients();
  } catch {
    useAlert(t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.ERROR'));
  } finally {
    isChangingRepresentative.value = false;
  }
};

onMounted(fetchClients);
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <ReportHeader :header-title="t('CRM.CLIENTS.HEADER')" />
    <p class="mb-4 text-sm text-n-slate-11">
      {{ t('CRM.CLIENTS.DESCRIPTION') }}
    </p>

    <div class="flex items-center justify-between gap-3 mb-4">
      <Input
        v-model="searchQuery"
        :placeholder="t('CRM.CLIENTS.SEARCH')"
        class="max-w-xs"
        @keyup.enter="fetchClients"
      />
      <Button
        :label="t('CRM.CLIENTS.NEW')"
        icon="i-lucide-plus"
        @click="openNew"
      />
    </div>

    <div
      v-if="isFormOpen"
      class="flex flex-col gap-3 p-4 mb-4 rounded-xl border border-n-weak bg-n-solid-2"
    >
      <div class="grid grid-cols-2 gap-3">
        <Input v-model="form.name" :label="t('CRM.CLIENTS.FIELDS.NAME')" />
        <Input v-model="form.cnpj" :label="t('CRM.CLIENTS.FIELDS.CNPJ')" />
        <Input
          v-model="form.contact_name"
          :label="t('CRM.CLIENTS.FIELDS.CONTACT_NAME')"
        />
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
        {{ t('CRM.CLIENTS.CONTRACT_DATA_SECTION') }}
        {{ showContractData ? '▲' : '▼' }}
      </button>

      <div v-if="showContractData" class="grid grid-cols-3 gap-3">
        <Input
          v-model="form.trade_name"
          :label="t('CRM.CLIENTS.FIELDS.TRADE_NAME')"
          size="sm"
        />
        <Input
          v-model="form.state_registration"
          :label="t('CRM.CLIENTS.FIELDS.STATE_REGISTRATION')"
          size="sm"
        />
        <Input
          v-model="form.address_street"
          :label="t('CRM.CLIENTS.FIELDS.ADDRESS_STREET')"
          size="sm"
        />
        <div class="w-24">
          <Input
            v-model="form.address_number"
            :label="t('CRM.CLIENTS.FIELDS.ADDRESS_NUMBER')"
            size="sm"
          />
        </div>
        <Input
          v-model="form.address_complement"
          :label="t('CRM.CLIENTS.FIELDS.ADDRESS_COMPLEMENT')"
          size="sm"
        />
        <Input
          v-model="form.address_neighborhood"
          :label="t('CRM.CLIENTS.FIELDS.ADDRESS_NEIGHBORHOOD')"
          size="sm"
        />
        <div class="sm:col-span-2 flex gap-3">
          <div class="w-24">
            <label :class="FIELD_LABEL_CLASS">
              {{ t('CRM.CLIENTS.FIELDS.STATE') }}
              <select v-model="form.state" :class="SELECT_CLASS">
                <option value="">-</option>
                <option
                  v-for="estado in BRAZIL_STATES"
                  :key="estado.uf"
                  :value="estado.uf"
                >
                  {{ estado.uf }}
                </option>
              </select>
            </label>
          </div>
          <div class="flex-1 min-w-0">
            <Input
              v-model="form.city"
              :label="t('CRM.CLIENTS.FIELDS.CITY')"
              size="sm"
              list="crm-client-cities"
            />
          </div>
        </div>
        <div class="w-28">
          <Input
            v-model="form.zip_code"
            :label="t('CRM.CLIENTS.FIELDS.ZIP_CODE')"
            size="sm"
          />
        </div>
        <Input
          v-model="form.representative_name"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_NAME')"
          size="sm"
        />
        <Input
          v-model="form.representative_cpf"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_CPF')"
          size="sm"
        />
        <Input
          v-model="form.representative_birth_date"
          type="date"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_BIRTH_DATE')"
          size="sm"
        />
        <div class="w-32">
          <Input
            v-model="representativePhoneMasked"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_PHONE')"
            size="sm"
          />
        </div>
        <div class="w-32">
          <Input
            v-model="representativeMobileMasked"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_MOBILE')"
            size="sm"
          />
        </div>
        <Input
          v-model="form.representative_address_street"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_STREET')"
          size="sm"
        />
        <div class="w-24">
          <Input
            v-model="form.representative_address_number"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_NUMBER')"
            size="sm"
          />
        </div>
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
        <div class="sm:col-span-2 flex gap-3">
          <div class="w-24">
            <label :class="FIELD_LABEL_CLASS">
              {{ t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_STATE') }}
              <select v-model="form.representative_state" :class="SELECT_CLASS">
                <option value="">-</option>
                <option
                  v-for="estado in BRAZIL_STATES"
                  :key="estado.uf"
                  :value="estado.uf"
                >
                  {{ estado.uf }}
                </option>
              </select>
            </label>
          </div>
          <div class="flex-1 min-w-0">
            <Input
              v-model="form.representative_city"
              :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_CITY')"
              size="sm"
              list="crm-representative-cities"
            />
          </div>
        </div>
        <div class="w-28">
          <Input
            v-model="form.representative_zip_code"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ZIP_CODE')"
            size="sm"
          />
        </div>
      </div>

      <datalist id="crm-client-cities">
        <option
          v-for="cidade in citiesByUf[form.state] || []"
          :key="cidade"
          :value="cidade"
        />
      </datalist>
      <datalist id="crm-representative-cities">
        <option
          v-for="cidade in citiesByUf[form.representative_state] || []"
          :key="cidade"
          :value="cidade"
        />
      </datalist>

      <div v-if="showContractData" class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-11">{{
            t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.TITLE')
          }}</span>
          <button class="text-xs text-n-brand" @click="addExtraRepresentative">
            {{ t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.ADD') }}
          </button>
        </div>
        <p class="text-[11px] text-n-slate-11">
          {{ t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.HINT') }}
        </p>
        <div
          v-for="(representative, index) in form.extra_representatives"
          :key="index"
          class="grid grid-cols-[2fr_1fr_1fr_1fr_2fr_auto] gap-2 items-end"
        >
          <Input
            v-model="representative.name"
            :label="t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.NAME')"
            size="sm"
          />
          <Input
            v-model="representative.cpf"
            :label="t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.CPF')"
            size="sm"
          />
          <Input
            v-model="representative.birth_date"
            type="date"
            :label="t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.BIRTH_DATE')"
            size="sm"
          />
          <Input
            v-model="representative.phone"
            :label="t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.PHONE')"
            size="sm"
          />
          <Input
            v-model="representative.address"
            :label="t('CRM.CLIENTS.EXTRA_REPRESENTATIVES.ADDRESS')"
            size="sm"
          />
          <button
            class="mb-1 text-n-ruby-9"
            @click="removeExtraRepresentative(index)"
          >
            <i class="i-lucide-trash-2 size-4" />
          </button>
        </div>
      </div>

      <div class="flex gap-2 justify-end">
        <Button
          variant="faded"
          color="slate"
          :label="t('CRM.CLIENTS.FORM.CANCEL')"
          @click="closeForm"
        />
        <Button
          :label="t('CRM.CLIENTS.FORM.SAVE')"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </div>

    <div
      v-if="representativeChangeClient"
      class="flex flex-col gap-3 p-4 mb-4 rounded-xl border border-n-amber-6 bg-n-amber-2"
    >
      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.TITLE', {
              client: representativeChangeClient.name,
            })
          }}
        </span>
        <p class="text-xs text-n-slate-11">
          {{ t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.HINT') }}
        </p>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <Input
          v-model="representativeForm.representative_name"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_NAME')"
          size="sm"
        />
        <Input
          v-model="representativeForm.representative_cpf"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_CPF')"
          size="sm"
        />
        <Input
          v-model="representativeForm.representative_birth_date"
          type="date"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_BIRTH_DATE')"
          size="sm"
        />
        <div class="w-32">
          <Input
            v-model="repChangePhoneMasked"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_PHONE')"
            size="sm"
          />
        </div>
        <div class="w-32">
          <Input
            v-model="repChangeMobileMasked"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_MOBILE')"
            size="sm"
          />
        </div>
        <Input
          v-model="representativeForm.representative_address_street"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_STREET')"
          size="sm"
        />
        <div class="w-24">
          <Input
            v-model="representativeForm.representative_address_number"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_NUMBER')"
            size="sm"
          />
        </div>
        <Input
          v-model="representativeForm.representative_address_complement"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ADDRESS_COMPLEMENT')"
          size="sm"
        />
        <Input
          v-model="representativeForm.representative_neighborhood"
          :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_NEIGHBORHOOD')"
          size="sm"
        />
        <div class="sm:col-span-2 flex gap-3">
          <div class="w-24">
            <label :class="FIELD_LABEL_CLASS">
              {{ t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_STATE') }}
              <select
                v-model="representativeForm.representative_state"
                :class="SELECT_CLASS"
              >
                <option value="">-</option>
                <option
                  v-for="estado in BRAZIL_STATES"
                  :key="estado.uf"
                  :value="estado.uf"
                >
                  {{ estado.uf }}
                </option>
              </select>
            </label>
          </div>
          <div class="flex-1 min-w-0">
            <Input
              v-model="representativeForm.representative_city"
              :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_CITY')"
              size="sm"
              list="crm-repchange-cities"
            />
          </div>
        </div>
        <div class="w-28">
          <Input
            v-model="representativeForm.representative_zip_code"
            :label="t('CRM.CLIENTS.FIELDS.REPRESENTATIVE_ZIP_CODE')"
            size="sm"
          />
        </div>
      </div>

      <datalist id="crm-repchange-cities">
        <option
          v-for="cidade in citiesByUf[representativeForm.representative_state] || []"
          :key="cidade"
          :value="cidade"
        />
      </datalist>

      <div class="flex gap-2 justify-end">
        <Button
          variant="faded"
          color="slate"
          :label="t('CRM.CLIENTS.FORM.CANCEL')"
          @click="closeChangeRepresentative"
        />
        <Button
          color="amber"
          :label="t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.SUBMIT')"
          :is-loading="isChangingRepresentative"
          @click="saveRepresentativeChange"
        />
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
        <tr
          v-for="client in clients"
          :key="client.id"
          class="border-b border-n-weak"
        >
          <td class="py-2 font-medium text-n-slate-12">{{ client.name }}</td>
          <td class="py-2">{{ client.cnpj }}</td>
          <td class="py-2">{{ client.contact_name }}</td>
          <td class="py-2">{{ client.phone }}</td>
          <td class="py-2">
            <button class="mr-3 text-n-brand" @click="openEdit(client)">
              <i class="i-lucide-pencil size-4" />
            </button>
            <button
              class="mr-3 text-n-slate-11"
              :title="t('CRM.CLIENTS.REPRESENTATIVE_CHANGE.BUTTON')"
              @click="openChangeRepresentative(client)"
            >
              <i class="i-lucide-user-cog size-4" />
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
