<script setup>
/**
 * A barra lateral da Área do Cliente.
 *
 * Monta o `SidebarGroupLeaf` real do painel - o mesmo item de menu, com o mesmo
 * estado ativo, o mesmo hover e os mesmos tokens. O que não vem junto é o resto
 * do `Sidebar.vue`: conta, troca de conta, atalhos, changelog e o menu de
 * perfil, que são do usuário interno.
 *
 * Segue o mesmo arranjo do painel para os dois tamanhos de tela:
 * - no celular é uma GAVETA, fora da tela até ser aberta (`fixed` + translate);
 * - a partir de `md` ela faz parte do layout e pode ser recolhida a um trilho
 *   de ícones.
 *
 * `provideSidebarContext` é obrigatório: o item pergunta ao contexto se a rota é
 * permitida. Sem permissão exigida nas rotas do cliente, a resposta é sempre
 * sim - e é o mesmo caminho que os testes do componente usam.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { provideSidebarContext } from 'dashboard/components-next/sidebar/provider';
import SidebarGroupLeaf from 'dashboard/components-next/sidebar/SidebarGroupLeaf.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  // Recolhida no desktop: só os ícones.
  isCollapsed: { type: Boolean, default: false },
  // Aberta no celular: a gaveta está à vista.
  isMobileOpen: { type: Boolean, default: false },
});

const emit = defineEmits(['toggleCollapse', 'closeMobile']);

const { t } = useI18n();
const route = useRoute();

provideSidebarContext({});

const itens = computed(() => [
  {
    name: 'client_home',
    label: t('CLIENT_AREA.MENU.PRINCIPAL'),
    icon: 'i-lucide-home',
    to: { name: 'client_home' },
    activeOn: ['client_home'],
  },
  {
    name: 'client_tickets',
    label: t('CLIENT_AREA.MENU.TICKETS'),
    icon: 'i-lucide-ticket',
    to: { name: 'client_tickets' },
    // O detalhe de um chamado continua sendo "Tickets": sair do item ativo ao
    // abrir um chamado faria o menu perder a referência de onde se está.
    activeOn: ['client_tickets', 'client_ticket_detail'],
  },
  {
    name: 'client_chat',
    label: t('CLIENT_AREA.MENU.CHAT'),
    icon: 'i-lucide-message-circle',
    to: { name: 'client_chat' },
    activeOn: ['client_chat', 'client_chat_history', 'client_chat_history_detail'],
  },
  {
    name: 'client_notifications',
    label: t('CLIENT_AREA.MENU.NOTIFICATIONS'),
    icon: 'i-lucide-bell',
    to: { name: 'client_notifications' },
    activeOn: ['client_notifications'],
  },
]);

const isActive = item => item.activeOn.includes(route.name);

// No celular a gaveta é sempre larga: um trilho de ícones sobreposto ao
// conteúdo não ajudaria ninguém.
const larguraDesktop = computed(() =>
  props.isCollapsed ? 'md:w-14' : 'md:w-56'
);
</script>

<template>
  <aside
    class="fixed top-0 z-40 flex flex-col h-full gap-2 py-3 text-sm transition-transform duration-200 ease-out bg-n-background border-e border-n-weak w-56 ltr:left-0 rtl:right-0 md:relative md:flex-shrink-0 md:ltr:translate-x-0 md:rtl:translate-x-0 md:transition-[width]"
    :class="[
      larguraDesktop,
      isMobileOpen
        ? 'shadow-lg md:shadow-none'
        : 'ltr:-translate-x-full rtl:translate-x-full',
    ]"
  >
    <nav class="flex flex-col flex-grow min-w-0 gap-2 px-2 overflow-y-auto">
      <ul class="flex flex-col gap-1 m-0 list-none min-w-0">
        <SidebarGroupLeaf
          v-for="item in itens"
          :key="item.name"
          :label="item.label"
          :icon="item.icon"
          :to="item.to"
          :active="isActive(item)"
          :collapsed="isCollapsed"
          :title="item.label"
          hide-tree-line
          @click="emit('closeMobile')"
        />
      </ul>
    </nav>

    <!-- Recolher é do desktop: no celular a gaveta se fecha ao escolher um
         item ou ao tocar fora. -->
    <div class="flex-shrink-0 hidden px-2 md:block">
      <button
        type="button"
        class="flex items-center w-full h-9 gap-2 px-2 rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :class="{ 'justify-center': isCollapsed }"
        :title="
          isCollapsed
            ? t('CLIENT_AREA.MENU.EXPAND')
            : t('CLIENT_AREA.MENU.COLLAPSE')
        "
        :aria-label="
          isCollapsed
            ? t('CLIENT_AREA.MENU.EXPAND')
            : t('CLIENT_AREA.MENU.COLLAPSE')
        "
        @click="emit('toggleCollapse')"
      >
        <Icon
          :icon="
            isCollapsed ? 'i-lucide-panel-left-open' : 'i-lucide-panel-left-close'
          "
          class="size-5 flex-shrink-0"
        />
        <span v-if="!isCollapsed" class="truncate">
          {{ t('CLIENT_AREA.MENU.COLLAPSE') }}
        </span>
      </button>
    </div>
  </aside>
</template>
