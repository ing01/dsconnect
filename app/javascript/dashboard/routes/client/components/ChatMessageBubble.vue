<script setup>
/**
 * Uma mensagem do chat, como bolha - reaproveitada pelo chat "de agora"
 * (`ClientChatPage`) e pelo histórico de sessões encerradas
 * (`ClientChatHistoryDetailPage`), para não duplicar o layout duas vezes.
 *
 * A pesquisa de satisfação (`content_type === 'input_csat'`) é a única parte
 * interativa - e só quando `interactive` é true e ainda não foi respondida.
 * No histórico (sempre uma sessão já encerrada) ela entra como `interactive:
 * false`: mostra que a pergunta existiu, sem reabrir a possibilidade de
 * responder uma conversa do passado.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  message: { type: Object, required: true },
  interactive: { type: Boolean, default: true },
});

const { t } = useI18n();

const rating = ref(0);
const feedback = ref('');
const isSubmitting = ref(false);
const justAnswered = ref(false);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const enviarCsat = async () => {
  if (!rating.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await ClientAreaAPI.submitChatCsat(props.message.id, {
      rating: rating.value,
      feedbackMessage: feedback.value.trim(),
    });
    justAnswered.value = true;
  } catch {
    useAlert(t('CLIENT_AREA.CHAT.CSAT.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col max-w-[80%] gap-1 px-3 py-2 rounded-lg"
    :class="[
      message.from_you
        ? 'self-end bg-n-brand text-white'
        : 'self-start bg-n-alpha-2 text-n-slate-12',
      message.pending ? 'opacity-60' : '',
      message.failed ? 'ring-2 ring-n-ruby-9' : '',
    ]"
  >
    <span
      v-if="!message.from_you && message.content_type !== 'input_csat'"
      class="text-xs font-medium text-n-slate-11"
    >
      {{ message.author_name || t('CLIENT_AREA.CHAT.TEAM') }}
    </span>

    <!-- Pesquisa de satisfacao: bolha propria, com estrelas em vez de texto
         corrido. -->
    <template v-if="message.content_type === 'input_csat'">
      <p class="m-0 text-sm whitespace-pre-line break-words">
        {{ message.content }}
      </p>

      <div
        v-if="interactive && !message.csat_answered && !justAnswered"
        class="flex flex-col gap-2 mt-1"
      >
        <div class="flex gap-1">
          <button
            v-for="valor in [1, 2, 3, 4, 5]"
            :key="valor"
            type="button"
            class="p-0.5"
            :aria-label="String(valor)"
            @click="rating = valor"
          >
            <Icon
              icon="i-lucide-star"
              class="size-5"
              :class="valor <= rating ? 'text-n-amber-9' : 'text-n-slate-8'"
            />
          </button>
        </div>
        <TextArea
          v-model="feedback"
          :placeholder="t('CLIENT_AREA.CHAT.CSAT.FEEDBACK_PLACEHOLDER')"
          min-height="2.5rem"
          max-height="6rem"
          class="w-full"
        />
        <Button
          size="sm"
          slate
          faded
          class="self-start"
          :disabled="!rating"
          :is-loading="isSubmitting"
          :label="t('CLIENT_AREA.CHAT.CSAT.SEND')"
          @click="enviarCsat"
        />
      </div>
      <p
        v-else-if="interactive"
        class="m-0 text-xs italic opacity-80"
      >
        {{ t('CLIENT_AREA.CHAT.CSAT.THANKS') }}
      </p>
    </template>

    <p
      v-else-if="message.content"
      class="m-0 text-sm whitespace-pre-line break-words"
    >
      {{ message.content }}
    </p>

    <div v-if="message.attachments?.length" class="flex flex-col gap-1.5">
      <template v-for="anexo in message.attachments" :key="anexo.id">
        <audio
          v-if="anexo.file_type === 'audio'"
          :src="anexo.data_url"
          controls
          class="max-w-full h-9"
        />
        <img
          v-else-if="anexo.file_type === 'image'"
          :src="anexo.data_url"
          class="max-w-full rounded-md max-h-48"
        />
        <a
          v-else
          :href="anexo.data_url"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-1.5 px-2 py-1 text-xs border rounded-md border-n-weak"
          :class="message.from_you ? 'text-white' : 'text-n-slate-11'"
        >
          <Icon icon="i-lucide-paperclip" class="size-3" />
          {{ t('CLIENT_AREA.CHAT.ATTACHMENT') }}
        </a>
      </template>
    </div>

    <span
      class="text-[11px] opacity-70"
      :class="message.from_you ? 'text-white' : 'text-n-slate-10'"
    >
      {{
        message.failed
          ? t('CLIENT_AREA.CHAT.SEND_ERROR')
          : dataHora(message.created_at)
      }}
    </span>
  </div>
</template>
