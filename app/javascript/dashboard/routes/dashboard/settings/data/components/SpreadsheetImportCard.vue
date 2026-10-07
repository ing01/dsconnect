<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import DataImportsAPI from 'dashboard/api/dataImports';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  dataType: { type: String, required: true },
  icon: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, required: true },
  templateUrl: { type: String, required: true },
  templateFilename: { type: String, required: true },
  // Permite trocar a CHAVE de i18n usada no resumo/contagem de erro - o
  // texto genérico fala em "linhas importadas", o que não faz sentido pra um
  // cartão que só compara e não grava nada, como o comparativo de CNPJ.
  resultSummaryKey: {
    type: String,
    default: 'DATA_IMPORTS.SPREADSHEETS.RESULT_SUMMARY',
  },
  errorCountKey: {
    type: String,
    default: 'DATA_IMPORTS.SPREADSHEETS.ERROR_COUNT',
  },
  // So' o cartão de Comparativo de CNPJ usa isso: depois de comparar,
  // oferece excluir as Empresas cadastradas que NÃO estão na planilha (ver
  // CompanyCnpjCheckJob#record_unmatched_companies). Fica fora por padrão
  // pra nenhum outro cartão de planilha ganhar essa opção sem querer.
  allowDeleteUnmatched: { type: Boolean, default: false },
  // Mesma ideia, mas pras Empresas DUPLICADAS que o job acha dentro do
  // próprio sistema (ver CompanyCnpjCheckJob#record_duplicate_companies) -
  // independe da planilha ter sido enviada certa ou não.
  allowDeleteDuplicates: { type: Boolean, default: false },
});

const { t } = useI18n();

const fileInput = ref(null);
const selectedFile = ref(null);
const isUploading = ref(false);
const isPolling = ref(false);
const result = ref(null);
const isDeletingUnmatched = ref(false);
const isDeletingDuplicates = ref(false);
let pollTimer = null;

const unmatchedCount = computed(
  () => result.value?.stats?.unmatched_companies_count || 0
);
const duplicateCount = computed(
  () => result.value?.stats?.duplicate_companies_count || 0
);

const stopPolling = () => {
  if (!pollTimer) return;
  window.clearInterval(pollTimer);
  pollTimer = null;
};

const pollStatus = dataImportId => {
  stopPolling();
  pollTimer = window.setInterval(async () => {
    try {
      const { data } = await DataImportsAPI.show(dataImportId);
      if (data.status === 'pending' || data.status === 'processing') return;

      stopPolling();
      isPolling.value = false;
      result.value = {
        id: data.id,
        status: data.status,
        processed: data.processed_records || 0,
        total: data.total_records || 0,
        errorCount: data.import_errors_count || 0,
        stats: data.stats || {},
      };
    } catch (error) {
      stopPolling();
      isPolling.value = false;
    }
  }, 3000);
};

const onFileChange = event => {
  const [file] = event.target.files;
  selectedFile.value = file || null;
};

const onSubmit = async () => {
  if (!selectedFile.value) return;

  isUploading.value = true;
  result.value = null;
  try {
    const { data } = await DataImportsAPI.upload(props.dataType, selectedFile.value);
    selectedFile.value = null;
    if (fileInput.value) fileInput.value.value = '';
    isPolling.value = true;
    pollStatus(data.id);
  } catch (error) {
    useAlert(t('DATA_IMPORTS.SPREADSHEETS.UPLOAD_ERROR'));
  } finally {
    isUploading.value = false;
  }
};

const downloadBlob = (response, filename) => {
  const url = window.URL.createObjectURL(new Blob([response.data]));
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', filename);
  document.body.appendChild(link);
  link.click();
  link.remove();
};

const downloadErrors = async () => {
  if (!result.value) return;
  const response = await DataImportsAPI.downloadErrorLogs(result.value.id);
  downloadBlob(response, `${props.dataType}-erros.csv`);
};

const downloadUnmatchedCompanies = async () => {
  if (!result.value) return;
  const response = await DataImportsAPI.downloadUnmatchedCompanies(result.value.id);
  downloadBlob(response, `${props.dataType}-empresas-fora-da-planilha.csv`);
};

const downloadDuplicateCompanies = async () => {
  if (!result.value) return;
  const response = await DataImportsAPI.downloadDuplicateCompanies(result.value.id);
  downloadBlob(response, `${props.dataType}-empresas-duplicadas.csv`);
};

// Confirmação explícita (window.confirm, mesmo padrão já usado nos outros
// "excluir" deste app) antes de mandar o delete de verdade pro backend - a
// mensagem já avisa o que é mantido (contatos/tickets/pesquisas, só ficam
// sem empresa vinculada) e o que é apagado junto (credenciais e módulos de
// sistema da Empresa).
const deleteUnmatchedCompanies = async () => {
  if (!result.value || !unmatchedCount.value) return;
  // eslint-disable-next-line no-alert
  if (
    !window.confirm(
      t('DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.UNMATCHED.CONFIRM', {
        count: unmatchedCount.value,
      })
    )
  ) {
    return;
  }

  isDeletingUnmatched.value = true;
  try {
    const { data } = await DataImportsAPI.deleteUnmatchedCompanies(result.value.id);
    useAlert(
      t('DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.UNMATCHED.DELETE_SUCCESS', {
        count: data.deleted_count,
      })
    );
    result.value = {
      ...result.value,
      stats: { ...result.value.stats, unmatched_companies_count: 0 },
    };
  } catch (error) {
    useAlert(
      t('DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.UNMATCHED.DELETE_ERROR')
    );
  } finally {
    isDeletingUnmatched.value = false;
  }
};

// Mesmo fluxo de confirmação acima, pras duplicatas.
const deleteDuplicateCompanies = async () => {
  if (!result.value || !duplicateCount.value) return;
  // eslint-disable-next-line no-alert
  if (
    !window.confirm(
      t('DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.DUPLICATE.CONFIRM', {
        count: duplicateCount.value,
      })
    )
  ) {
    return;
  }

  isDeletingDuplicates.value = true;
  try {
    const { data } = await DataImportsAPI.deleteDuplicateCompanies(result.value.id);
    useAlert(
      t('DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.DUPLICATE.DELETE_SUCCESS', {
        count: data.deleted_count,
      })
    );
    result.value = {
      ...result.value,
      stats: { ...result.value.stats, duplicate_companies_count: 0 },
    };
  } catch (error) {
    useAlert(
      t('DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.DUPLICATE.DELETE_ERROR')
    );
  } finally {
    isDeletingDuplicates.value = false;
  }
};

onBeforeUnmount(() => stopPolling());
</script>

<template>
  <div class="flex flex-col gap-4 p-5 border rounded-2xl border-n-weak bg-n-solid-1">
    <div class="flex items-start gap-3">
      <div class="grid flex-shrink-0 rounded-xl place-content-center size-10 bg-gradient-to-br from-n-blue-9 to-n-teal-9">
        <Icon :icon="icon" class="text-white size-5" />
      </div>
      <div class="min-w-0">
        <h3 class="font-medium text-n-slate-12">{{ title }}</h3>
        <p class="mt-0.5 text-sm text-n-slate-11">{{ description }}</p>
      </div>
    </div>

    <a
      :href="templateUrl"
      :download="templateFilename"
      class="inline-flex items-center self-start gap-1.5 text-sm font-medium text-n-blue-11 hover:underline"
    >
      <Icon icon="i-lucide-download" class="size-4" />
      {{ t('DATA_IMPORTS.SPREADSHEETS.DOWNLOAD_TEMPLATE') }}
    </a>

    <div class="flex flex-wrap items-center gap-2">
      <label
        class="flex items-center h-8 gap-2 px-3 text-sm border rounded-lg cursor-pointer border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
      >
        <Icon icon="i-lucide-paperclip" class="size-4" />
        <span class="max-w-[12rem] truncate">
          {{ selectedFile ? selectedFile.name : t('DATA_IMPORTS.SPREADSHEETS.CHOOSE_FILE') }}
        </span>
        <input
          ref="fileInput"
          type="file"
          accept=".xlsx"
          class="hidden"
          @change="onFileChange"
        />
      </label>
      <Button
        size="sm"
        icon="i-lucide-upload"
        :is-loading="isUploading"
        :disabled="!selectedFile || isUploading"
        :label="t('DATA_IMPORTS.SPREADSHEETS.SUBMIT')"
        @click="onSubmit"
      />
    </div>

    <div v-if="isPolling" class="flex items-center gap-2 text-sm text-n-slate-11">
      <Icon icon="i-lucide-loader-circle" class="animate-spin size-4" />
      {{ t('DATA_IMPORTS.SPREADSHEETS.PROCESSING') }}
    </div>

    <div
      v-else-if="result"
      class="flex flex-col gap-2 p-3 text-sm rounded-lg bg-n-slate-2"
    >
      <p class="font-medium text-n-slate-12">
        {{
          t(resultSummaryKey, {
            processed: result.processed,
            total: result.total,
          })
        }}
      </p>
      <button
        v-if="result.errorCount"
        type="button"
        class="inline-flex items-center self-start gap-1.5 text-n-ruby-11 hover:underline"
        @click="downloadErrors"
      >
        <Icon icon="i-lucide-triangle-alert" class="size-4" />
        {{ t(errorCountKey, { count: result.errorCount }) }}
      </button>

      <div
        v-if="allowDeleteUnmatched && unmatchedCount"
        class="flex flex-col gap-2 pt-2 mt-1 border-t border-n-weak"
      >
        <p class="text-n-slate-11">
          {{
            t(
              'DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.UNMATCHED.COUNT',
              { count: unmatchedCount }
            )
          }}
        </p>
        <div class="flex flex-wrap items-center gap-3">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 font-medium text-n-blue-11 hover:underline"
            @click="downloadUnmatchedCompanies"
          >
            <Icon icon="i-lucide-download" class="size-4" />
            {{
              t(
                'DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.UNMATCHED.DOWNLOAD'
              )
            }}
          </button>
          <Button
            size="sm"
            color="ruby"
            icon="i-lucide-trash-2"
            :is-loading="isDeletingUnmatched"
            :label="
              t(
                'DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.UNMATCHED.DELETE_BUTTON'
              )
            "
            @click="deleteUnmatchedCompanies"
          />
        </div>
      </div>

      <div
        v-if="allowDeleteDuplicates && duplicateCount"
        class="flex flex-col gap-2 pt-2 mt-1 border-t border-n-weak"
      >
        <p class="text-n-slate-11">
          {{
            t(
              'DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.DUPLICATE.COUNT',
              { count: duplicateCount }
            )
          }}
        </p>
        <div class="flex flex-wrap items-center gap-3">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 font-medium text-n-blue-11 hover:underline"
            @click="downloadDuplicateCompanies"
          >
            <Icon icon="i-lucide-download" class="size-4" />
            {{
              t(
                'DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.DUPLICATE.DOWNLOAD'
              )
            }}
          </button>
          <Button
            size="sm"
            color="ruby"
            icon="i-lucide-trash-2"
            :is-loading="isDeletingDuplicates"
            :label="
              t(
                'DATA_IMPORTS.SPREADSHEETS.COMPANY_CNPJ_CHECK.DUPLICATE.DELETE_BUTTON'
              )
            "
            @click="deleteDuplicateCompanies"
          />
        </div>
      </div>
    </div>
  </div>
</template>
