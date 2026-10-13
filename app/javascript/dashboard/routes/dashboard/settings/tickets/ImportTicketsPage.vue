<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import TicketImportsAPI from 'dashboard/api/ticketImports';

import NextButton from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();

// Mesma ordem que Tickets::ImportService espera - o nome da coluna e o que
// importa (sem acento tambem funciona), nao a posicao.
const TEMPLATE_HEADERS = [
  'Número',
  'Cliente',
  'Título',
  'Descrição',
  'Status',
  'Estágio',
  'Contato',
  'Time',
  'Prioridade',
  'Catálogo de Serviços',
  'Área do Catálogo de Serviços',
  'Item',
  'Ticket pai',
  'Criado por',
  'Criado em',
  'Categoria',
  'Data',
  'Desenvolvimento',
  'Responsável',
];
const TEMPLATE_EXAMPLE_ROW = [
  '1001',
  'Empresa Exemplo Ltda',
  'Erro ao emitir nota fiscal',
  'Cliente relata erro ao tentar emitir NF-e pelo sistema.',
  'Aberto',
  'Em andamento',
  'João Vitor',
  'Suporte N1',
  'Alta',
  'DS Comercial',
  'Movimentações',
  'Notas Fiscais de Mercadorias',
  '',
  'Maria Silva',
  '05/03/2024 09:30',
  'Erro',
  '',
  'PROJ-123',
  'Carlos Andrade',
];

// A cada quanto tempo a tela busca o progresso de uma importacao rodando em
// segundo plano - rapido o suficiente pra parecer ao vivo, sem virar uma
// enxurrada de requisicoes numa planilha que demora dezenas de minutos.
const POLL_INTERVAL_MS = 2500;

const selectedFile = ref(null);
const isSubmitting = ref(false);
const ticketImport = ref(null);
const fileInput = ref(null);
let pollTimer = null;

// O log: as ultimas importacoes da conta, pra saber o que ja rodou mesmo
// depois de sair e voltar pra esta tela - o resultado de `ticketImport`
// acima so existe enquanto o upload que a gerou estiver na tela.
const importLog = ref([]);
const expandedLogIds = ref(new Set());

const fetchImportLog = async () => {
  try {
    const { data } = await TicketImportsAPI.get();
    importLog.value = data;
  } catch (error) {
    // Uma falha pontual de rede deixa o historico vazio por agora - a tela
    // nao trava por isso, o upload continua funcionando normalmente.
  }
};

const toggleLogDetails = id => {
  const next = new Set(expandedLogIds.value);
  if (next.has(id)) {
    next.delete(id);
  } else {
    next.add(id);
  }
  expandedLogIds.value = next;
};

const formatLogDate = unixSeconds =>
  unixSeconds ? shortTimestamp(dynamicTime(unixSeconds)) : '';

const LOG_STATUS_CLASSES = {
  completed: 'text-n-teal-11',
  failed: 'text-n-ruby-11',
  processing: 'text-n-amber-11',
  pending: 'text-n-slate-11',
};
const logStatusClass = status => LOG_STATUS_CLASSES[status] || 'text-n-slate-11';

onMounted(fetchImportLog);

const isProcessing = computed(
  () =>
    ticketImport.value &&
    ['pending', 'processing'].includes(ticketImport.value.status)
);
const progressPercent = computed(() => {
  const total = ticketImport.value?.total_rows;
  if (!total) return 0;
  return Math.min(
    100,
    Math.round(((ticketImport.value.processed_rows || 0) / total) * 100)
  );
});

const stopPolling = () => {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
};

const pollStatus = async id => {
  try {
    const { data } = await TicketImportsAPI.show(id);
    ticketImport.value = data;
    if (!['pending', 'processing'].includes(data.status)) {
      stopPolling();
      // A importacao que acabou de terminar tambem deve aparecer no log,
      // sem precisar sair e voltar na tela (ou dar F5) pra ver.
      fetchImportLog();
    }
  } catch (error) {
    // Uma falha pontual de rede nao para o acompanhamento - a proxima
    // tentativa do intervalo tenta de novo sozinha.
  }
};

const onFileChange = event => {
  selectedFile.value = event.target.files[0] || null;
  ticketImport.value = null;
};

const downloadTemplate = () => {
  const csvLines = [TEMPLATE_HEADERS, TEMPLATE_EXAMPLE_ROW].map(row =>
    row.map(value => `"${String(value).replace(/"/g, '""')}"`).join(',')
  );
  // BOM no inicio: sem isso o Excel abre acentuado como lixo em UTF-8.
  const blob = new Blob(['﻿', csvLines.join('\n')], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'modelo-importacao-tickets.csv';
  link.click();
  URL.revokeObjectURL(url);
};

// Linha 0 e um erro geral (ex: cabecalho nao reconhecido), nao uma linha de
// dado de verdade - mostra so a mensagem, sem "Linha 0:".
const formatRowMessage = row =>
  row.row > 0
    ? t('TICKET.SETTINGS.IMPORT.RESULT.ROW_MESSAGE', {
        row: row.row,
        message: row.message,
      })
    : row.message;

const submit = async () => {
  if (!selectedFile.value) return;

  isSubmitting.value = true;
  stopPolling();
  ticketImport.value = null;
  try {
    const { data } = await TicketImportsAPI.import(selectedFile.value);
    ticketImport.value = data;
    pollTimer = setInterval(() => pollStatus(data.id), POLL_INTERVAL_MS);
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.SETTINGS.IMPORT.API.ERROR')
    );
  } finally {
    isSubmitting.value = false;
    selectedFile.value = null;
    if (fileInput.value) fileInput.value.value = '';
  }
};

onBeforeUnmount(stopPolling);
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.IMPORT.TITLE')"
        :description="t('TICKET.SETTINGS.IMPORT.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="flex flex-col w-full max-w-2xl gap-5">
        <div
          class="flex flex-col w-full gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <div class="flex flex-col gap-1">
            <h3 class="text-heading-2 text-n-slate-12">
              {{ t('TICKET.SETTINGS.IMPORT.FIELDS.TITLE') }}
            </h3>
            <p class="mb-0 text-body-para text-n-slate-11">
              {{ t('TICKET.SETTINGS.IMPORT.FIELDS.DESCRIPTION') }}
            </p>
          </div>
          <NextButton
            type="button"
            slate
            faded
            sm
            icon="i-lucide-download"
            :label="t('TICKET.SETTINGS.IMPORT.DOWNLOAD_TEMPLATE')"
            class="self-start"
            @click="downloadTemplate"
          />

          <div class="flex flex-col gap-2 pt-2 border-t border-n-weak">
            <label class="text-sm text-n-slate-12">
              {{ t('TICKET.SETTINGS.IMPORT.FILE_LABEL') }}
            </label>
            <input
              ref="fileInput"
              type="file"
              accept=".csv"
              class="mb-0"
              :disabled="isProcessing"
              @change="onFileChange"
            />
            <p class="mb-0 text-xs text-n-slate-11">
              {{ t('TICKET.SETTINGS.IMPORT.FILE_HINT') }}
            </p>
          </div>

          <div class="flex justify-end">
            <NextButton
              type="button"
              blue
              :label="t('TICKET.SETTINGS.IMPORT.SUBMIT')"
              :disabled="!selectedFile || isProcessing"
              :is-loading="isSubmitting"
              @click="submit"
            />
          </div>
        </div>

        <div
          v-if="ticketImport"
          class="flex flex-col w-full gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <h3 class="text-heading-2 text-n-slate-12">
            {{ t('TICKET.SETTINGS.IMPORT.RESULT.TITLE') }}
          </h3>

          <div v-if="isProcessing" class="flex flex-col gap-2">
            <p class="mb-0 text-sm text-n-slate-11">
              {{
                ticketImport.total_rows
                  ? t('TICKET.SETTINGS.IMPORT.RESULT.PROCESSING_WITH_TOTAL', {
                      processed: ticketImport.processed_rows || 0,
                      total: ticketImport.total_rows,
                    })
                  : t('TICKET.SETTINGS.IMPORT.RESULT.PROCESSING')
              }}
            </p>
            <div
              v-if="ticketImport.total_rows"
              class="w-full h-2 overflow-hidden rounded-full bg-n-slate-4"
            >
              <div
                class="h-full transition-all rounded-full bg-n-brand"
                :style="{ width: `${progressPercent}%` }"
              />
            </div>
          </div>

          <p
            v-else-if="ticketImport.status === 'failed'"
            class="mb-0 text-sm text-n-ruby-11"
          >
            {{
              t('TICKET.SETTINGS.IMPORT.RESULT.FAILED', {
                message: ticketImport.failure_message,
              })
            }}
          </p>

          <template v-else>
            <div class="flex gap-4">
              <span class="text-sm text-n-teal-11">
                {{
                  t('TICKET.SETTINGS.IMPORT.RESULT.CREATED', {
                    count: ticketImport.created_count,
                  })
                }}
              </span>
              <span v-if="ticketImport.updated_count" class="text-sm text-n-blue-11">
                {{
                  t('TICKET.SETTINGS.IMPORT.RESULT.UPDATED', {
                    count: ticketImport.updated_count,
                  })
                }}
              </span>
              <span v-if="ticketImport.skipped_count" class="text-sm text-n-ruby-11">
                {{
                  t('TICKET.SETTINGS.IMPORT.RESULT.SKIPPED', {
                    count: ticketImport.skipped_count,
                  })
                }}
              </span>
            </div>

            <div v-if="ticketImport.row_errors?.length" class="flex flex-col gap-2">
              <h4 class="text-sm font-medium text-n-ruby-11">
                {{ t('TICKET.SETTINGS.IMPORT.RESULT.ERRORS_TITLE') }}
              </h4>
              <ul class="flex flex-col gap-1 pl-4 m-0 list-disc">
                <li
                  v-for="(error, index) in ticketImport.row_errors"
                  :key="index"
                  class="text-sm text-n-slate-11"
                >
                  {{ formatRowMessage(error) }}
                </li>
              </ul>
            </div>

            <div v-if="ticketImport.row_warnings?.length" class="flex flex-col gap-2">
              <h4 class="text-sm font-medium text-n-amber-11">
                {{ t('TICKET.SETTINGS.IMPORT.RESULT.WARNINGS_TITLE') }}
              </h4>
              <ul class="flex flex-col gap-1 pl-4 m-0 list-disc">
                <li
                  v-for="(warning, index) in ticketImport.row_warnings"
                  :key="index"
                  class="text-sm text-n-slate-11"
                >
                  {{ formatRowMessage(warning) }}
                </li>
              </ul>
            </div>
          </template>
        </div>

        <div
          v-if="importLog.length"
          class="flex flex-col w-full gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <h3 class="text-heading-2 text-n-slate-12">
            {{ t('TICKET.SETTINGS.IMPORT.LOG.TITLE') }}
          </h3>

          <div class="flex flex-col gap-3">
            <div
              v-for="log in importLog"
              :key="log.id"
              class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
            >
              <div class="flex items-center justify-between gap-2">
                <div class="flex flex-col">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ formatLogDate(log.created_at) }}
                  </span>
                  <span class="text-xs text-n-slate-11">
                    {{ log.user_name || t('TICKET.SETTINGS.IMPORT.LOG.UNKNOWN_USER') }}
                  </span>
                </div>
                <span
                  class="text-xs font-medium"
                  :class="logStatusClass(log.status)"
                >
                  {{ t(`TICKET.SETTINGS.IMPORT.LOG.STATUS.${log.status.toUpperCase()}`) }}
                </span>
              </div>

              <p v-if="log.status === 'failed'" class="mb-0 text-sm text-n-ruby-11">
                {{
                  t('TICKET.SETTINGS.IMPORT.RESULT.FAILED', {
                    message: log.failure_message,
                  })
                }}
              </p>

              <div v-else-if="log.status === 'completed'" class="flex gap-4">
                <span class="text-sm text-n-teal-11">
                  {{
                    t('TICKET.SETTINGS.IMPORT.RESULT.CREATED', {
                      count: log.created_count,
                    })
                  }}
                </span>
                <span v-if="log.updated_count" class="text-sm text-n-blue-11">
                  {{
                    t('TICKET.SETTINGS.IMPORT.RESULT.UPDATED', {
                      count: log.updated_count,
                    })
                  }}
                </span>
                <span v-if="log.skipped_count" class="text-sm text-n-ruby-11">
                  {{
                    t('TICKET.SETTINGS.IMPORT.RESULT.SKIPPED', {
                      count: log.skipped_count,
                    })
                  }}
                </span>
              </div>

              <NextButton
                v-if="log.row_errors?.length || log.row_warnings?.length"
                type="button"
                slate
                faded
                xs
                class="self-start"
                :label="
                  expandedLogIds.has(log.id)
                    ? t('TICKET.SETTINGS.IMPORT.LOG.HIDE_DETAILS')
                    : t('TICKET.SETTINGS.IMPORT.LOG.SHOW_DETAILS')
                "
                @click="toggleLogDetails(log.id)"
              />

              <template v-if="expandedLogIds.has(log.id)">
                <div v-if="log.row_errors?.length" class="flex flex-col gap-2">
                  <h4 class="text-sm font-medium text-n-ruby-11">
                    {{ t('TICKET.SETTINGS.IMPORT.RESULT.ERRORS_TITLE') }}
                  </h4>
                  <ul class="flex flex-col gap-1 pl-4 m-0 list-disc">
                    <li
                      v-for="(error, index) in log.row_errors"
                      :key="index"
                      class="text-sm text-n-slate-11"
                    >
                      {{ formatRowMessage(error) }}
                    </li>
                  </ul>
                </div>

                <div v-if="log.row_warnings?.length" class="flex flex-col gap-2">
                  <h4 class="text-sm font-medium text-n-amber-11">
                    {{ t('TICKET.SETTINGS.IMPORT.RESULT.WARNINGS_TITLE') }}
                  </h4>
                  <ul class="flex flex-col gap-1 pl-4 m-0 list-disc">
                    <li
                      v-for="(warning, index) in log.row_warnings"
                      :key="index"
                      class="text-sm text-n-slate-11"
                    >
                      {{ formatRowMessage(warning) }}
                    </li>
                  </ul>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
