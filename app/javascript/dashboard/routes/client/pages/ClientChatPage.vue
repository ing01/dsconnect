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
// Contato bloqueado nao usa o chat: o servidor responde 403 com o codigo
// `chat_blocked` (e o aviso com o telefone) em vez de abrir a conversa.
const isChatBlocked = ref(false);
const blockedMessage = ref('');
const isSending = ref(false);
// A falha do ultimo envio, em destaque ate a pessoa tentar de novo ou fechar:
// um aviso de 2,5 s no topo passava despercebido e a mensagem so' ficava
// "vermelha" sem dizer por que.
const sendError = ref(null);
const MAX_CONTENT_LENGTH = 150000;
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
        if (!data || data.conversation_id !== conversationDisplayId.value) {
          return;
        }

        if (event === 'message.created') {
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
        } else if (event === 'message.updated') {
          // So a transcricao de audio atualiza uma mensagem ja enviada - sem
          // isto, o texto so apareceria depois de recarregar a pagina.
          const existente = messages.value.find(
            mensagem => mensagem.id === data.id
          );
          if (existente) existente.attachments = data.attachments || [];
        }
      },
    }
  );
};

const marcarBloqueado = error => {
  if (error?.response?.data?.code !== 'chat_blocked') return false;
  isChatBlocked.value = true;
  blockedMessage.value =
    error.response.data.error || t('CLIENT_AREA.CHAT.BLOCKED');
  desconectar();
  return true;
};

const carregar = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClientAreaAPI.chat();
    messages.value = data.messages || [];
    conversationDisplayId.value = data.conversation_id;
    if (data.pubsub_token) assinar(data.pubsub_token);
    rolarParaFinal();
  } catch (error) {
    if (!marcarBloqueado(error)) useAlert(t('CLIENT_AREA.CHAT.ERROR'));
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

// Traduz a falha para um motivo que a pessoa entende e sabe como resolver.
const motivoDoErro = error => {
  const status = error?.response?.status;
  const dados = error?.response?.data;

  // Sem resposta nenhuma: a requisicao nem chegou ao servidor.
  if (!error?.response) return t('CLIENT_AREA.CHAT.ERRORS.OFFLINE');
  if (status === 401) return t('CLIENT_AREA.CHAT.ERRORS.SESSION_EXPIRED');
  if (status === 413) return t('CLIENT_AREA.CHAT.ERRORS.TOO_LARGE');
  if (status >= 500) return t('CLIENT_AREA.CHAT.ERRORS.SERVER');

  // 4xx com explicacao do servidor (conteudo longo demais, limite de anexos...).
  const doServidor = dados?.error || dados?.message;
  if (doServidor) return doServidor;

  return t('CLIENT_AREA.CHAT.ERRORS.UNKNOWN', { status: status || '?' });
};

const mostrarFalha = (tempId, error, payload) => {
  const falha = messages.value.find(item => item.id === tempId);
  if (falha) {
    falha.failed = true;
    falha.pending = false;
    // Guardado para "Tentar novamente" reenviar exatamente o que foi escrito.
    falha.retryPayload = payload;
  }
  const motivo = typeof error === 'string' ? error : motivoDoErro(error);
  sendError.value = { tempId, motivo };
  useAlert(t('CLIENT_AREA.CHAT.SEND_ERROR_TOAST', { motivo }));
};

const enviarMensagem = async ({ conteudo, arquivosEnviados, audioEnviado }) => {
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

  isSending.value = true;
  try {
    const { data } = await ClientAreaAPI.sendChatMessage({
      content: conteudo,
      attachments: arquivosEnviados,
      audio: audioEnviado,
    });
    sendError.value = null;

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
  } catch (error) {
    // Foi bloqueado com a tela ja aberta: troca o chat pelo aviso.
    if (marcarBloqueado(error)) return;

    // A mensagem otimista fica marcada como falha em vez de desaparecer - o
    // cliente sabe o que tentou mandar e pode tentar de novo - e o motivo
    // aparece numa faixa vermelha que nao some sozinha.
    mostrarFalha(tempId, error, { conteudo, arquivosEnviados, audioEnviado });
  } finally {
    isSending.value = false;
  }
};

const enviar = async () => {
  if (!podeEnviar()) return;

  const conteudo = draft.value.trim();
  const arquivosEnviados = attachments.value;
  const audioEnviado = recordedAudioFile.value;

  // Texto maior que o limite do servidor: avisa AGORA, com o numero, em vez de
  // esperar a recusa (e sem apagar o que a pessoa escreveu).
  if (conteudo.length > MAX_CONTENT_LENGTH) {
    sendError.value = {
      tempId: null,
      motivo: t('CLIENT_AREA.CHAT.ERRORS.TOO_LONG', {
        max: MAX_CONTENT_LENGTH.toLocaleString(),
        atual: conteudo.length.toLocaleString(),
      }),
    };
    return;
  }

  draft.value = '';
  attachments.value = [];
  recordedAudioFile.value = null;
  await enviarMensagem({ conteudo, arquivosEnviados, audioEnviado });
};

// Reenvia uma mensagem que falhou: sai a bolha vermelha e o mesmo conteudo
// volta a ser enviado (e, se der certo, o aviso some).
const tentarNovamente = async mensagem => {
  const payload = mensagem?.retryPayload;
  if (!payload || isSending.value) return;

  const index = messages.value.findIndex(item => item.id === mensagem.id);
  if (index !== -1) messages.value.splice(index, 1);
  sendError.value = null;
  await enviarMensagem(payload);
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
    <header
      class="flex flex-wrap items-start justify-between flex-shrink-0 gap-2"
    >
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

    <div
      v-else-if="isChatBlocked"
      role="alert"
      class="flex flex-col items-center gap-3 px-6 py-10 text-center border rounded-xl border-n-amber-6 bg-n-amber-2"
    >
      <Icon icon="i-lucide-phone-call" class="size-8 text-n-amber-11" />
      <p class="max-w-md m-0 text-sm font-medium text-n-amber-12">
        {{ blockedMessage }}
      </p>
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
          @retry="tentarNovamente(mensagem)"
        />
      </div>

      <div
        class="flex flex-col flex-shrink-0 gap-2 pt-2 border-t border-n-weak"
      >
        <!-- Falha de envio: faixa vermelha, com o motivo, que fica ate a pessoa
             tentar de novo ou fechar. -->
        <div
          v-if="sendError"
          role="alert"
          class="flex items-start gap-3 p-3 border-2 rounded-xl border-n-ruby-9 bg-n-ruby-3 send-error"
        >
          <Icon
            icon="i-lucide-triangle-alert"
            class="flex-shrink-0 mt-0.5 size-5 text-n-ruby-11"
          />
          <div class="flex flex-col flex-1 min-w-0 gap-1">
            <p class="m-0 text-sm font-semibold text-n-ruby-11">
              {{ t('CLIENT_AREA.CHAT.SEND_FAILED_TITLE') }}
            </p>
            <p class="m-0 text-sm break-words text-n-ruby-12">
              {{ sendError.motivo }}
            </p>
            <div class="flex flex-wrap gap-2 pt-1">
              <Button
                v-if="sendError.tempId"
                ruby
                size="sm"
                icon="i-lucide-rotate-cw"
                :label="t('CLIENT_AREA.CHAT.RETRY')"
                :is-loading="isSending"
                @click="
                  tentarNovamente(
                    messages.find(item => item.id === sendError.tempId)
                  )
                "
              />
              <Button
                faded
                slate
                size="sm"
                :label="t('CLIENT_AREA.CHAT.DISMISS')"
                @click="sendError = null"
              />
            </div>
          </div>
        </div>

        <div
          v-if="isRecordingAudio"
          class="flex flex-col gap-1 p-2 border rounded-lg border-n-weak"
        >
          <!-- A prova de que esta gravando de verdade: um ponto piscando +
               o tempo, sempre visivel - a onda do wavesurfer sozinha e' sutil
               demais (barras finas e escuras) para quem esta so de olho no
               botao, e sem isso a gravacao PARECE travada mesmo funcionando. -->
          <div class="flex items-center gap-2 text-xs text-n-ruby-11">
            <span class="relative flex size-2.5">
              <span
                class="absolute inline-flex w-full h-full rounded-full opacity-75 bg-n-ruby-9 animate-ping"
              />
              <span
                class="relative inline-flex rounded-full size-2.5 bg-n-ruby-9"
              />
            </span>
            <span class="font-medium">
              {{
                t('CLIENT_AREA.CHAT.RECORDING', {
                  duration: recordingAudioDurationText,
                })
              }}
            </span>
          </div>
          <AudioRecorder
            ref="audioRecorderRef"
            :audio-record-format="AUDIO_FORMATS.OGG"
            @recorder-progress-changed="onRecordProgressChanged"
            @finish-record="onFinishRecorder"
            @record-error="onRecordError"
          />
        </div>

        <div
          v-if="recordedAudioFile"
          class="flex items-center gap-2 text-xs text-n-slate-11"
        >
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
            :title="
              t('CLIENT_AREA.CHAT.STOP_RECORDING', {
                duration: recordingAudioDurationText,
              })
            "
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
