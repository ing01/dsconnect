<script setup>
/**
 * Lancamento de vendas do Comercial - uma venda tem 1+ itens (produto +
 * implantacao + mensalidade); os totais da venda sao sempre a soma dos itens
 * (calculado no backend, ver Crm::Sale#sync_totals_from_items).
 */
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import CrmSalesAPI from 'dashboard/api/crmSales';
import CrmClientsAPI from 'dashboard/api/crmClients';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();
const store = useStore();

const sellers = computed(() => store.getters['agents/getAgents'] || []);

const isLoading = ref(true);
const sales = ref([]);
const clients = ref([]);
const isFormOpen = ref(false);
const editingId = ref(null);
const isSaving = ref(false);

const today = new Date();
const defaultCompetencia = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-01`;

const emptyForm = () => ({
  crm_client_id: '',
  user_id: '',
  competencia: defaultCompetencia,
  payment_method: '',
  installments: 1,
  channel: '',
  items_attributes: [{ product: '', implementation_value: 0, monthly_value: 0 }],
});
const form = ref(emptyForm());

const totalImplementation = computed(() =>
  sales.value.reduce((sum, sale) => sum + Number(sale.implementation_value || 0), 0)
);
const totalMonthly = computed(() =>
  sales.value.reduce((sum, sale) => sum + Number(sale.monthly_value || 0), 0)
);

const fetchClients = async () => {
  try {
    const { data } = await CrmClientsAPI.get();
    clients.value = data;
  } catch {
    // A lista de clientes e' so para o seletor do form - uma falha aqui nao
    // impede ver as vendas ja lancadas.
  }
};

const fetchSales = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmSalesAPI.get();
    sales.value = data;
  } catch {
    useAlert(t('CRM.SALES.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openNew = () => {
  editingId.value = null;
  form.value = emptyForm();
  isFormOpen.value = true;
};

const openEdit = async sale => {
  editingId.value = sale.id;
  form.value = {
    crm_client_id: sale.crm_client_id,
    user_id: sale.user_id,
    competencia: sale.competencia,
    payment_method: sale.payment_method,
    installments: sale.installments,
    channel: sale.channel,
    items_attributes: sale.items.map(item => ({
      id: item.id,
      product: item.product,
      implementation_value: item.implementation_value,
      monthly_value: item.monthly_value,
    })),
  };
  isFormOpen.value = true;
};

const closeForm = () => {
  isFormOpen.value = false;
};

const addItem = () => {
  form.value.items_attributes.push({ product: '', implementation_value: 0, monthly_value: 0 });
};

const removeItem = index => {
  const item = form.value.items_attributes[index];
  if (item.id) {
    // Mantem o id pra mandar `_destroy: true` ao backend em vez de so sumir
    // da tela - senao o item continuaria existindo (e contando no total).
    item._destroy = true;
  } else {
    form.value.items_attributes.splice(index, 1);
  }
};

const visibleItems = computed(() =>
  form.value.items_attributes
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => !item._destroy)
);

const save = async () => {
  isSaving.value = true;
  try {
    const payload = { crm_sale: form.value };
    if (editingId.value) {
      await CrmSalesAPI.update(editingId.value, payload);
    } else {
      await CrmSalesAPI.create(payload);
    }
    isFormOpen.value = false;
    fetchSales();
  } catch {
    useAlert(t('CRM.SALES.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const remove = async sale => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('CRM.SALES.DELETE_CONFIRM'))) return;
  try {
    await CrmSalesAPI.delete(sale.id);
    fetchSales();
  } catch {
    useAlert(t('CRM.SALES.DELETE_ERROR'));
  }
};

onMounted(() => {
  fetchClients();
  fetchSales();
});
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <ReportHeader :header-title="t('CRM.SALES.HEADER')" />
    <p class="mb-4 text-sm text-n-slate-11">{{ t('CRM.SALES.DESCRIPTION') }}</p>

    <div class="flex gap-4 mb-4">
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.SALES.TOTALS.IMPLEMENTATION') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">R$ {{ totalImplementation.toFixed(2) }}</div>
      </div>
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.SALES.TOTALS.MONTHLY') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">R$ {{ totalMonthly.toFixed(2) }}</div>
      </div>
    </div>

    <div class="flex justify-end mb-4">
      <Button :label="t('CRM.SALES.NEW')" icon="i-lucide-plus" @click="openNew" />
    </div>

    <div v-if="isFormOpen" class="flex flex-col gap-3 p-4 mb-4 rounded-xl border border-n-weak bg-n-solid-2">
      <div class="grid grid-cols-3 gap-3">
        <div class="flex flex-col gap-1">
          <label class="text-[11px] font-medium text-n-slate-11">{{ t('CRM.SALES.FIELDS.CLIENT') }}</label>
          <select v-model="form.crm_client_id" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
            <option value="" disabled>-</option>
            <option v-for="client in clients" :key="client.id" :value="client.id">{{ client.name }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[11px] font-medium text-n-slate-11">{{ t('CRM.SALES.FIELDS.COMPETENCIA') }}</label>
          <input v-model="form.competencia" type="date" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[11px] font-medium text-n-slate-11">{{ t('CRM.SALES.FIELDS.SELLER') }}</label>
          <select v-model="form.user_id" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
            <option value="" disabled>-</option>
            <option v-for="seller in sellers" :key="seller.id" :value="seller.id">{{ seller.name }}</option>
          </select>
        </div>
        <Input v-model="form.payment_method" :label="t('CRM.SALES.FIELDS.PAYMENT_METHOD')" />
        <Input v-model.number="form.installments" type="number" :label="t('CRM.SALES.FIELDS.INSTALLMENTS')" />
        <Input v-model="form.channel" :label="t('CRM.SALES.FIELDS.CHANNEL')" />
      </div>

      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-11">{{ t('CRM.SALES.ITEMS.TITLE') }}</span>
          <button class="text-xs text-n-brand" @click="addItem">{{ t('CRM.SALES.ITEMS.ADD') }}</button>
        </div>
        <div v-for="{ item, index } in visibleItems" :key="index" class="grid grid-cols-[2fr_1fr_1fr_auto] gap-2 items-end">
          <Input v-model="item.product" :label="t('CRM.SALES.ITEMS.PRODUCT')" size="sm" />
          <Input v-model.number="item.implementation_value" type="number" :label="t('CRM.SALES.ITEMS.IMPLEMENTATION_VALUE')" size="sm" />
          <Input v-model.number="item.monthly_value" type="number" :label="t('CRM.SALES.ITEMS.MONTHLY_VALUE')" size="sm" />
          <button class="mb-1 text-n-ruby-9" @click="removeItem(index)">
            <i class="i-lucide-trash-2 size-4" />
          </button>
        </div>
      </div>

      <div class="flex gap-2 justify-end">
        <Button variant="faded" color="slate" :label="t('CRM.SALES.FORM.CANCEL')" @click="closeForm" />
        <Button :label="t('CRM.SALES.FORM.SAVE')" :is-loading="isSaving" @click="save" />
      </div>
    </div>

    <p v-if="!isLoading && !sales.length" class="text-sm text-n-slate-11">
      {{ t('CRM.SALES.EMPTY') }}
    </p>

    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-left text-n-slate-11 border-b border-n-weak">
          <th class="py-2">{{ t('CRM.SALES.TABLE.COMPETENCIA') }}</th>
          <th class="py-2">{{ t('CRM.SALES.TABLE.CLIENT') }}</th>
          <th class="py-2">{{ t('CRM.SALES.TABLE.SELLER') }}</th>
          <th class="py-2">{{ t('CRM.SALES.TABLE.IMPLEMENTATION_VALUE') }}</th>
          <th class="py-2">{{ t('CRM.SALES.TABLE.MONTHLY_VALUE') }}</th>
          <th class="py-2">{{ t('CRM.SALES.TABLE.ACTIONS') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="sale in sales" :key="sale.id" class="border-b border-n-weak">
          <td class="py-2">{{ sale.competencia }}</td>
          <td class="py-2 font-medium text-n-slate-12">{{ sale.client_name }}</td>
          <td class="py-2">{{ sale.seller_name }}</td>
          <td class="py-2">R$ {{ Number(sale.implementation_value).toFixed(2) }}</td>
          <td class="py-2">R$ {{ Number(sale.monthly_value).toFixed(2) }}</td>
          <td class="py-2">
            <button class="mr-3 text-n-brand" @click="openEdit(sale)">
              <i class="i-lucide-pencil size-4" />
            </button>
            <button class="text-n-ruby-9" @click="remove(sale)">
              <i class="i-lucide-trash-2 size-4" />
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
