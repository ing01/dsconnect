<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();

const body = ref('');
const isSending = ref(false);

// Messages that went TO the customer, kept apart from the internal thread.
const communications = computed(
  () => props.ticket.customer_communications || []
);
const email = computed(() => props.ticket.customer_email);

// The subject is not the agent's to write: the server titles the message with
// the ticket header so the customer recognises the thread. Shown here so what
// will be sent is visible.
const subject = computed(() => props.ticket.display_subject);

const canSend = computed(() => !!email.value && !!body.value.trim());

const STATUS_COLORS = { sent: 'teal', failed: 'ruby', pending: 'amber' };

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '—';

const send = async () => {
  if (!canSend.value || isSending.value) return;

  isSending.value = true;
  try {
    // Not a closing message: this is ordinary correspondence. Only the closing
    // flow marks one as such, and only that kind unlocks the close.
    await store.dispatch('tickets/sendCustomerCommunication', {
      ticketId: props.ticket.id,
      body: body.value,
      closing: false,
    });
    body.value = '';
  } catch (error) {
    useAlert(error?.response?.data?.error || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSending.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4 min-w-0">
    <!-- Nothing can be sent without an address, so the composer is replaced by
         the reason rather than failing on submit. -->
    <p
      v-if="!email"
      class="flex items-start gap-2 p-3 text-sm rounded-lg text-n-amber-11 bg-n-amber-3"
    >
      <Icon icon="i-lucide-circle-alert" class="flex-shrink-0 size-4 mt-0.5" />
      {{ t('TICKET.CLOSE.NO_CONTACT_EMAIL') }}
    </p>

    <template v-else>
      <div
        class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak min-w-0"
      >
        <p class="text-sm text-n-slate-11">
          {{ t('TICKET.CLOSE.TO') }}:
          <span class="text-n-slate-12">{{ email }}</span>
        </p>

        <p class="text-sm truncate text-n-slate-11" :title="subject">
          {{ t('TICKET.CLOSE.SUBJECT') }}:
          <span class="text-n-slate-12">{{ subject }}</span>
        </p>

        <FullEditor
          v-model="body"
          class="min-w-0 [&_.ProseMirror]:min-h-[8rem]"
          :placeholder="t('TICKET.CLOSE.MESSAGE_PLACEHOLDER')"
        />

        <div class="flex justify-end">
          <Button
            size="sm"
            :is-loading="isSending"
            :disabled="!canSend"
            :label="t('TICKET.COMMUNICATION.SEND')"
            @click="send"
          />
        </div>
      </div>
    </template>

    <div class="flex flex-col gap-2 min-w-0">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.COMMUNICATION.HISTORY') }}
      </h3>

      <p v-if="!communications.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.COMMUNICATION.EMPTY') }}
      </p>

      <ul v-else class="flex flex-col gap-2 min-w-0">
        <li
          v-for="communication in communications"
          :key="communication.id"
          class="flex flex-col gap-1 p-3 border rounded-lg border-n-weak min-w-0"
        >
          <div class="flex flex-wrap items-center gap-2 min-w-0">
            <span class="text-xs text-n-slate-10">
              {{
                formatDate(communication.sent_at || communication.created_at)
              }}
            </span>
            <span class="text-xs truncate text-n-slate-11">
              {{ `${communication.user_name} → ${communication.to_email}` }}
            </span>
            <WootLabel
              :label="
                t(
                  `TICKET.COMMUNICATION.STATUS.${communication.status.toUpperCase()}`
                )
              "
              :color="STATUS_COLORS[communication.status] || 'slate'"
              compact
            />
            <WootLabel
              v-if="communication.closing"
              :label="t('TICKET.COMMUNICATION.CLOSING')"
              color="blue"
              compact
            />
          </div>

          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ communication.subject }}
          </span>

          <!-- The body is the agent's own rich text, already sanitised on the
               way out; shown as plain text here to keep the list compact. -->
          <p class="text-sm truncate text-n-slate-11">
            {{ communication.body.replace(/<[^>]*>/g, ' ').trim() }}
          </p>

          <p v-if="communication.error_message" class="text-xs text-n-ruby-11">
            {{ communication.error_message }}
          </p>
        </li>
      </ul>
    </div>
  </div>
</template>
