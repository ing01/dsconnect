<script setup>
/**
 * A tela de ENTRADA da Área do Cliente (`/app/client`): só três opções, bem
 * grandes - "Falar com a equipe", "Abrir ticket" e "Acessar o portal completo"
 * (a lista de tickets). Nada de saudação, novidades ou tutorial: quem entra
 * quer fazer uma de duas coisas, e a tela só precisa dizer qual botão é qual.
 * O menu lateral fica escondido aqui e só aparece depois da escolha (ver
 * `ClientLayout.vue`).
 *
 * É a porta de TODA entrada - login e abertura do site/app partem de
 * /app/client - e nada é lembrado de uma vez para a outra: escolher o portal
 * completo hoje não pula esta tela amanhã. A tela "Principal" (novidades do
 * Portal) continua como uma tela comum do menu, em /app/client/principal. Quem
 * chega por um link direto, como o aviso de resposta num chamado, vai direto
 * para o destino.
 *
 * "Abrir ticket" abre o mesmo diálogo da tela de chamados (categoria, assunto,
 * descrição, anexos e "Abrir com IA"), sem passar pela lista antes. Ao criar,
 * leva para a lista, onde o chamado novo já aparece.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ClientTicketDialog from '../components/ClientTicketDialog.vue';

const { t } = useI18n();
const router = useRouter();

const novoTicketDialog = ref(null);
const categorias = ref([]);

// A lista é lida a cada abertura (igual à tela de chamados): a Categoria pode
// ter sido marcada ou desmarcada para o Portal depois que a tela carregou.
const abrirNovoTicket = async () => {
  try {
    const { data } = await ClientAreaAPI.categories();
    categorias.value = data;
  } catch {
    categorias.value = [];
  }
  novoTicketDialog.value?.open();
};

const aoCriar = () => router.push({ name: 'client_tickets' });

const classeBotao =
  'flex items-center justify-start w-full max-w-md gap-4 px-6 py-5 text-white rounded-2xl shadow-lg bg-n-brand hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand';
</script>

<template>
  <div
    class="flex flex-col items-center justify-center w-full h-full min-h-0 gap-4 p-6 overflow-y-auto"
  >
    <router-link :to="{ name: 'client_chat' }" :class="classeBotao">
      <Icon icon="i-lucide-message-circle" class="flex-shrink-0 size-8" />
      <span class="flex flex-col gap-1 text-left">
        <span class="text-xl font-semibold tracking-wide uppercase">
          {{ t('CLIENT_AREA.START.TALK_TO_TEAM') }}
        </span>
        <span class="text-sm font-normal opacity-90">
          {{ t('CLIENT_AREA.START.TALK_TO_TEAM_HINT') }}
        </span>
      </span>
    </router-link>

    <button type="button" :class="classeBotao" @click="abrirNovoTicket">
      <Icon icon="i-lucide-ticket" class="flex-shrink-0 size-8" />
      <span class="flex flex-col gap-1 text-left">
        <span class="text-xl font-semibold tracking-wide uppercase">
          {{ t('CLIENT_AREA.START.OPEN_TICKET') }}
        </span>
        <span class="text-sm font-normal opacity-90">
          {{ t('CLIENT_AREA.START.OPEN_TICKET_HINT') }}
        </span>
      </span>
    </button>

    <router-link
      :to="{ name: 'client_tickets' }"
      class="flex items-center gap-1 mt-2 text-base font-medium underline rounded text-n-slate-11 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    >
      {{ t('CLIENT_AREA.START.FULL_PORTAL') }}
      <Icon icon="i-lucide-arrow-right" class="size-4" />
    </router-link>

    <ClientTicketDialog
      ref="novoTicketDialog"
      :categories="categorias"
      @created="aoCriar"
    />
  </div>
</template>
