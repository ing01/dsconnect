<script setup>
/**
 * O chat com a equipe - item proprio do menu, sem relacao com ticket nenhum.
 *
 * Por baixo e uma Conversation de verdade, no MESMO Inbox que aparece na tela
 * de Conversas do atendente. Do lado do Portal isso e invisivel: o cliente so
 * ve uma lista de mensagens e uma caixa para responder, como qualquer chat.
 *
 * `GET /chat` devolve a sessao ABERTA (ou cria uma, na primeira vez) junto do
 * `pubsub_token` do `ContactInbox` para assinar o `RoomChannel` - o mesmo
 * mecanismo do Website Widget. Quando o atendente resolve a conversa, a
 * PROXIMA mensagem do cliente comeca uma sessao nova por baixo
 * (`Client::ChatConversationResolver`) - por isso toda resposta enviada
 * carrega `conversation_id`/`pubsub_token`, e esta tela se resubscreve
 * sozinha quando eles mudam, sem precisar recarregar a pagina.
 *
 * O envio e' OTIMISTA: a mensagem aparece na tela assim que o cliente clica
 * em enviar, antes da resposta do servidor chegar - e' um chat do proprio
 * sistema, e esperar o ciclo completo (requisicao + fila de automacao) so
 * para mostrar o que a pessoa acabou de escrever faria um chat interno
 * parecer mais lento que uma mensagem de WhatsApp de verdade.
 */
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { createConsumer } from '@rails/actioncable';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import {
  clientPushPermission,
  clientPushSupported,
  requestClientPushPermission,
} from 'dashboard/helper/clientPushHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import { AUDIO_FORMATS } from 'shared/constants/messages';
import TicketFileInput from 'dashboard/routes/dashboard/tickets/components/create/TicketFileInput.vue';
import ChatMessageBubble from 'dashboard/routes/client/components/ChatMessageBubble.vue';

const { t } = useI18n();
const router = useRouter();

const isLoading = ref(true);
const isSending = ref(false);
const messages = ref([]);
const draft = ref('');
const attachments = ref([]);
const conversationDisplayId = ref(null);
const pushPermission = ref('default');
const isRecordingAudio = ref(false);
const recordedAudioFile = ref(null);
const recordingAudioDurationText = ref('00:00');
const audioRecorderRef = ref(null);
const listRef = ref(null);
let consumer = null;
let subscription = null;
let tempIdCounter = 0;

const podeAtivarPush = computed(
  () => clientPushSupported() && pushPermission.value === 'default'
);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const rolarParaFinal = () => {
  nextTick(() => {
    if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight;
  });
};

// O eco da propria mensagem tambem chega pelo cable - o id evita mostra-la
// duas vezes quando o `create` e a assinatura respondem quase juntos.
const adicionar = mensagem => {
  if (messages.value.some(existing => existing.id === mensagem.id)) return;
  messages.value.push(mensagem);
  rolarParaFinal();
};

const desconectar = () => {
  subscription?.unsubscribe();
  consumer?.disconnect();
  subscription = null;
  consumer = null;
};

const assinar = pubsubToken => {
  desconectar();
  consumer = createConsumer();
  subscription = consumer.subscriptions.create(
    { channel: 'RoomChannel', pubsub_token: pubsubToken },
    {
      received: ({ event, data }) => {
        if (event !== 'message.created' || !data) return;
        if (data.conversation_id !== conversationDisplayId.value) return;
        // O cable manda o formato do painel (`sender_type`, `sender`,
        // `attachments`); aqui o formato e' o do endpoint de historico -
        // normaliza antes de empilhar.
        adicionar({
          id: data.id,
          content: data.content,
          content_type: data.content_type,
          from_you: data.sender_type === 'Contact',
          author_name: data.sender_type === 'User' ? data.sender?.name : null,
          created_at: data.created_at,
          attachments: data.attachments || [],
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
    rolarParaFinal();
  } catch {
    useAlert(t('CLIENT_AREA.CHAT.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const toggleAudioRecorder = () => {
  isRecordingAudio.value = !isRecordingAudio.value;
  if (!isRecordingAudio.value) recordedAudioFile.value = null;
};

const onRecordProgressChanged = duration => {
  recordingAudioDurationText.value = duration;
};

const onFinishRecorder = file => {
  recordedAudioFile.value = file?.file || null;
  isRecordingAudio.value = false;
};

const onRecordError = () => {
  isRecordingAudio.value = false;
  recordedAudioFile.value = null;
  useAlert(t('CLIENT_AREA.CHAT.RECORD_ERROR'));
};

const stopRecording = () => {
  audioRecorderRef.value?.stopRecording();
};

const podeEnviar = () =>
  !isSending.value &&
  (draft.value.trim().length > 0 ||
    attachments.value.length > 0 ||
    Boolean(recordedAudioFile.value));

const ativarPush = async () => {
  const concedida = await requestClientPushPermission();
  pushPermission.value = clientPushPermission();
  if (!concedida) useAlert(t('CLIENT_AREA.CHAT.PUSH_DENIED'));
};

const enviar = async () => {
  if (!podeEnviar()) return;

  const conteudo = draft.value.trim();
  const arquivosEnviados = attachments.value;
  const audioEnviado = recordedAudioFile.value;

  // Otimista: aparece na hora, com um id temporario que o eco do cable (ou a
  // resposta desta mesma chamada) substitui - sem isso o cliente veria o
  // proprio texto "sumir" por um instante e so voltar depois do round-trip.
  tempIdCounter += 1;
  const tempId = `pending-${tempIdCounter}`;
  const pendente = {
    id: tempId,
    content: conteudo || null,
    from_you: true,
    author_name: null,
    created_at: Math.floor(Date.now() / 1000),
    attachments: [],
    pending: true,
  };
  messages.value.push(pendente);
  rolarParaFinal();

  draft.value = '';
  attachments.value = [];
  recordedAudioFile.value = null;

  isSending.value = true;
  try {
    const { data } = await ClientAreaAPI.sendChatMessage({
      content: conteudo,
      attachments: arquivosEnviados,
      audio: audioEnviado,
    });

    if (
      data.conversation_id &&
      data.conversation_id !== conversationDisplayId.value
    ) {
      // A sessao anterior foi resolvida entre o carregamento da tela e este
      // envio - a mensagem que acabou de sair ja pertence a uma conversa
      // NOVA. Troca o rastreio e recomeca a lista so com ela.
      conversationDisplayId.value = data.conversation_id;
      messages.value = [data];
      if (data.pubsub_token) assinar(data.pubsub_token);
      return;
    }

    const index = messages.value.findIndex(item => item.id === tempId);
    if (index !== -1) {
      // O eco do proprio cable pode ter chegado ANTES desta resposta (mesmo
      // id real ja empilhado) - nesse caso so descarta o rascunho otimista,
      // sem duplicar a mensagem.
      const jaVeioPeloCable = messages.value.some(
        item => item.id === data.id && item.id !== tempId
      );
      if (jaVeioPeloCable) messages.value.splice(index, 1);
      else messages.value.splice(index, 1, data);
    } else {
      adicionar(data);
    }
  } catch {
    // A mensagem otimista fica marcada como falha em vez de desaparecer - o
    // cliente sabe o que tentou mandar e pode tentar de novo.
    const falha = messages.value.find(item => item.id === tempId);
    if (falha) falha.failed = true;
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

onMounted(() => {
  pushPermission.value = clientPushPermission();
  carregar();
});
onBeforeUnmount(desconectar);
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 gap-3 p-4 sm:p-6">
    <header class="flex flex-wrap items-start justify-between flex-shrink-0 gap-2">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.CHAT.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('CLIENT_AREA.CHAT.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Button
          faded
          slate
          size="sm"
          icon="i-lucide-history"
          :label="t('CLIENT_AREA.CHAT.HISTORY_LINK')"
          @click="router.push({ name: 'client_chat_history' })"
        />
        <Button
          v-if="podeAtivarPush"
          faded
          slate
          size="sm"
          icon="i-lucide-bell"
          :label="t('CLIENT_AREA.CHAT.ENABLE_PUSH')"
          @click="ativarPush"
        />
      </div>
    </header>

    <div
      v-if="isLoading"
      class="flex justify-center flex-1 py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <template v-else>
      <div
        ref="listRef"
        class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto"
      >
        <p
          v-if="!messages.length"
          class="py-8 m-0 text-sm text-center text-n-slate-11"
        >
          {{ t('CLIENT_AREA.CHAT.EMPTY') }}
        </p>

        <ChatMessageBubble
          v-for="mensagem in messages"
          :key="mensagem.id"
          :message="mensagem"
        />
      </div>

      <div class="flex flex-col flex-shrink-0 gap-2 pt-2 border-t border-n-weak">
        <AudioRecorder
          v-if="isRecordingAudio"
          ref="audioRecorderRef"
          :audio-record-format="AUDIO_FORMATS.OGG"
          class="border rounded-lg border-n-weak"
          @recorder-progress-changed="onRecordProgressChanged"
          @finish-record="onFinishRecorder"
          @record-error="onRecordError"
        />

        <div v-if="recordedAudioFile" class="flex items-center gap-2 text-xs text-n-slate-11">
          <Icon icon="i-lucide-mic" class="size-3.5" />
          {{ t('CLIENT_AREA.CHAT.RECORDED') }}
          <button
            type="button"
            class="underline"
            @click="recordedAudioFile = null"
          >
            {{ t('CLIENT_AREA.CHAT.RECORD_AGAIN') }}
          </button>
        </div>

        <div class="flex items-end gap-2">
          <TextArea
            v-model="draft"
            :placeholder="t('CLIENT_AREA.CHAT.PLACEHOLDER')"
            min-height="2.5rem"
            max-height="8rem"
            class="flex-1"
            @keydown.enter="aoPressionarEnter"
          />
          <Button
            v-if="!isRecordingAudio && !recordedAudioFile"
            faded
            slate
            size="sm"
            icon="i-lucide-mic"
            :title="t('CLIENT_AREA.CHAT.RECORD')"
            @click="toggleAudioRecorder"
          />
          <Button
            v-if="isRecordingAudio"
            ruby
            size="sm"
            icon="i-lucide-square"
            :title="t('CLIENT_AREA.CHAT.STOP_RECORDING', { duration: recordingAudioDurationText })"
            @click="stopRecording"
          />
          <Button
            icon="i-lucide-send"
            size="sm"
            :disabled="!podeEnviar()"
            :is-loading="isSending"
            @click="enviar"
          />
        </div>

        <TicketFileInput v-model="attachments" />
      </div>
    </template>
  </div>
</template>
