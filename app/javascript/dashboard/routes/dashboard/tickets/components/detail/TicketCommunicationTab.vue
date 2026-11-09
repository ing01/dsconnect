<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import ContactAPI from 'dashboard/api/contacts';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import TicketComments from '../TicketComments.vue';
import TicketCustomerCommunication from './TicketCustomerCommunication.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

// Depois de abrir a conversa, a pagina relê o ticket: e' assim que ela aparece em
// "Conversas vinculadas" sem recarregar.
const emit = defineEmits(['refresh']);

const { t } = useI18n();
const route = useRoute();
const store = useStore();

// A conversa e' com o SOLICITANTE do ticket. Sem solicitante nao ha com quem abrir.
const requesterId = computed(() => props.ticket.contact?.id || null);

// Quem ja atende o solicitante (conversa aberta com OUTRO agente), ou null. O servidor ja
// recusa abrir outra conversa com ele; isto so' antecipa o motivo - o aviso aparece quando a
// aba abre, e nao so' depois de a pessoa preencher e enviar o formulario. A consulta usa a
// MESMA regra do bloqueio (Conversations::ContactAttendance), inclusive para conversa de
// caixa a que a pessoa nao tem acesso.
const attendance = ref(null);

const loadAttendance = async () => {
  const id = requesterId.value;
  attendance.value = null;
  if (!id) return;

  try {
    const { data } = await ContactAPI.getAttendance(id);
    // Uma resposta atrasada de outro solicitante nao pode avisar do cliente errado.
    if (id === requesterId.value && data.in_attendance) attendance.value = data;
  } catch {
    // Sem o aviso a tela segue normal: o servidor continua barrando a abertura.
  }
};

// O formulario de nova conversa le o contato (e as caixas de entrada dele) da store de
// contatos, que a pagina do ticket nao carrega sozinha.
watch(
  requesterId,
  id => {
    if (id) store.dispatch('contacts/show', { id });
    loadAttendance();
  },
  { immediate: true }
);

// Depois de criar a conversa o cliente passa a estar em atendimento: a pagina relê o ticket e
// o aviso e' refeito.
const onCreated = () => {
  emit('refresh');
  loadAttendance();
};

// Two clearly separate audiences: the team's own thread, and what is sent to
// the customer. They are never mixed.
const channel = ref('internal');
const router = useRouter();

// Os status que a conversa pode ter; qualquer outro aparece como veio.
const KNOWN_STATUSES = ['open', 'resolved', 'pending', 'snoozed'];

const statusLabel = status =>
  KNOWN_STATUSES.includes(status)
    ? t(`TICKET.DETAIL.CONVERSATION_STATUS.${status.toUpperCase()}`)
    : status;

// Quem atende a conversa - ou atendeu, quando ja foi resolvida. A conversa guarda so' o
// responsavel atual, e numa conversa encerrada e' quem a atendeu (e quase sempre quem a
// encerrou).
const attendantLabel = conversation => {
  if (!conversation.assignee_name) {
    return t('TICKET.DETAIL.CONVERSATION_NO_ASSIGNEE');
  }
  return t(
    conversation.status === 'resolved'
      ? 'TICKET.DETAIL.CONVERSATION_ATTENDED_BY'
      : 'TICKET.DETAIL.CONVERSATION_ASSIGNEE',
    { name: conversation.assignee_name }
  );
};

const formatDateTime = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '';

// Navigates by `display_id`: the dashboard route and the conversations API both
// resolve on it, so using the primary key opens the wrong conversation.
const openConversation = conversation => {
  router.push(
    frontendURL(
      `accounts/${route.params.accountId}/conversations/${conversation.display_id}`
    )
  );
};
</script>

<template>
  <div class="flex flex-col gap-4 w-full min-w-0">
    <!-- Internal notes never leave the account; customer messages are e-mails.
         The tabs make which one you are writing unmistakable. -->
    <div
      class="flex gap-1 p-1 rounded-lg bg-n-alpha-2 w-fit max-w-full overflow-x-auto"
    >
      <button
        v-for="value in ['internal', 'customer']"
        :key="value"
        type="button"
        :data-channel="value"
        class="px-3 py-1.5 text-sm rounded-md whitespace-nowrap transition-colors"
        :class="
          channel === value
            ? 'bg-n-solid-1 text-n-slate-12 font-medium'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="channel = value"
      >
        {{ t(`TICKET.COMMUNICATION.TAB.${value.toUpperCase()}`) }}
      </button>
    </div>

    <TicketCustomerCommunication
      v-if="channel === 'customer'"
      :ticket="ticket"
    />

    <template v-else>
      <section
        class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
      >
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DETAIL.LINKED_CONVERSATIONS') }}
          </h2>

          <!-- Abre o formulario de nova conversa ja no solicitante do ticket; o
               servidor vincula a conversa a ESTE ticket na mesma criacao. -->
          <ComposeConversation
            v-if="requesterId && !attendance"
            :contact-id="String(requesterId)"
            :ticket-id="ticket.id"
            @created="onCreated"
          >
            <template #trigger>
              <Button
                data-testid="open-conversation"
                icon="i-lucide-message-square-plus"
                size="sm"
                :label="t('TICKET.DETAIL.OPEN_CONVERSATION')"
              />
            </template>
          </ComposeConversation>
          <span v-else-if="!requesterId" class="text-xs text-n-slate-10">
            {{ t('TICKET.DETAIL.OPEN_CONVERSATION_NO_REQUESTER') }}
          </span>
        </div>

        <!-- O cliente ja esta com um chat em andamento com outro agente: o servidor nao
             deixa abrir outra conversa, entao em vez do botao a tela diz com QUEM ele esta
             e leva para essa conversa. -->
        <div
          v-if="attendance"
          role="alert"
          data-testid="in-attendance"
          class="flex flex-col gap-2 p-3 text-sm border rounded-lg border-n-amber-4 bg-n-amber-2"
        >
          <span class="flex items-start gap-2 text-n-amber-11">
            <Icon
              icon="i-lucide-triangle-alert"
              class="flex-shrink-0 mt-0.5 size-4"
            />
            {{
              t('TICKET.DETAIL.IN_ATTENDANCE', {
                agent: attendance.assignee_name,
                id: attendance.conversation_id,
              })
            }}
          </span>
          <button
            type="button"
            data-testid="open-attendance"
            class="self-start text-sm font-medium text-n-brand hover:underline"
            @click="openConversation({ display_id: attendance.conversation_id })"
          >
            {{
              t('TICKET.DETAIL.IN_ATTENDANCE_OPEN', {
                id: attendance.conversation_id,
              })
            }}
          </button>
        </div>

        <p
          v-if="!(ticket.conversations || []).length"
          class="text-sm text-n-slate-10"
        >
          {{ t('TICKET.DETAIL.NO_CONVERSATIONS') }}
        </p>

        <ul v-else class="flex flex-col gap-1">
          <li
            v-for="conversation in ticket.conversations"
            :key="conversation.id"
          >
            <button
              type="button"
              class="flex flex-col w-full gap-1 px-2 py-2 text-left rounded-lg hover:bg-n-alpha-2 transition-colors min-w-0"
              @click="openConversation(conversation)"
            >
              <span class="flex items-center gap-2 min-w-0">
                <Icon
                  icon="i-lucide-messages-square"
                  class="size-4 text-n-slate-11 flex-shrink-0"
                />
                <span class="text-sm text-n-slate-12 truncate">
                  #{{ conversation.display_id }}
                  <template v-if="conversation.contact_name">
                    — {{ conversation.contact_name }}
                  </template>
                </span>
              </span>
              <span
                class="flex flex-wrap items-center gap-2 text-xs text-n-slate-10"
              >
                <span v-if="conversation.inbox_name">
                  {{ conversation.inbox_name }}
                </span>
                <span v-if="conversation.status">{{
                  statusLabel(conversation.status)
                }}</span>
                <span
                  data-testid="conversation-attendant"
                  class="flex items-center gap-1"
                >
                  <Icon icon="i-lucide-user-round" class="size-3" />
                  {{ attendantLabel(conversation) }}
                </span>
                <span v-if="conversation.last_activity_at">
                  {{ formatDateTime(conversation.last_activity_at) }}
                </span>
              </span>
            </button>
          </li>
        </ul>
      </section>

      <!-- Internal comments stay visibly separate from the customer-facing
         conversation above: different audience, different place. -->
      <section class="rounded-xl border border-n-weak p-4 min-w-0">
        <TicketComments :ticket-id="ticket.id" />
      </section>
    </template>
  </div>
</template>
