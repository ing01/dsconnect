<script setup>
/**
 * As novidades dos chamados do cliente.
 *
 * Lista o que a EQUIPE escreveu nos chamados dele, do mais recente para o mais
 * antigo, com o caminho para o chamado. A resposta que ele mesmo enviou não
 * aparece - não é novidade para quem escreveu.
 *
 * Os itens continuam sintéticos (comunicação de ticket + mensagem de chat, sem
 * tabela de notificação própria) - o que persiste é só a CHAVE do que este
 * contato já abriu/removeu (`ClientNotificationDismissal`, por item_key), não
 * o item em si. Por isso abrir UM item já o remove daqui, e tem um botão para
 * remover sem abrir, e outro para limpar tudo que está visível agora.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useClientNotificationsCount } from 'dashboard/composables/useClientNotificationsCount';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();

const { count: notificationsCount } = useClientNotificationsCount();

const isLoading = ref(true);
const isClearing = ref(false);
const items = ref([]);

const temItens = computed(() => items.value.length > 0);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

// Dispara sem esperar resposta: a tela já reage removendo o item da lista -
// se a chamada falhar, o pior caso é o item reaparecer na próxima visita, não
// uma tela travada esperando o servidor.
const dispensar = item => {
  items.value = items.value.filter(i => i.id !== item.id);
  notificationsCount.value = items.value.length;
  ClientAreaAPI.dismissNotification(item.id).catch(() => {});
};

const abrir = item => {
  dispensar(item);
  if (item.type === 'chat') {
    router.push({ name: 'client_chat' });
    return;
  }
  router.push({
    name: 'client_ticket_detail',
    params: { ticketId: item.ticket_id },
  });
};

const removerSemAbrir = (item, event) => {
  event.stopPropagation();
  dispensar(item);
};

const limparTudo = async () => {
  if (isClearing.value) return;
  isClearing.value = true;
  try {
    await ClientAreaAPI.dismissAllNotifications();
    items.value = [];
    notificationsCount.value = 0;
  } catch {
    useAlert(t('CLIENT_AREA.NOTIFICATIONS.ERROR'));
  } finally {
    isClearing.value = false;
  }
};

onMounted(async () => {
  try {
    const { data } = await ClientAreaAPI.notifications();
    items.value = data;
    notificationsCount.value = data.length;
  } catch {
    useAlert(t('CLIENT_AREA.NOTIFICATIONS.ERROR'));
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col flex-1 h-full min-h-0 gap-4 p-4 min-w-0 sm:p-6">
    <div class="flex items-start justify-between flex-shrink-0 gap-2">
      <div>
        <h1 class="m-0 text-xl font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.NOTIFICATIONS.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CLIENT_AREA.NOTIFICATIONS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        v-if="temItens"
        variant="ghost"
        size="sm"
        :disabled="isClearing"
        @click="limparTudo"
      >
        {{ t('CLIENT_AREA.NOTIFICATIONS.CLEAR_ALL') }}
      </Button>
    </div>

    <div v-if="isLoading" class="flex justify-center py-16 text-n-slate-10">
      <Spinner />
    </div>

    <div
      v-else-if="!temItens"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
    >
      <Icon icon="i-lucide-bell-off" class="size-6 text-n-slate-10" />
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.NOTIFICATIONS.EMPTY') }}
      </p>
    </div>

    <ul v-else class="flex flex-col gap-2 m-0 overflow-y-auto">
      <li v-for="item in items" :key="item.id" class="relative list-none group">
        <button
          type="button"
          class="flex flex-col w-full gap-1.5 p-3 pr-10 text-left border rounded-lg cursor-pointer border-n-weak hover:border-n-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="abrir(item)"
        >
          <div class="flex flex-wrap items-center w-full gap-2 min-w-0">
            <span
              v-if="item.type === 'chat'"
              class="flex items-center gap-1 text-sm font-medium text-n-slate-12"
            >
              <Icon icon="i-lucide-message-circle" class="size-3.5" />
              {{ t('CLIENT_AREA.MENU.CHAT') }}
            </span>
            <template v-else>
              <span class="text-xs font-medium text-n-slate-10">
                #{{ item.ticket_display_id }}
              </span>
              <span class="flex-1 text-sm font-medium truncate text-n-slate-12">
                {{ item.ticket_title }}
              </span>
            </template>
            <Label
              v-if="item.closing"
              :label="t('CLIENT_AREA.DETAIL.CLOSING_NOTICE')"
              color="teal"
              size="small"
            />
            <span class="flex-shrink-0 text-xs text-n-slate-10">
              {{ dataHora(item.created_at) }}
            </span>
          </div>

          <p class="m-0 text-sm text-n-slate-11 line-clamp-2">
            {{ item.preview }}
          </p>

          <span v-if="item.author_name" class="text-xs text-n-slate-10">
            {{ item.author_name }}
          </span>
        </button>

        <button
          type="button"
          :aria-label="t('CLIENT_AREA.NOTIFICATIONS.REMOVE')"
          :title="t('CLIENT_AREA.NOTIFICATIONS.REMOVE')"
          class="absolute flex items-center justify-center rounded-md top-2 right-2 size-10 text-n-slate-10 hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="removerSemAbrir(item, $event)"
        >
          <Icon icon="i-lucide-x" class="size-5" />
        </button>
      </li>
    </ul>
  </div>
</template>
