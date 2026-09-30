<script setup>
/**
 * O chat com a equipe - item proprio do menu, sem relacao com ticket nenhum.
 *
 * Por baixo e uma Conversation de verdade, no MESMO Inbox que aparece na tela
 * de Conversas do atendente. Do lado do Portal isso e invisivel: o cliente so
 * ve uma lista de mensagens e uma caixa para responder, como qualquer chat.
 *
 * `GET /chat` cria a conversa na primeira vez (ou devolve a que ja existe) e
 * devolve o `pubsub_token` do `ContactInbox` - o mesmo mecanismo que o
 * Website Widget ja usa para assinar o `RoomChannel` sem precisar de canal
 * novo nenhum.
 */
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { createConsumer } from '@rails/actioncable';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();

const isLoading = ref(true);
const isSending = ref(false);
const messages = ref([]);
const draft = ref('');
const conversationDisplayId = ref(null);
let consumer = null;
let subscription = null;

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

// O eco da propria mensagem tambem chega pelo cable - o id evita mostra-la
// duas vezes quando o `create` e a assinatura respondem quase juntos.
const adicionar = mensagem => {
  if (messages.value.some(existing => existing.id === mensagem.id)) return;
  messages.value.push(mensagem);
};

const assinar = pubsubToken => {
  consumer = createConsumer();
  subscription = consumer.subscriptions.create(
    { channel: 'RoomChannel', pubsub_token: pubsubToken },
    {
      received: ({ event, data }) => {
        if (event !== 'message.created' || !data) return;
        if (data.conversation_id !== conversationDisplayId.value) return;
        // O cable manda o formato do painel (`sender_type`, `sender`); aqui o
        // formato e o do endpoint de historico - normaliza antes de empilhar.
        adicionar({
          id: data.id,
          content: data.content,
          from_you: data.sender_type === 'Contact',
          author_name: data.sender_type === 'User' ? data.sender?.name : null,
          created_at: data.created_at,
        });
      },
    }
  );
};

const carregar = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClientAreaAPI.chat();
    messages.value = data.messages || [];
    conversationDisplayId.value = data.conversation_id;
    if (data.pubsub_token) assinar(data.pubsub_token);
  } catch {
    useAlert(t('CLIENT_AREA.CHAT.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const podeEnviar = () => draft.value.trim().length > 0 && !isSending.value;

const enviar = async () => {
  if (!podeEnviar()) return;

  const conteudo = draft.value.trim();
  isSending.value = true;
  try {
    const { data } = await ClientAreaAPI.sendChatMessage(conteudo);
    adicionar(data);
    draft.value = '';
  } catch {
    useAlert(t('CLIENT_AREA.CHAT.SEND_ERROR'));
  } finally {
    isSending.value = false;
  }
};

const aoPressionarEnter = event => {
  if (event.shiftKey) return;
  event.preventDefault();
  enviar();
};

onMounted(carregar);
onBeforeUnmount(() => {
  subscription?.unsubscribe();
  consumer?.disconnect();
});
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 gap-3 p-4 sm:p-6">
    <header class="flex-shrink-0">
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('CLIENT_AREA.CHAT.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.CHAT.DESCRIPTION') }}
      </p>
    </header>

    <div
      v-if="isLoading"
      class="flex justify-center flex-1 py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <template v-else>
      <div class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto">
        <p
          v-if="!messages.length"
          class="py-8 m-0 text-sm text-center text-n-slate-11"
        >
          {{ t('CLIENT_AREA.CHAT.EMPTY') }}
        </p>

        <div
          v-for="mensagem in messages"
          :key="mensagem.id"
          class="flex flex-col max-w-[80%] gap-1 px-3 py-2 rounded-lg"
          :class="
            mensagem.from_you
              ? 'self-end bg-n-brand text-white'
              : 'self-start bg-n-alpha-2 text-n-slate-12'
          "
        >
          <span
            v-if="!mensagem.from_you"
            class="text-xs font-medium text-n-slate-11"
          >
            {{ mensagem.author_name || t('CLIENT_AREA.CHAT.TEAM') }}
          </span>
          <p class="m-0 text-sm whitespace-pre-line break-words">
            {{ mensagem.content }}
          </p>
          <span
            class="text-[11px] opacity-70"
            :class="mensagem.from_you ? 'text-white' : 'text-n-slate-10'"
          >
            {{ dataHora(mensagem.created_at) }}
          </span>
        </div>
      </div>

      <div
        class="flex items-end flex-shrink-0 gap-2 pt-2 border-t border-n-weak"
      >
        <TextArea
          v-model="draft"
          :placeholder="t('CLIENT_AREA.CHAT.PLACEHOLDER')"
          min-height="2.5rem"
          max-height="8rem"
          class="flex-1"
          @keydown.enter="aoPressionarEnter"
        />
        <Button
          icon="i-lucide-send"
          size="sm"
          :disabled="!podeEnviar()"
          :is-loading="isSending"
          @click="enviar"
        />
      </div>
    </template>
  </div>
</template>
