<script setup>
/**
 * As novidades dos chamados do cliente.
 *
 * Lista o que a EQUIPE escreveu nos chamados dele, do mais recente para o mais
 * antigo, com o caminho para o chamado. A resposta que ele mesmo enviou não
 * aparece - não é novidade para quem escreveu.
 *
 * Ainda não há estado de lido/não lido: não existe tabela de notificação para
 * contato, e criar uma antes de haver o que guardar seria estrutura à toa. Por
 * isso também não há contador no menu - um número que nunca zera é pior do que
 * número nenhum.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';

const { t } = useI18n();
const router = useRouter();

const isLoading = ref(true);
const items = ref([]);

const temItens = computed(() => items.value.length > 0);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const abrir = item => {
  router.push({
    name: 'client_ticket_detail',
    params: { ticketId: item.ticket_id },
  });
};

onMounted(async () => {
  try {
    const { data } = await ClientAreaAPI.notifications();
    items.value = data;
  } catch {
    useAlert(t('CLIENT_AREA.NOTIFICATIONS.ERROR'));
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col flex-1 h-full min-h-0 gap-4 p-4 min-w-0 sm:p-6">
    <div class="flex-shrink-0">
      <h1 class="m-0 text-xl font-medium text-n-slate-12">
        {{ t('CLIENT_AREA.NOTIFICATIONS.TITLE') }}
      </h1>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.NOTIFICATIONS.DESCRIPTION') }}
      </p>
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
      <li v-for="item in items" :key="item.id" class="list-none">
        <button
          type="button"
          class="flex flex-col w-full gap-1.5 p-3 text-left border rounded-lg cursor-pointer border-n-weak hover:border-n-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="abrir(item)"
        >
          <div class="flex flex-wrap items-center w-full gap-2 min-w-0">
            <span class="text-xs font-medium text-n-slate-10">
              #{{ item.ticket_display_id }}
            </span>
            <span class="flex-1 text-sm font-medium truncate text-n-slate-12">
              {{ item.ticket_title }}
            </span>
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
      </li>
    </ul>
  </div>
</template>
