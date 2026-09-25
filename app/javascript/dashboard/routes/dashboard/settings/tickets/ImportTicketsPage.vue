<script setup>
import { ref } from 'vue';
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
];

const selectedFile = ref(null);
const isSubmitting = ref(false);
const result = ref(null);
const fileInput = ref(null);

const onFileChange = event => {
  selectedFile.value = event.target.files[0] || null;
  result.value = null;
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
  result.value = null;
  try {
    const { data } = await TicketImportsAPI.import(selectedFile.value);
    result.value = data;
    useAlert(
      t('TICKET.SETTINGS.IMPORT.API.SUCCESS', { count: data.created })
    );
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
              :disabled="!selectedFile"
              :is-loading="isSubmitting"
              @click="submit"
            />
          </div>
        </div>

        <div
          v-if="result"
          class="flex flex-col w-full gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <h3 class="text-heading-2 text-n-slate-12">
            {{ t('TICKET.SETTINGS.IMPORT.RESULT.TITLE') }}
          </h3>
          <div class="flex gap-4">
            <span class="text-sm text-n-teal-11">
              {{ t('TICKET.SETTINGS.IMPORT.RESULT.CREATED', { count: result.created }) }}
            </span>
            <span
              v-if="result.skipped"
              class="text-sm text-n-ruby-11"
            >
              {{ t('TICKET.SETTINGS.IMPORT.RESULT.SKIPPED', { count: result.skipped }) }}
            </span>
          </div>

          <div v-if="result.errors?.length" class="flex flex-col gap-2">
            <h4 class="text-sm font-medium text-n-ruby-11">
              {{ t('TICKET.SETTINGS.IMPORT.RESULT.ERRORS_TITLE') }}
            </h4>
            <ul class="flex flex-col gap-1 pl-4 m-0 list-disc">
              <li
                v-for="(error, index) in result.errors"
                :key="index"
                class="text-sm text-n-slate-11"
              >
                {{ formatRowMessage(error) }}
              </li>
            </ul>
          </div>

          <div v-if="result.warnings?.length" class="flex flex-col gap-2">
            <h4 class="text-sm font-medium text-n-amber-11">
              {{ t('TICKET.SETTINGS.IMPORT.RESULT.WARNINGS_TITLE') }}
            </h4>
            <ul class="flex flex-col gap-1 pl-4 m-0 list-disc">
              <li
                v-for="(warning, index) in result.warnings"
                :key="index"
                class="text-sm text-n-slate-11"
              >
                {{ formatRowMessage(warning) }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
