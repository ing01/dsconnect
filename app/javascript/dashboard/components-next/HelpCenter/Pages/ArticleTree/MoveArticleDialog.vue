<script setup>
/**
 * "Mover para...": a alternativa ao arrastar (teclado, toque). Lista as pastas e os artigos
 * que podem receber o artigo, com recuo para mostrar a hierarquia.
 */
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { NODE_TYPE } from './articleTreeHelper';

defineProps({
  targets: { type: Array, default: () => [] },
});

const emit = defineEmits(['confirm']);

const { t } = useI18n();

// Espaco que nao some dentro do <option>: mostra a hierarquia.
const INDENT = String.fromCharCode(160).repeat(2);

const dialogRef = ref(null);
const node = ref(null);
const selected = ref('');

const open = articleNode => {
  node.value = articleNode;
  selected.value = '';
  dialogRef.value?.open();
};

const keyOf = target => `${target.type}-${target.id}`;

const confirm = () => {
  if (!selected.value) return;
  emit('confirm', { node: node.value, targetKey: selected.value });
  dialogRef.value?.close();
};

const isDisabled = computed(() => !selected.value);

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('HELP_CENTER.KB_TREE.MOVE.TITLE')"
    :description="t('HELP_CENTER.KB_TREE.MOVE.DESCRIPTION')"
    :confirm-button-label="t('HELP_CENTER.KB_TREE.MOVE.CONFIRM')"
    :disable-confirm-button="isDisabled"
    @confirm="confirm"
  >
    <label class="flex flex-col gap-1 text-sm">
      <span class="font-medium text-n-slate-12">
        {{ t('HELP_CENTER.KB_TREE.MOVE.TARGET') }}
      </span>
      <select
        v-model="selected"
        class="w-full mb-0 text-sm"
        data-testid="kb-move-target"
      >
        <option value="" disabled>
          {{ t('HELP_CENTER.KB_TREE.FORM_DIALOG.CHOOSE') }}
        </option>
        <option
          v-for="target in targets"
          :key="keyOf(target)"
          :value="keyOf(target)"
        >
          {{
            INDENT.repeat(target.depth) +
            (target.type === NODE_TYPE.FOLDER ? '▸ ' : '• ') +
            target.label
          }}
        </option>
      </select>
    </label>
  </Dialog>
</template>
