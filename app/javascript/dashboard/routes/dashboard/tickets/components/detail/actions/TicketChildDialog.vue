<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);

const selected = ref({});

// Which options exist, and what each one actually depends on IN THIS MODEL -
// not in the reference screenshot. `assignee` genuinely requires `team`,
// because a Responsavel is only valid inside the Mesa the ticket sits in.
// Everything the reference hangs off "Cliente" has no such dependency here:
// Empresa is a real association on our Ticket and the Mesa is independent of it.
//
// There is deliberately no "Solicitante" option: a Ticket has no contact FK -
// the Solicitante is derived from the earliest linked Conversation. Copying it
// on its own is not expressible, so it travels with `conversations` instead of
// being offered as a checkbox that would do nothing.
const OPTIONS = [
  { key: 'title', requires: null },
  { key: 'description', requires: null },
  { key: 'company', requires: null },
  { key: 'team', requires: null },
  { key: 'assignee', requires: 'team' },
  { key: 'followers', requires: null },
  { key: 'attachments', requires: null },
  { key: 'comments', requires: null },
  { key: 'conversations', requires: null },
];

// An option is offered only when the parent has something to copy. Ticking
// "Empresa" on a ticket with no Empresa would promise a copy that cannot happen.
const hasSource = key =>
  ({
    title: !!props.ticket.title,
    description: !!props.ticket.description,
    company: !!props.ticket.company_id,
    team: !!props.ticket.team_id,
    assignee: !!props.ticket.assignee_id,
    followers: !!(props.ticket.followers || []).length,
    attachments: !!(props.ticket.attachments || []).length,
    comments: true,
    conversations: !!(props.ticket.conversations || []).length,
  })[key];

const isEnabled = option => {
  if (!hasSource(option.key)) return false;
  return !option.requires || !!selected.value[option.requires];
};

const availableOptions = computed(() => OPTIONS.filter(isEnabled));

const allSelected = computed(
  () =>
    availableOptions.value.length > 0 &&
    availableOptions.value.every(option => selected.value[option.key])
);

// Selecting all is applied repeatedly until it settles: ticking `team` makes
// `assignee` available, which was not in the list on the first pass.
const toggleAll = () => {
  if (allSelected.value) {
    selected.value = {};
    return;
  }
  const next = { ...selected.value };
  // One pass over the options available right now, returning whether it added
  // anything. Ticking `team` makes `assignee` available, so the loop repeats
  // until a pass adds nothing new.
  const tickAvailable = () =>
    OPTIONS.filter(option => hasSource(option.key))
      .filter(option => !option.requires || next[option.requires])
      .filter(option => !next[option.key])
      .map(option => {
        next[option.key] = true;
        return option.key;
      }).length > 0;

  while (tickAvailable());
  selected.value = next;
};

// Unticking a parent option has to drop what depended on it, otherwise the
// payload would ask to copy a Responsavel without the Mesa that validates them.
const toggle = key => {
  const next = { ...selected.value, [key]: !selected.value[key] };
  if (!next[key]) {
    OPTIONS.filter(option => option.requires === key).forEach(option => {
      delete next[option.key];
    });
  }
  selected.value = next;
};

const isDisabled = option =>
  !!option.requires && !selected.value[option.requires];

const visibleOptions = computed(() =>
  OPTIONS.filter(option => hasSource(option.key))
);

const open = () => {
  selected.value = {};
  dialogRef.value?.open();
};

const handleConfirm = () => {
  emit('submit', {
    options: { ...selected.value },
    // The child needs a title even when the parent's is not copied; the server
    // derives one from the parent rather than rejecting the request.
    ticket: {},
  });
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    overflow-y-auto
    :title="t('TICKET.ACTIONS.CHILD_DIALOG.TITLE')"
    :description="t('TICKET.ACTIONS.CHILD_DIALOG.DESCRIPTION')"
    :confirm-button-label="t('TICKET.ACTIONS.CHILD_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col min-w-0 max-h-[60vh] overflow-y-auto">
      <label
        class="flex items-center gap-2 py-2 border-b cursor-pointer border-n-weak"
      >
        <input
          type="checkbox"
          class="m-0"
          :checked="allSelected"
          @change="toggleAll"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.CHILD_DIALOG.SELECT_ALL') }}
        </span>
      </label>

      <label
        v-for="option in visibleOptions"
        :key="option.key"
        class="flex items-start gap-2 py-2 min-w-0"
        :class="
          isDisabled(option)
            ? 'cursor-not-allowed opacity-50'
            : 'cursor-pointer'
        "
        :style="option.requires ? 'padding-left: 1.5rem' : ''"
      >
        <input
          type="checkbox"
          class="m-0 mt-0.5"
          :checked="!!selected[option.key]"
          :disabled="isDisabled(option)"
          @change="toggle(option.key)"
        />
        <span class="flex flex-col min-w-0">
          <span class="text-sm text-n-slate-12">
            {{
              t(
                `TICKET.ACTIONS.CHILD_DIALOG.OPTIONS.${option.key.toUpperCase()}`
              )
            }}
          </span>
          <span v-if="option.requires" class="text-xs text-n-slate-10">
            {{ t('TICKET.ACTIONS.CHILD_DIALOG.REQUIRES_TEAM') }}
          </span>
        </span>
      </label>

      <p v-if="!visibleOptions.length" class="py-4 text-sm text-n-slate-10">
        {{ t('TICKET.ACTIONS.CHILD_DIALOG.NOTHING_TO_COPY') }}
      </p>
    </div>
  </Dialog>
</template>
