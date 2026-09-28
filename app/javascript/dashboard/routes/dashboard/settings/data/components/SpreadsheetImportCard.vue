<script setup>
import { ref, onBeforeUnmount } from 'vue';
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
});

const { t } = useI18n();

const fileInput = ref(null);
const selectedFile = ref(null);
const isUploading = ref(false);
const isPolling = ref(false);
const result = ref(null);
let pollTimer = null;

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

const downloadErrors = async () => {
  if (!result.value) return;
  const response = await DataImportsAPI.downloadErrorLogs(result.value.id);
  const url = window.URL.createObjectURL(new Blob([response.data]));
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', `${props.dataType}-erros.csv`);
  document.body.appendChild(link);
  link.click();
  link.remove();
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
    </div>
  </div>
</template>
