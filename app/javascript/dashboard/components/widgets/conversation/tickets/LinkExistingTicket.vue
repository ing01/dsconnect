<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import TicketsAPI from 'dashboard/api/tickets';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TicketPicker from 'dashboard/routes/dashboard/tickets/components/detail/actions/TicketPicker.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  // The Empresa the conversation's contact belongs to. Only that company's
  // tickets may be linked, so without one there is nothing to offer.
  companyId: { type: [Number, String], default: null },
  companyName: { type: String, default: '' },
  // A conversation already linked to a ticket must not be offered it again -
  // the join row is unique, and re-linking would just fail.
  linkedTicketIds: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'linked']);

const { t } = useI18n();

const ticketId = ref(null);
const isSubmitting = ref(false);

const hasCompany = computed(() => !!props.companyId);

const link = async () => {
  if (!ticketId.value) return;

  isSubmitting.value = true;
  try {
    // Adds a link; it never replaces one. A ticket carries many conversations
    // and this conversation keeps whatever it was already linked to.
    await TicketsAPI.linkConversation(ticketId.value, props.conversationId);
    emit('linked');
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="t('TICKET.CONVERSATION_PANEL.LINK_EXISTING')"
    />
    <div class="flex flex-col gap-4 px-8 pb-8">
      <p v-if="companyName" class="text-sm text-n-slate-11">
        {{
          t('TICKET.CONVERSATION_PANEL.LINK_COMPANY_SCOPE', {
            company: companyName,
          })
        }}
      </p>

      <!-- No Empresa on the contact means no list to scope: say so instead of
           offering every ticket in the account. -->
      <p v-if="!hasCompany" class="text-sm text-n-slate-11">
        {{ t('TICKET.CONVERSATION_PANEL.LINK_NEEDS_COMPANY') }}
      </p>

      <TicketPicker
        v-else
        v-model="ticketId"
        open-only
        :company-id="companyId"
        :exclude-ids="linkedTicketIds"
        :placeholder="t('TICKET.CONVERSATION_PANEL.SEARCH_PLACEHOLDER')"
      />

      <div class="flex items-center justify-end gap-2">
        <NextButton
          faded
          slate
          type="button"
          :label="t('TICKET.FORM.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="button"
          :is-loading="isSubmitting"
          :disabled="!ticketId"
          :label="t('TICKET.CONVERSATION_PANEL.LINK_ACTION')"
          @click="link"
        />
      </div>
    </div>
  </div>
</template>
