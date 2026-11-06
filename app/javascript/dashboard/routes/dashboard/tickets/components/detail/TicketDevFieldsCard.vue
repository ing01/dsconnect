<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import { useMapGetter } from 'dashboard/composables/store';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';

// Os campos de texto do card do Jira que o desenvolvimento preenche. Ficam em
// `custom_attributes` do ticket (as mesmas chaves que a API de Integracao le e
// grava) - so' aparecem nas Mesas com o Modulo de Desenvolvimento ligado.
const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
});

const emit = defineEmits(['save']);

const { t } = useI18n();

const EDITOR_MENU_OPTIONS = [
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

const fields = computed(() => [
  {
    key: 'observacoes_dev',
    label: t('TICKET.DETAIL.DEV_FIELDS.OBSERVACOES_DEV'),
  },
  {
    key: 'observacoes_teste',
    label: t('TICKET.DETAIL.DEV_FIELDS.OBSERVACOES_TESTE'),
  },
  { key: 'documentacao', label: t('TICKET.DETAIL.DEV_FIELDS.DOCUMENTACAO') },
  { key: 'instrucoes', label: t('TICKET.DETAIL.DEV_FIELDS.INSTRUCOES') },
  { key: 'analise', label: t('TICKET.DETAIL.DEV_FIELDS.ANALISE') },
]);

const uiFlags = useMapGetter('tickets/getUIFlags');
const isSaving = computed(() => !!uiFlags.value.isUpdating);

const valueOf = key => props.ticket.custom_attributes?.[key] || '';
const hasValue = key => Boolean(valueOf(key).trim());
const rendered = key => new MessageFormatter(valueOf(key)).formattedMessage;

const editingKey = ref(null);
const draft = ref('');
// O que acabamos de mandar salvar - fecha a edicao quando o mesmo texto volta
// no ticket, em vez de depender do timing de `isSaving` (o mesmo cuidado de
// TicketDescriptionCard).
let justSaved = null;

const startEditing = key => {
  editingKey.value = key;
  draft.value = valueOf(key);
  justSaved = null;
};

const cancel = () => {
  editingKey.value = null;
  draft.value = '';
  justSaved = null;
};

const save = key => {
  if (draft.value === valueOf(key)) {
    cancel();
    return;
  }
  justSaved = { key, value: draft.value };
  emit('save', key, draft.value);
};

watch(
  () => props.ticket.custom_attributes,
  attributes => {
    if (!justSaved || editingKey.value !== justSaved.key) return;
    if ((attributes?.[justSaved.key] || '') === justSaved.value) cancel();
  },
  { deep: true }
);
</script>

<template>
  <div class="flex flex-col gap-2 min-w-0">
    <Accordion v-for="field in fields" :key="field.key" :title="field.label">
      <div class="flex flex-col gap-3 min-w-0">
        <template v-if="editingKey === field.key">
          <FullEditor
            v-model="draft"
            :editor-id="`ticket-dev-${field.key}-${ticket.id}`"
            :placeholder="t('TICKET.DETAIL.DEV_FIELDS.PLACEHOLDER')"
            :enabled-menu-options="EDITOR_MENU_OPTIONS"
            class="min-w-0"
          />
          <div class="flex justify-end gap-2">
            <Button
              variant="faded"
              color="slate"
              size="sm"
              :label="t('TICKET.DETAIL.DESCRIPTION.CANCEL')"
              @click="cancel"
            />
            <Button
              size="sm"
              :is-loading="isSaving"
              :label="t('TICKET.DETAIL.DESCRIPTION.SAVE')"
              @click="save(field.key)"
            />
          </div>
        </template>

        <template v-else>
          <div
            v-if="hasValue(field.key)"
            v-dompurify-html="rendered(field.key)"
            class="prose-sm max-w-none text-sm text-n-slate-12 break-words"
          />
          <p v-else class="m-0 text-sm text-n-slate-10">
            {{ t('TICKET.DETAIL.DEV_FIELDS.EMPTY') }}
          </p>
          <div v-if="canUpdate" class="flex justify-end">
            <Button
              variant="ghost"
              color="slate"
              size="xs"
              icon="i-lucide-pencil"
              :label="t('TICKET.DETAIL.DESCRIPTION.EDIT')"
              @click="startEditing(field.key)"
            />
          </div>
        </template>
      </div>
    </Accordion>
  </div>
</template>
