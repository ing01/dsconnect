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
  CRM_LOCKED_CLIENT_TOKEN_KEYS,
  CRM_YES_NO_TOKEN_KEYS,
} from '../crmContractTokenLabels';

const { t } = useI18n();

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

// Os 5 tokens de identidade do cliente (razão social, CNPJ etc.) sempre vêm
// do cadastro - o backend já trava isso (ver Crm::ContractTokenMapper), e
// por isso nem aparecem como campo editável aqui.
const editableTokens = computed(() =>
  (selectedTemplate.value?.tokens || []).filter(
    token => !CRM_LOCKED_CLIENT_TOKEN_KEYS.includes(token)
  )
);

const isYesNoToken = token => CRM_YES_NO_TOKEN_KEYS.includes(token);

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
    tokenValues.value[token] = '';
  });
};

const generate = async () => {
  if (!selectedTemplateId.value || !selectedClientId.value) return;
  generationError.value = '';
  isGenerating.value = true;
  try {
    const filledData = Object.fromEntries(
      Object.entries(tokenValues.value).filter(
        ([, value]) => String(value || '').trim() !== ''
      )
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
  <div class="flex-1 overflow-auto p-4">
    <div class="flex items-center justify-between gap-3">
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
    <p class="mb-4 text-sm text-n-slate-11">
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
      <table class="w-full text-xs">
        <thead>
          <tr class="text-left text-n-slate-11 border-b border-n-weak">
            <th class="py-2 pr-3">{{ t('CRM.CONTRACTS.TOKEN_HELP.TOKEN') }}</th>
            <th class="py-2">{{ t('CRM.CONTRACTS.TOKEN_HELP.MEANING') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="[token, meaning] in tokenHelpEntries"
            :key="token"
            class="border-b border-n-weak align-top"
          >
            <td class="py-2 pr-3 font-mono whitespace-nowrap text-n-slate-12">
              [[{{ token }}]]
            </td>
            <td class="py-2 text-n-slate-11">{{ meaning }}</td>
          </tr>
        </tbody>
      </table>
    </Dialog>

    <div class="p-4 mb-6 rounded-xl border border-n-weak bg-n-solid-2">
      <h3 class="mb-3 text-sm font-medium text-n-slate-12">
        {{ t('CRM.CONTRACTS.TEMPLATES.TITLE') }}
      </h3>

      <div class="flex items-end gap-3 mb-4">
        <Input
          v-model="newTemplateName"
          :label="t('CRM.CONTRACTS.TEMPLATES.NAME')"
          class="max-w-xs"
        />
        <input
          type="file"
          accept=".docx"
          class="text-xs"
          @change="onFileChange"
        />
        <Button
          :label="t('CRM.CONTRACTS.TEMPLATES.UPLOAD')"
          :is-loading="isUploading"
          :disabled="!newTemplateName || !newTemplateFile"
          @click="uploadTemplate"
        />
      </div>

      <table v-if="templates.length" class="w-full text-sm">
        <thead>
          <tr class="text-left text-n-slate-11 border-b border-n-weak">
            <th class="py-2">{{ t('CRM.CONTRACTS.TEMPLATES.NAME') }}</th>
            <th class="py-2">{{ t('CRM.CONTRACTS.TEMPLATES.TOKENS') }}</th>
            <th class="py-2">{{ t('CRM.CONTRACTS.TEMPLATES.ACTIONS') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="template in templates"
            :key="template.id"
            class="border-b border-n-weak"
          >
            <td class="py-2 font-medium text-n-slate-12">
              {{ template.name }}
            </td>
            <td class="py-2 text-n-slate-11">{{ template.tokens.length }}</td>
            <td class="py-2">
              <button class="text-n-ruby-9" @click="removeTemplate(template)">
                <i class="i-lucide-trash-2 size-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else class="text-sm text-n-slate-11">
        {{ t('CRM.CONTRACTS.TEMPLATES.EMPTY') }}
      </p>
    </div>

    <div class="p-4 mb-6 rounded-xl border border-n-weak bg-n-solid-2">
      <h3 class="mb-3 text-sm font-medium text-n-slate-12">
        {{ t('CRM.CONTRACTS.GENERATE.TITLE') }}
      </h3>

      <div class="grid grid-cols-3 gap-3 mb-4">
        <div class="flex flex-col gap-1">
          <label class="text-[11px] font-medium text-n-slate-11">{{
            t('CRM.CONTRACTS.GENERATE.TEMPLATE')
          }}</label>
          <select
            v-model="selectedTemplateId"
            class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12"
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
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[11px] font-medium text-n-slate-11">{{
            t('CRM.CONTRACTS.GENERATE.CLIENT')
          }}</label>
          <select
            v-model="selectedClientId"
            class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12"
          >
            <option value="" disabled>-</option>
            <option
              v-for="client in clients"
              :key="client.id"
              :value="client.id"
            >
              {{ client.name }}
            </option>
          </select>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[11px] font-medium text-n-slate-11">{{
            t('CRM.CONTRACTS.GENERATE.SALE')
          }}</label>
          <select
            v-model="selectedSaleId"
            class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12"
          >
            <option value="">-</option>
            <option v-for="sale in clientSales" :key="sale.id" :value="sale.id">
              {{ sale.competencia }}
            </option>
          </select>
        </div>
      </div>

      <p
        v-if="selectedClientExtraRepresentatives.length"
        class="mb-3 text-xs text-n-amber-11"
      >
        {{
          t('CRM.CONTRACTS.GENERATE.EXTRA_REPRESENTATIVES_HINT', {
            count: selectedClientExtraRepresentatives.length,
          })
        }}
      </p>

      <div v-if="selectedTemplate" class="mb-4">
        <p class="mb-2 text-xs text-n-slate-11">
          {{ t('CRM.CONTRACTS.GENERATE.FIELDS_HINT') }}
        </p>
        <p class="mb-2 text-xs text-n-slate-10">
          {{ t('CRM.CONTRACTS.GENERATE.LOCKED_FIELDS_HINT') }}
        </p>
        <div class="grid grid-cols-3 gap-3">
          <div
            v-for="token in editableTokens"
            :key="token"
            class="flex flex-col gap-1"
          >
            <template v-if="isYesNoToken(token)">
              <label class="text-[11px] font-medium text-n-slate-11">{{
                `${crmContractTokenLabel(token)} (${token})`
              }}</label>
              <select
                v-model="tokenValues[token]"
                class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12"
              >
                <option value="">-</option>
                <option value="Sim">
                  {{ t('CRM.CONTRACTS.GENERATE.YES') }}
                </option>
                <option value="Não">
                  {{ t('CRM.CONTRACTS.GENERATE.NO') }}
                </option>
              </select>
            </template>
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
        :label="t('CRM.CONTRACTS.GENERATE.SUBMIT')"
        :is-loading="isGenerating"
        :disabled="!selectedTemplateId || !selectedClientId"
        @click="generate"
      />
    </div>

    <div>
      <h3 class="mb-3 text-sm font-medium text-n-slate-12">
        {{ t('CRM.CONTRACTS.LIST.TITLE') }}
      </h3>
      <p v-if="!isLoading && !contracts.length" class="text-sm text-n-slate-11">
        {{ t('CRM.CONTRACTS.LIST.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-left text-n-slate-11 border-b border-n-weak">
            <th class="py-2">{{ t('CRM.CONTRACTS.LIST.TEMPLATE') }}</th>
            <th class="py-2">{{ t('CRM.CONTRACTS.LIST.CLIENT') }}</th>
            <th class="py-2">{{ t('CRM.CONTRACTS.LIST.DOWNLOAD') }}</th>
            <th class="py-2">{{ t('CRM.CONTRACTS.LIST.DOWNLOAD_WORD') }}</th>
            <th class="py-2">
              {{ t('CRM.CONTRACTS.LIST.PREVIOUS_VERSIONS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="contract in contracts"
            :key="contract.id"
            class="border-b border-n-weak"
          >
            <td class="py-2">{{ contract.template_name }}</td>
            <td class="py-2 font-medium text-n-slate-12">
              {{ contract.client_name }}
            </td>
            <td class="py-2">
              <a
                :href="contract.pdf_url"
                target="_blank"
                rel="noopener"
                class="text-n-brand"
              >
                {{ t('CRM.CONTRACTS.LIST.DOWNLOAD') }}
              </a>
            </td>
            <td class="py-2">
              <a
                v-if="contract.docx_url"
                :href="contract.docx_url"
                target="_blank"
                rel="noopener"
                class="text-n-brand"
              >
                {{ t('CRM.CONTRACTS.LIST.DOWNLOAD_WORD') }}
              </a>
            </td>
            <td class="py-2">
              <span v-if="!contract.revisions?.length" class="text-n-slate-10">-</span>
              <div v-else class="flex flex-col gap-0.5">
                <a
                  v-for="revision in contract.revisions"
                  :key="revision.id"
                  :href="revision.pdf_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-n-brand text-xs"
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
  </div>
</template>
