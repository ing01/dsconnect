<script setup>
/**
 * As sessoes de chat ja ENCERRADAS - a de agora fica em `ClientChatPage`.
 * Uma sessao termina quando o atendente resolve a conversa; a proxima
 * mensagem do cliente comeca uma nova (ver `Client::ChatConversationResolver`
 * no servidor). Somente leitura: clicar abre o historico, sem reabrir nada.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const router = useRouter();

const isLoading = ref(true);
const conversas = ref([]);

const temItens = computed(() => conversas.value.length > 0);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const abrir = conversa =>
  router.push({
    name: 'client_chat_history_detail',
    params: { conversationId: conversa.id },
  });

const voltar = () => router.push({ name: 'client_chat' });

onMounted(async () => {
  try {
    const { data } = await ClientAreaAPI.chatHistory();
    conversas.value = data;
  } catch {
    useAlert(t('CLIENT_AREA.CHAT_HISTORY.ERROR'));
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 gap-4 p-4 sm:p-6">
    <header class="flex flex-wrap items-start gap-3 flex-shrink-0">
      <Button
        faded
        slate
        size="sm"
        icon="i-lucide-arrow-left"
        :label="t('CLIENT_AREA.CHAT_HISTORY.BACK')"
        @click="voltar"
      />
      <div>
        <h1 class="m-0 text-xl font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.CHAT_HISTORY.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CLIENT_AREA.CHAT_HISTORY.DESCRIPTION') }}
        </p>
      </div>
    </header>

    <div v-if="isLoading" class="flex justify-center py-16 text-n-slate-10">
      <Spinner />
    </div>

    <div
      v-else-if="!temItens"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
    >
      <Icon icon="i-lucide-message-circle-off" class="size-6 text-n-slate-10" />
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.CHAT_HISTORY.EMPTY') }}
      </p>
    </div>

    <ul v-else class="flex flex-col gap-2 m-0 overflow-y-auto">
      <li v-for="conversa in conversas" :key="conversa.id" class="list-none">
        <button
          type="button"
          class="flex flex-col w-full gap-1 p-3 text-left border rounded-lg cursor-pointer border-n-weak hover:border-n-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="abrir(conversa)"
        >
          <span class="text-xs text-n-slate-10">
            {{
              t('CLIENT_AREA.CHAT_HISTORY.RESOLVED_AT', {
                date: dataHora(conversa.resolved_at),
              })
            }}
          </span>
          <p class="m-0 text-sm text-n-slate-11 line-clamp-2">
            {{ conversa.preview || '—' }}
          </p>
        </button>
      </li>
    </ul>
  </div>
</template>
