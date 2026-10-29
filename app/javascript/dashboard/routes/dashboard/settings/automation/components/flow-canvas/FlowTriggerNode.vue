<script setup>
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DEFAULT_HANDLE_ID, NODE_WIDTH } from './flowGraph';

// So contexto visual - representa o evento que inicia a automacao. Nao e uma
// etapa de verdade (nao existe em `steps`), por isso nao tem campos, nao abre
// painel de edicao e nao pode ser removido.
defineOptions({ inheritAttrs: false });

const { t } = useI18n();
</script>

<template>
  <div
    class="flex items-center gap-2 p-3 rounded-xl border border-dashed border-n-slate-6 bg-n-slate-2"
    :style="{ width: `${NODE_WIDTH}px` }"
  >
    <span
      class="flex items-center justify-center rounded-lg size-7 shrink-0 bg-n-slate-4 text-n-slate-11"
    >
      <Icon icon="i-lucide-play" class="size-4" />
    </span>
    <div class="flex flex-col min-w-0">
      <span class="text-xs font-medium truncate text-n-slate-12">
        {{ t('AUTOMATION.FLOW.CANVAS.TRIGGER_TITLE') }}
      </span>
      <span class="text-xs truncate text-n-slate-10">
        {{ t('AUTOMATION.FLOW.CANVAS.TRIGGER_DESCRIPTION') }}
      </span>
    </div>
    <Handle
      :id="DEFAULT_HANDLE_ID"
      type="source"
      :position="Position.Right"
      class="!bg-n-slate-8 !border-n-slate-1"
    />
  </div>
</template>
