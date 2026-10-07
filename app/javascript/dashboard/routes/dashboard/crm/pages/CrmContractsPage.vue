<script setup>
/**
 * Modelos de contrato (.docx com marcadores `[[token]]`) e geracao de PDF.
 * Os campos do formulario de geracao sao os tokens do modelo escolhido,
 * extraidos automaticamente no upload (ver Crm::Contracts::TokenExtractorService
 * no backend) - nao ha lista de campos fixa aqui, cada modelo define a sua.
 * Campo deixado em branco na geracao usa o que o cadastro do cliente ja sabe
 * (ver Crm::ContractTokenMapper) - so sobrescrevemos quando a pessoa digitou
 * algo.
 */
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CrmContractTemplatesAPI from 'dashboard/api/crmContractTemplates';
import CrmGeneratedContractsAPI from 'dashboard/api/crmGeneratedContracts';
import CrmClientsAPI from 'dashboard/api/crmClients';
import CrmSalesAPI from 'dashboard/api/crmSales';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { CRM_CONTRACT_TOKEN_HELP } from '../crmContractTokenHelp';
import {
  crmContractTokenLabel,
  CRM_DATE_TOKEN_KEYS,
  CRM_LOCKED_CLIENT_TOKEN_KEYS,
  CRM_YES_NO_TOKEN_KEYS,
} from '../crmContractTokenLabels';

const { t } = useI18n();

const SELECT_CLASS =
  'h-9 w-full px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none';
// Mesma tipografia do label do componente `Input` (`text-heading-3
// text-n-slate-12`) - sem isto, os campos com `<select>`/checkbox ficavam
// com letra menor e mais clara que os campos de texto ao lado.
const FIELD_LABEL_CLASS = 'flex flex-col gap-1.5 text-heading-3 text-n-slate-12';
const CARD_CLASS =
  'p-4 sm:p-5 mb-6 rounded-xl border border-n-weak bg-n-solid-2 shadow-sm';
const TABLE_HEAD_CLASS =
  'py-2 px-3 text-left text-xs font-medium text-n-slate-11 whitespace-nowrap';
const TABLE_CELL_CLASS = 'py-2.5 px-3 text-sm align-top';

const tokenHelpDialogRef = ref(null);
const tokenHelpEntries = Object.entries(CRM_CONTRACT_TOKEN_HELP);
const openTokenHelp = () => tokenHelpDialogRef.value?.open();

const templates = ref([]);
const clients = ref([]);
const sales = ref([]);
const contracts = ref([]);
const isLoading = ref(true);

const newTemplateName = ref('');
const newTemplateFile = ref(null);
const isUploading = ref(false);

const selectedTemplateId = ref('');
const selectedClientId = ref('');
const selectedSaleId = ref('');
const tokenValues = ref({});
const isGenerating = ref(false);
const generationError = ref('');

const selectedTemplate = computed(() =>
  templates.value.find(tmpl => tmpl.id === Number(selectedTemplateId.value))
);

const clientSales = computed(() =>
  sales.value.filter(
    sale => sale.crm_client_id === Number(selectedClientId.value)
  )
);

const selectedClientExtraRepresentatives = computed(() => {
  const client = clients.value.find(
    c => c.id === Number(selectedClientId.value)
  );
  return client?.extra_representatives || [];
});

// Os tokens de identidade do cliente (razão social, CNPJ etc.) sempre vêm do
// cadastro - o backend já trava isso (ver Crm::ContractTokenMapper), e por isso
// nem aparecem como campo editável aqui.
const editableTokens = computed(() =>
  (selectedTemplate.value?.tokens || []).filter(
    token => !CRM_LOCKED_CLIENT_TOKEN_KEYS.includes(token)
  )
);

const isYesNoToken = token => CRM_YES_NO_TOKEN_KEYS.includes(token);
const isDateToken = token => CRM_DATE_TOKEN_KEYS.includes(token);

// O seletor de data devolve aaaa-mm-dd; o contrato precisa de dd/mm/aaaa.
const toContractDate = value => {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || '');
  return match ? `${match[3]}/${match[2]}/${match[1]}` : value;
};

const fetchAll = async () => {
  isLoading.value = true;
  try {
    const [templatesRes, clientsRes, salesRes, contractsRes] =
      await Promise.all([
        CrmContractTemplatesAPI.get(),
        CrmClientsAPI.get(),
        CrmSalesAPI.get(),
        CrmGeneratedContractsAPI.get(),
      ]);
    templates.value = templatesRes.data;
    clients.value = clientsRes.data;
    sales.value = salesRes.data;
    contracts.value = contractsRes.data;
  } catch {
    useAlert(t('CRM.CONTRACTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const onFileChange = event => {
  [newTemplateFile.value] = event.target.files;
};

const uploadTemplate = async () => {
  if (!newTemplateName.value || !newTemplateFile.value) return;
  isUploading.value = true;
  try {
    const formData = new FormData();
    formData.append('name', newTemplateName.value);
    formData.append('file', newTemplateFile.value);
    await CrmContractTemplatesAPI.create(formData);
    newTemplateName.value = '';
    newTemplateFile.value = null;
    fetchAll();
  } catch {
    useAlert(t('CRM.CONTRACTS.UPLOAD_ERROR'));
  } finally {
    isUploading.value = false;
  }
};

const removeTemplate = async template => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('CRM.CONTRACTS.DELETE_TEMPLATE_CONFIRM'))) return;
  try {
    await CrmContractTemplatesAPI.delete(template.id);
    fetchAll();
  } catch {
    useAlert(t('CRM.CONTRACTS.DELETE_TEMPLATE_ERROR'));
  }
};

const onSelectTemplate = () => {
  tokenValues.value = {};
  editableTokens.value.forEach(token => {
    // O checkbox nao tem estado "em branco" - sem isto o campo nasceria
    // marcado so' porque `tokenValues[token]` veio vazio (falsy).
    tokenValues.value[token] = isYesNoToken(token) ? 'Não' : '';
  });
};

const toggleYesNo = (token, checked) => {
  tokenValues.value[token] = checked ? 'Sim' : 'Não';
};

const generate = async () => {
  if (!selectedTemplateId.value || !selectedClientId.value) return;
  generationError.value = '';
  isGenerating.value = true;
  try {
    const filledData = Object.fromEntries(
      Object.entries(tokenValues.value)
        .filter(([, value]) => String(value || '').trim() !== '')
        .map(([token, value]) => [
          token,
          isDateToken(token) ? toContractDate(value) : value,
        ])
    );
    await CrmGeneratedContractsAPI.create({
      crm_contract_template_id: selectedTemplateId.value,
      crm_client_id: selectedClientId.value,
      crm_sale_id: selectedSaleId.value || undefined,
      data: filledData,
    });
    fetchAll();
  } catch (error) {
    generationError.value =
      error?.response?.data?.error || t('CRM.CONTRACTS.GENERATE_ERROR');
  } finally {
    isGenerating.value = false;
  }
};

onMounted(fetchAll);
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4 sm:p-6">
    <div
      class="flex flex-wrap items-start justify-between gap-3 mb-1"
    >
      <ReportHeader :header-title="t('CRM.CONTRACTS.HEADER')" />
      <Button
        faded
        slate
        size="sm"
        icon="i-lucide-circle-help"
        :label="t('CRM.CONTRACTS.TOKEN_HELP.BUTTON')"
        @click="openTokenHelp"
      />
    </div>
    <p class="mb-5 text-sm text-n-slate-11 max-w-3xl">
      {{ t('CRM.CONTRACTS.DESCRIPTION') }}
    </p>

    <Dialog
      ref="tokenHelpDialogRef"
      width="2xl"
      overflow-y-auto
      :show-confirm-button="false"
      :cancel-button-label="t('CRM.CONTRACTS.TOKEN_HELP.CLOSE')"
      :title="t('CRM.CONTRACTS.TOKEN_HELP.TITLE')"
      :description="t('CRM.CONTRACTS.TOKEN_HELP.DESCRIPTION')"
    >
      <div class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="text-left text-n-slate-11 border-b border-n-weak">
              <th class="py-2 pr-3">
                {{ t('CRM.CONTRACTS.TOKEN_HELP.TOKEN') }}
              </th>
              <th class="py-2">{{ t('CRM.CONTRACTS.TOKEN_HELP.MEANING') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="[token, meaning] in tokenHelpEntries"
              :key="token"
              class="border-b border-n-weak align-top"
            >
              <td
                class="py-2 pr-3 font-mono whitespace-nowrap text-n-slate-12"
              >
                [[{{ token }}]]
              </td>
              <td class="py-2 text-n-slate-11">{{ meaning }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Dialog>

    <section :class="CARD_CLASS">
      <h3 class="mb-4 text-sm font-semibold text-n-slate-12">
        {{ t('CRM.CONTRACTS.TEMPLATES.TITLE') }}
      </h3>

      <div class="flex flex-col sm:flex-row sm:items-end gap-3 mb-5">
        <div class="w-full sm:max-w-xs">
          <Input
            v-model="newTemplateName"
            :label="t('CRM.CONTRACTS.TEMPLATES.NAME')"
          />
        </div>
        <label
          class="flex-1 min-w-0 text-xs text-n-slate-11 flex flex-col gap-1"
        >
          <span class="font-medium">
            {{ t('CRM.CONTRACTS.TEMPLATES.FILE') }}
          </span>
          <input
            type="file"
            accept=".docx"
            class="block w-full text-xs text-n-slate-12 file:mr-3 file:rounded-lg file:border-0 file:bg-n-alpha-2 file:px-3 file:py-2 file:text-n-slate-12"
            @change="onFileChange"
          />
        </label>
        <Button
          class="w-full sm:w-auto"
          :label="t('CRM.CONTRACTS.TEMPLATES.UPLOAD')"
          :is-loading="isUploading"
          :disabled="!newTemplateName || !newTemplateFile"
          @click="uploadTemplate"
        />
      </div>

      <div v-if="templates.length" class="overflow-x-auto -mx-1">
        <table class="w-full min-w-[420px]">
          <thead class="border-b border-n-weak">
            <tr>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.TEMPLATES.NAME') }}
              </th>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.TEMPLATES.TOKENS') }}
              </th>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.TEMPLATES.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="template in templates"
              :key="template.id"
              class="border-b border-n-weak last:border-0 hover:bg-n-alpha-1"
            >
              <td :class="`${TABLE_CELL_CLASS} font-medium text-n-slate-12`">
                {{ template.name }}
              </td>
              <td :class="`${TABLE_CELL_CLASS} text-n-slate-11`">
                {{ template.tokens.length }}
              </td>
              <td :class="TABLE_CELL_CLASS">
                <button
                  class="p-1 rounded-md text-n-ruby-9 hover:bg-n-ruby-3"
                  :aria-label="t('CRM.CONTRACTS.TEMPLATES.REMOVE')"
                  @click="removeTemplate(template)"
                >
                  <i class="i-lucide-trash-2 size-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="text-sm text-n-slate-11">
        {{ t('CRM.CONTRACTS.TEMPLATES.EMPTY') }}
      </p>
    </section>

    <section :class="CARD_CLASS">
      <h3 class="mb-4 text-sm font-semibold text-n-slate-12">
        {{ t('CRM.CONTRACTS.GENERATE.TITLE') }}
      </h3>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
        <label :class="FIELD_LABEL_CLASS">
          {{ t('CRM.CONTRACTS.GENERATE.TEMPLATE') }}
          <select
            v-model="selectedTemplateId"
            :class="SELECT_CLASS"
            @change="onSelectTemplate"
          >
            <option value="" disabled>-</option>
            <option
              v-for="template in templates"
              :key="template.id"
              :value="template.id"
            >
              {{ template.name }}
            </option>
          </select>
        </label>
        <label :class="FIELD_LABEL_CLASS">
          {{ t('CRM.CONTRACTS.GENERATE.CLIENT') }}
          <select v-model="selectedClientId" :class="SELECT_CLASS">
            <option value="" disabled>-</option>
            <option
              v-for="client in clients"
              :key="client.id"
              :value="client.id"
            >
              {{ client.name }}
            </option>
          </select>
        </label>
        <label :class="FIELD_LABEL_CLASS">
          {{ t('CRM.CONTRACTS.GENERATE.SALE') }}
          <select v-model="selectedSaleId" :class="SELECT_CLASS">
            <option value="">-</option>
            <option v-for="sale in clientSales" :key="sale.id" :value="sale.id">
              {{ sale.competencia }}
            </option>
          </select>
        </label>
      </div>

      <p
        v-if="selectedClientExtraRepresentatives.length"
        class="mb-4 px-3 py-2 rounded-lg bg-n-amber-2 text-xs text-n-amber-11"
      >
        {{
          t('CRM.CONTRACTS.GENERATE.EXTRA_REPRESENTATIVES_HINT', {
            count: selectedClientExtraRepresentatives.length,
          })
        }}
      </p>

      <div v-if="selectedTemplate" class="mb-5">
        <p class="mb-1 text-xs text-n-slate-11">
          {{ t('CRM.CONTRACTS.GENERATE.FIELDS_HINT') }}
        </p>
        <p class="mb-4 text-xs text-n-slate-10">
          {{ t('CRM.CONTRACTS.GENERATE.LOCKED_FIELDS_HINT') }}
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          <div v-for="token in editableTokens" :key="token" class="min-w-0">
            <div v-if="isYesNoToken(token)" class="flex flex-col gap-1.5">
              <span :class="FIELD_LABEL_CLASS">{{
                `${crmContractTokenLabel(token)} (${token})`
              }}</span>
              <label class="flex items-center gap-2 h-9 text-sm text-n-slate-12 cursor-pointer">
                <input
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                  :checked="tokenValues[token] === 'Sim'"
                  @change="toggleYesNo(token, $event.target.checked)"
                />
                {{
                  tokenValues[token] === 'Sim'
                    ? t('CRM.CONTRACTS.GENERATE.YES')
                    : t('CRM.CONTRACTS.GENERATE.NO')
                }}
              </label>
            </div>
            <label
              v-else-if="isDateToken(token)"
              :class="FIELD_LABEL_CLASS"
            >
              {{ `${crmContractTokenLabel(token)} (${token})` }}
              <input
                v-model="tokenValues[token]"
                type="date"
                :class="SELECT_CLASS"
              />
            </label>
            <Input
              v-else
              v-model="tokenValues[token]"
              :label="`${crmContractTokenLabel(token)} (${token})`"
              size="sm"
            />
          </div>
        </div>
      </div>

      <p v-if="generationError" class="mb-3 text-xs text-n-ruby-9">
        {{ generationError }}
      </p>

      <Button
        class="w-full sm:w-auto"
        :label="t('CRM.CONTRACTS.GENERATE.SUBMIT')"
        :is-loading="isGenerating"
        :disabled="!selectedTemplateId || !selectedClientId"
        @click="generate"
      />
    </section>

    <section>
      <h3 class="mb-3 text-sm font-semibold text-n-slate-12">
        {{ t('CRM.CONTRACTS.LIST.TITLE') }}
      </h3>
      <p v-if="!isLoading && !contracts.length" class="text-sm text-n-slate-11">
        {{ t('CRM.CONTRACTS.LIST.EMPTY') }}
      </p>
      <div v-else class="overflow-x-auto rounded-xl border border-n-weak">
        <table class="w-full min-w-[560px] bg-n-solid-2">
          <thead class="border-b border-n-weak bg-n-alpha-1">
            <tr>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.LIST.TEMPLATE') }}
              </th>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.LIST.CLIENT') }}
              </th>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.LIST.DOWNLOAD') }}
              </th>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.LIST.DOWNLOAD_WORD') }}
              </th>
              <th :class="TABLE_HEAD_CLASS">
                {{ t('CRM.CONTRACTS.LIST.PREVIOUS_VERSIONS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="contract in contracts"
              :key="contract.id"
              class="border-b border-n-weak last:border-0 hover:bg-n-alpha-1"
            >
              <td :class="`${TABLE_CELL_CLASS} text-n-slate-12`">
                {{ contract.template_name }}
              </td>
              <td :class="`${TABLE_CELL_CLASS} font-medium text-n-slate-12`">
                {{ contract.client_name }}
              </td>
              <td :class="TABLE_CELL_CLASS">
                <a
                  :href="contract.pdf_url"
                  target="_blank"
                  rel="noopener"
                  class="text-n-brand hover:underline"
                >
                  {{ t('CRM.CONTRACTS.LIST.DOWNLOAD') }}
                </a>
              </td>
              <td :class="TABLE_CELL_CLASS">
                <a
                  v-if="contract.docx_url"
                  :href="contract.docx_url"
                  target="_blank"
                  rel="noopener"
                  class="text-n-brand hover:underline"
                >
                  {{ t('CRM.CONTRACTS.LIST.DOWNLOAD_WORD') }}
                </a>
              </td>
              <td :class="TABLE_CELL_CLASS">
                <span
                  v-if="!contract.revisions?.length"
                  class="text-n-slate-10"
                >
                  -
                </span>
                <div v-else class="flex flex-col gap-1">
                  <a
                    v-for="revision in contract.revisions"
                    :key="revision.id"
                    :href="revision.pdf_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-n-brand text-xs hover:underline"
                  >
                    {{
                      t('CRM.CONTRACTS.LIST.VERSION_FROM', {
                        date: new Date(
                          revision.created_at * 1000
                        ).toLocaleDateString(),
                      })
                    }}
                  </a>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
