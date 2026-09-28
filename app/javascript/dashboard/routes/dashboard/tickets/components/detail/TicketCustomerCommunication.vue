<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
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
// Enviar por e-mail e o caso comum, entao ja vem marcado. Desmarcado, a
// mensagem e apenas REGISTRADA: ela continua aparecendo para o cliente na Area
// do Cliente, e serve para quando a equipe ja falou com ele por telefone ou
// WhatsApp e quer deixar isso no chamado.
const notificarCliente = ref(true);

// Messages that went TO the customer, kept apart from the internal thread.
const communications = computed(
  () => props.ticket.customer_communications || []
);
const email = computed(() => props.ticket.customer_email);

// O assunto nao aparece em lugar nenhum desta tela. Ele existe para o CLIENTE
// reconhecer a thread na caixa de entrada dele - aqui dentro, quem le ja esta
// no ticket, e repetir "#34 - [EMPRESA] | [Agente] | [titulo]" em cada linha so
// empurra a mensagem para baixo. Quem monta o assunto e o servidor
// (`ticket.display_subject`), e ele continua indo no cabecalho do e-mail.

const canSend = computed(() => !!email.value && !!body.value.trim());

// `skipped` nao e falha nem pendencia - e a mensagem que ninguem mandou por
// e-mail de proposito. Cinza justamente por isso: nada a corrigir.
const STATUS_COLORS = {
  sent: 'teal',
  skipped: 'slate',
  failed: 'ruby',
  pending: 'amber',
};

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
      notifyCustomer: notificarCliente.value,
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

        <FullEditor
          v-model="body"
          class="min-w-0 [&_.ProseMirror]:min-h-[8rem]"
          :placeholder="t('TICKET.CLOSE.MESSAGE_PLACEHOLDER')"
        />

        <!-- A escolha fica JUNTO do botao, e nao no topo do bloco: e a ultima
             coisa decidida antes de enviar, e o rotulo do botao muda com ela. -->
        <div class="flex flex-wrap items-center justify-between gap-3 min-w-0">
          <label class="flex items-start gap-2 cursor-pointer min-w-0">
            <Checkbox v-model="notificarCliente" class="mt-0.5 flex-shrink-0" />
            <span class="flex flex-col gap-0.5 min-w-0">
              <span class="text-sm text-n-slate-12">
                {{ t('TICKET.COMMUNICATION.NOTIFY') }}
              </span>
              <span v-if="!notificarCliente" class="text-xs text-n-slate-10">
                {{ t('TICKET.COMMUNICATION.NOTIFY_HINT') }}
              </span>
            </span>
          </label>

          <Button
            size="sm"
            class="flex-shrink-0"
            :is-loading="isSending"
            :disabled="!canSend"
            :label="
              notificarCliente
                ? t('TICKET.COMMUNICATION.SEND')
                : t('TICKET.COMMUNICATION.REGISTER')
            "
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
            <!-- A conversa tem dois sentidos: o que a equipe enviou ao cliente
                 e o que ele respondeu pela Area do Cliente. Sem distinguir, a
                 resposta recebida apareceria como "null → null". -->
            <span class="text-xs truncate text-n-slate-11">
              {{
                communication.direction === 'inbound'
                  ? t('TICKET.COMMUNICATION.FROM_CUSTOMER', {
                      name:
                        communication.author_name || communication.contact_name,
                    })
                  : `${communication.user_name} → ${communication.to_email}`
              }}
            </span>
            <WootLabel
              v-if="communication.direction !== 'inbound'"
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

          <!-- O corpo e o texto do agente, ja higienizado na saida; mostrado
               como texto puro para a lista ficar compacta. Sem o assunto acima:
               ele e igual em todas as linhas e nao distingue uma da outra. Por
               isso o corpo herda o destaque que era do titulo - e ele que diz
               qual comunicacao e qual. Segue em UMA linha: a lista e indice. -->
          <p class="text-sm truncate text-n-slate-12">
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
