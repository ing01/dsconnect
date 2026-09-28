<script setup>
/**
 * A busca do menu lateral: só chamado, e só pelo número.
 *
 * Antes isto era um atalho para a tela de busca geral (conversas, contatos,
 * artigos). Virou um campo de verdade: digita-se o número do chamado, e ele
 * abre. Uma coisa só, feita direto - e não uma tela intermediária de onde ainda
 * é preciso escolher.
 *
 * Fica num componente próprio, e não dentro do Sidebar.vue, porque aquele
 * arquivo passa de mil linhas e é mexido com frequência: quanto menor o rastro
 * lá, menos conflito na próxima mesclagem.
 */
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import TicketsAPI from 'dashboard/api/tickets';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const { t } = useI18n();
const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');

const termo = ref('');
const isSearching = ref(false);
// Só no modo recolhido: ali não cabe um campo, então o ícone abre um.
const isOpen = ref(false);
const campo = ref(null);

// Só os dígitos. O mesmo número é escrito de muitas formas - "#42", "42",
// "n 42" - e todas querem dizer a mesma coisa.
const numero = computed(() => termo.value.replace(/\D/g, ''));

const buscar = async () => {
  if (isSearching.value || !numero.value) return;

  isSearching.value = true;
  try {
    // A rota do detalhe usa o id interno, mas o que se digita é o NÚMERO do
    // chamado (`display_id`) - é ele que aparece no cartão, no título e no
    // e-mail. Esta consulta é a tradução de um para o outro.
    const { data } = await TicketsAPI.get({
      display_id: numero.value,
      per_page: 1,
    });
    const ticket = (data.payload || [])[0];

    if (!ticket) {
      useAlert(t('TICKET.SIDEBAR_SEARCH.NOT_FOUND', { number: numero.value }));
      return;
    }

    termo.value = '';
    isOpen.value = false;
    router.push(
      frontendURL(`accounts/${accountId.value}/tickets/${ticket.id}`)
    );
  } catch {
    useAlert(t('TICKET.SIDEBAR_SEARCH.ERROR'));
  } finally {
    isSearching.value = false;
  }
};

const abrir = async () => {
  isOpen.value = true;
  await nextTick();
  campo.value?.focus();
};

const fechar = () => {
  isOpen.value = false;
  termo.value = '';
};
</script>

<template>
  <!-- Menu aberto: o campo fica à vista, no lugar onde a busca sempre esteve. -->
  <div
    v-if="!isCollapsed"
    class="flex gap-2 items-center px-2 w-full h-7 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out focus-within:outline-n-brand"
  >
    <span
      class="flex-shrink-0 size-4 text-n-slate-10"
      :class="isSearching ? 'i-lucide-loader-2 animate-spin' : 'i-lucide-search'"
    />
    <input
      v-model="termo"
      type="search"
      inputmode="numeric"
      autocomplete="off"
      class="flex-grow !p-0 !m-0 !h-full !text-sm !bg-transparent !border-0 !outline-none !shadow-none text-n-slate-12 placeholder:text-n-slate-10"
      :placeholder="t('TICKET.SIDEBAR_SEARCH.PLACEHOLDER')"
      :aria-label="t('TICKET.SIDEBAR_SEARCH.LABEL')"
      @keyup.enter="buscar"
    />
  </div>

  <!-- Menu recolhido: o trilho é estreito demais para um campo, então o ícone
       abre um ao lado. Fecha ao clicar fora ou com Esc. -->
  <OnClickOutside v-else class="relative" @trigger="fechar">
    <button
      type="button"
      class="flex items-center justify-center size-8 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out hover:bg-n-alpha-2 dark:hover:bg-n-slate-9/30"
      :title="t('TICKET.SIDEBAR_SEARCH.LABEL')"
      :aria-label="t('TICKET.SIDEBAR_SEARCH.LABEL')"
      :aria-expanded="isOpen"
      @click="abrir"
    >
      <span
        class="size-4 text-n-slate-11"
        :class="
          isSearching ? 'i-lucide-loader-2 animate-spin' : 'i-lucide-search'
        "
      />
    </button>

    <div
      v-if="isOpen"
      class="absolute z-50 flex gap-2 items-center px-2 h-8 rounded-lg shadow-lg top-0 w-56 outline outline-1 outline-n-weak bg-n-solid-1 ltr:left-10 rtl:right-10"
    >
      <span class="flex-shrink-0 i-lucide-search size-4 text-n-slate-10" />
      <input
        ref="campo"
        v-model="termo"
        type="search"
        inputmode="numeric"
        autocomplete="off"
        class="flex-grow !p-0 !m-0 !h-full !text-sm !bg-transparent !border-0 !outline-none !shadow-none text-n-slate-12 placeholder:text-n-slate-10"
        :placeholder="t('TICKET.SIDEBAR_SEARCH.PLACEHOLDER')"
        :aria-label="t('TICKET.SIDEBAR_SEARCH.LABEL')"
        @keyup.enter="buscar"
        @keyup.esc="fechar"
      />
    </div>
  </OnClickOutside>
</template>
