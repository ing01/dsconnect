<script setup>
/**
 * Os tickets impedidos DE QUEM ESTA OLHANDO.
 *
 * Nao reaproveita a Busca detalhada: aquela tela existe para procurar em tudo -
 * doze filtros, ordenacao, paginacao, exportacao. Aqui a pergunta e outra e bem
 * mais estreita ("o que esta travado comigo?"), e todo aquele maquinario so
 * atrapalha a resposta.
 *
 * Busca pela API direto, com estado local, em vez de `tickets/fetchTickets`: a
 * action grava em `tickets.records`, a mesma lista que a Busca detalhada usa -
 * abrir este modal apagaria o resultado dela.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import TicketsAPI from 'dashboard/api/tickets';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const router = useRouter();

const currentAccountId = useMapGetter('getCurrentAccountId');

const tickets = ref([]);
const isLoading = ref(true);

const temAlgum = computed(() => tickets.value.length > 0);

const dataHora = segundos =>
  segundos
    ? new Date(segundos * 1000).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '';

// Mesa e Estagio dizem onde o ticket parou; juntos, numa linha so.
const localizacao = ticket =>
  [ticket.team_name, ticket.ticket_column_name].filter(Boolean).join(' · ');

const abrir = ticket => {
  emit('close');
  router.push(
    frontendURL(`accounts/${currentAccountId.value}/tickets/${ticket.id}`)
  );
};

// `mine` e `blocked` ja existem no TicketFinder; juntos sao exatamente esta
// tela. Impedido ha mais tempo vem primeiro: e o que precisa de atencao.
onMounted(async () => {
  try {
    const { data } = await TicketsAPI.get({
      blocked: true,
      mine: true,
      per_page: 50,
    });
    tickets.value = [...(data?.payload || [])].sort(
      (a, b) => (a.blocked_at || 0) - (b.blocked_at || 0)
    );
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="t('TICKET.IMPEDIMENT.LIST_TITLE')"
      :header-content="t('TICKET.IMPEDIMENT.LIST_DESCRIPTION')"
    />

    <div class="flex flex-col gap-3 px-8 pt-2 pb-8">
      <div v-if="isLoading" class="flex justify-center py-10 text-n-slate-10">
        <Spinner />
      </div>

      <div
        v-else-if="!temAlgum"
        class="flex flex-col items-center gap-2 py-10 text-center"
      >
        <Icon icon="i-lucide-circle-check" class="size-6 text-n-teal-11" />
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('TICKET.IMPEDIMENT.LIST_EMPTY') }}
        </p>
      </div>

      <ul v-else class="flex flex-col gap-2 m-0 overflow-y-auto max-h-[60vh]">
        <li v-for="ticket in tickets" :key="ticket.id" class="list-none">
          <button
            class="flex flex-col w-full gap-1.5 p-3 text-left border rounded-lg cursor-pointer border-n-weak hover:border-n-amber-6 hover:bg-n-alpha-1"
            @click="abrir(ticket)"
          >
            <div class="flex items-center w-full gap-2 min-w-0">
              <span class="text-xs font-medium text-n-slate-10">
                #{{ ticket.display_id }}
              </span>
              <span class="flex-1 text-sm font-medium truncate text-n-slate-12">
                {{ ticket.title }}
              </span>
              <span
                v-if="ticket.blocked_at"
                class="flex-shrink-0 text-xs text-n-slate-10"
              >
                {{ dataHora(ticket.blocked_at) }}
              </span>
            </div>

            <!-- O motivo e o que a pessoa precisa ler para decidir o que fazer:
                 fica a vista, nao atras de um clique. -->
            <p
              v-if="ticket.blocked_reason"
              class="flex items-start gap-1.5 m-0 text-sm text-n-amber-11"
            >
              <Icon
                icon="i-lucide-octagon-pause"
                class="flex-shrink-0 mt-0.5 size-3.5"
              />
              <span class="line-clamp-2">{{ ticket.blocked_reason }}</span>
            </p>

            <span v-if="localizacao(ticket)" class="text-xs text-n-slate-10">
              {{ localizacao(ticket) }}
            </span>
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>
