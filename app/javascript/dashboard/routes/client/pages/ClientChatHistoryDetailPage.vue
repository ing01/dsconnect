<script setup>
/**
 * Uma sessao de chat ja encerrada, so leitura - sem composer, sem assinatura
 * de tempo real: uma conversa resolvida nao recebe mensagem nova.
 */
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ChatMessageBubble from 'dashboard/routes/client/components/ChatMessageBubble.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const isLoading = ref(true);
const messages = ref([]);

const voltar = () => router.push({ name: 'client_chat_history' });

onMounted(async () => {
  try {
    const { data } = await ClientAreaAPI.chatHistoryConversation(
      route.params.conversationId
    );
    messages.value = data.messages || [];
  } catch {
    useAlert(t('CLIENT_AREA.CHAT_HISTORY.ERROR'));
    router.replace({ name: 'client_chat_history' });
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 gap-3 p-4 sm:p-6">
    <header class="flex flex-shrink-0">
      <Button
        faded
        slate
        size="sm"
        icon="i-lucide-arrow-left"
        :label="t('CLIENT_AREA.CHAT_HISTORY.BACK')"
        @click="voltar"
      />
    </header>

    <div
      v-if="isLoading"
      class="flex justify-center flex-1 py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <div v-else class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto">
      <ChatMessageBubble
        v-for="mensagem in messages"
        :key="mensagem.id"
        :message="mensagem"
        :interactive="false"
      />
    </div>
  </div>
</template>
