<script setup>
import { computed, onBeforeUnmount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
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
      </div>
    </template>
  </SettingsLayout>
</template>
