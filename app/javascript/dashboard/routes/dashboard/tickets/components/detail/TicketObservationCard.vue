<script setup>
/**
 * A Observação livre do ticket (qualquer Mesa, fora do módulo de desenvolvimento).
 *
 * Escrita como a Descrição: o mesmo editor de texto formatado, num modal grande. É
 * opcional - sem texto, o cartão só oferece "Adicionar". Esvaziar o texto e salvar (ou
 * "Remover") apaga a observação.
 */
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

// As mesmas opções da Descrição (sem imagem e vídeo: o botão de imagem do editor
// depende de uma rota de portal que não existe na tela do ticket).
const MENU_OPTIONS = [
  'bold',
  'italic',
  'strike',
  'link',
  'undo',
  'redo',
  'code',
  'h1',
  'h2',
  'h3',
  'bulletList',
  'orderedList',
  'blockquote',
  'codeBlock',
];

const { t } = useI18n();

const dialogRef = ref(null);
const isEditing = ref(false);
const draft = ref('');
// O que acabamos de mandar salvar; comparado com o que volta no ticket para fechar o
// modal (a flag `isSaving` desliga tarde demais - mesmo motivo da Descrição). Não é
// reativo de propósito.
let justSaved = null;

const hasObservation = computed(() =>
  Boolean(props.ticket.observation?.trim())
);

// Aberto quando ha texto, minimizado quando nao ha. Segue o conteudo: ao salvar a
// primeira observacao (ou ao chegar uma por outra pessoa) abre; ao remover, minimiza.
// O clique no titulo troca na hora, sem mexer no texto.
const expanded = ref(hasObservation.value);
watch(hasObservation, has => {
  expanded.value = has;
});

const renderedObservation = computed(
  () => new MessageFormatter(props.ticket.observation || '').formattedMessage
);

const startEditing = () => {
  draft.value = props.ticket.observation ?? '';
  isEditing.value = true;
  nextTick(() => dialogRef.value?.open());
};

const resetEditing = () => {
  isEditing.value = false;
  draft.value = '';
  justSaved = null;
};

const closeDialog = () => {
  if (dialogRef.value) dialogRef.value.close();
  else resetEditing();
};

const send = value => {
  justSaved = value;
  emit('save', { observation: value });
};

const save = () => send(draft.value);

// Remover é salvar vazio: o servidor guarda "sem observação".
const remove = () => {
  draft.value = '';
  send('');
};

const normalized = value => (value || '').trim();

watch(
  () => props.ticket.observation,
  newObservation => {
    if (
      isEditing.value &&
      normalized(newObservation) === normalized(justSaved)
    ) {
      closeDialog();
    }
  }
);
</script>

<template>
  <section
    class="rounded-xl border border-n-weak px-4 flex flex-col min-w-0"
    :class="expanded ? 'py-4 gap-3' : 'py-2'"
    data-testid="observation-card"
  >
    <div class="flex items-center justify-between gap-2">
      <button
        type="button"
        class="flex items-center gap-1.5 min-w-0 p-0 text-left"
        :aria-expanded="expanded"
        data-testid="observation-toggle"
        @click="expanded = !expanded"
      >
        <Icon
          :icon="expanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
          class="size-4 shrink-0 text-n-slate-10"
        />
        <h2 class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('TICKET.DETAIL.OBSERVATION.TITLE') }}
        </h2>
      </button>
      <Button
        v-if="canUpdate"
        variant="ghost"
        color="slate"
        size="xs"
        :icon="hasObservation ? 'i-lucide-pencil' : 'i-lucide-plus'"
        :label="
          hasObservation
            ? t('TICKET.DETAIL.OBSERVATION.EDIT')
            : t('TICKET.DETAIL.OBSERVATION.ADD')
        "
        data-testid="observation-edit"
        @click="startEditing"
      />
    </div>

    <Dialog
      ref="dialogRef"
      :title="t('TICKET.DETAIL.OBSERVATION.EDIT_DIALOG_TITLE')"
      width="3xl"
      @confirm="save"
      @close="resetEditing"
    >
      <FullEditor
        v-if="isEditing"
        v-model="draft"
        :editor-id="`ticket-observation-${ticket.id}`"
        :placeholder="t('TICKET.DETAIL.OBSERVATION.PLACEHOLDER')"
        :enabled-menu-options="MENU_OPTIONS"
        class="ticket-observation-editor min-w-0"
      />
      <template #footer>
        <div class="flex items-center justify-end w-full gap-2">
          <Button
            v-if="hasObservation"
            variant="faded"
            color="ruby"
            size="sm"
            type="button"
            icon="i-lucide-trash-2"
            :is-loading="isSaving"
            :label="t('TICKET.DETAIL.OBSERVATION.REMOVE')"
            class="mr-auto"
            data-testid="observation-remove"
            @click="remove"
          />
          <Button
            variant="faded"
            color="slate"
            size="sm"
            type="button"
            :label="t('TICKET.DETAIL.OBSERVATION.CANCEL')"
            @click="closeDialog"
          />
          <Button
            size="sm"
            type="button"
            :is-loading="isSaving"
            :label="t('TICKET.DETAIL.OBSERVATION.SAVE')"
            data-testid="observation-save"
            @click="save"
          />
        </div>
      </template>
    </Dialog>

    <div
      v-if="expanded && hasObservation"
      v-dompurify-html="renderedObservation"
      class="prose-sm max-w-none text-sm text-n-slate-12 break-words"
    />

    <p v-else-if="expanded" class="text-sm text-n-slate-10">
      {{ t('TICKET.DETAIL.OBSERVATION.EMPTY') }}
    </p>
  </section>
</template>

<style scoped>
/* Mesma área grande e fonte menor da Descrição, para caber mais texto. */
.ticket-observation-editor :deep(.ProseMirror-woot-style) {
  height: 52vh;
  min-height: 16rem;
  max-height: none;
  overflow-y: auto;
  font-size: 0.875rem;
  line-height: 1.45;
}

.ticket-observation-editor :deep(.ProseMirror-woot-style p) {
  margin: 0 0 0.5rem;
}
</style>
