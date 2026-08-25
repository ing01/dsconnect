<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import TicketCreateForm from './TicketCreateForm.vue';

const props = defineProps({
  // What the caller already knows; see TicketCreateForm.
  context: { type: Object, default: () => ({}) },
  // Links the chat the ticket is being opened from. The Conversation is
  // related, never duplicated - no message is copied and no new Conversation
  // is created.
  conversationId: { type: [Number, String], default: null },
  // Set when opening a child: the request goes to `create_child`, which also
  // carries the copies the form cannot express (files, comments, conversations,
  // followers).
  parentId: { type: [Number, String], default: null },
  copyOptions: { type: Object, default: null },
  allowCreateAnother: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const store = useStore();

const isSubmitting = ref(false);

const formContext = computed(() => ({
  ...props.context,
  parentId: props.parentId ?? props.context.parentId ?? null,
}));

const submit = async ({ ticket, files, createAnother, onCreated }) => {
  if (isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const created = await store.dispatch('tickets/createTicketWithContext', {
      ticket,
      files,
      conversationId: props.conversationId,
      parentId: props.parentId,
      options: props.copyOptions,
    });

    // The Kanban reflects the new ticket without waiting for the realtime
    // round-trip.
    store.dispatch('ticketColumns/applyRealtimeTicket', created);
    useAlert(t('TICKET.CREATE.CREATED', { number: created.display_id }));

    // "Criar e abrir outro" keeps the form open with the reusable context; the
    // caller is told either way so it can navigate, or resolve the chat.
    if (createAnother) {
      onCreated?.();
      emit('created', { ticket: created, keepOpen: true });
      return;
    }

    emit('created', { ticket: created, keepOpen: false });
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <!-- The modal container is what scrolls (see Modal.vue); the title sticks to
       the top of it and the form's buttons stick to the bottom, so both stay
       reachable on a short viewport without adding a nested overflow that would
       clip the searchable dropdowns. -->
  <div class="flex flex-col h-auto min-w-0">
    <woot-modal-header
      class="sticky top-0 z-10 bg-n-alpha-3 backdrop-blur-[4px]"
      :header-title="t('TICKET.CREATE.TITLE')"
    />
    <div class="px-8 pb-6 min-w-0">
      <TicketCreateForm
        :context="formContext"
        :is-submitting="isSubmitting"
        :allow-create-another="allowCreateAnother"
        @submit="submit"
        @cancel="emit('close')"
      />
    </div>
  </div>
</template>
