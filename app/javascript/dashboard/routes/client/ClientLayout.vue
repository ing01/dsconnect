<script setup>
/**
 * O enquadramento da Área do Cliente.
 *
 * Os mesmos tokens visuais do painel interno (`n-*`, a mesma tipografia, o
 * mesmo Button): para o cliente é outro sistema, mas é o mesmo produto, e uma
 * segunda linguagem visual só faria parecer remendo.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import { useAlert } from 'dashboard/composables';
import { useAppInstallPrompt } from 'dashboard/composables/useAppInstallPrompt';
import {
  getClientSession,
  clearClientSession,
  isSidebarCollapsed,
  setSidebarCollapsed,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ClientSidebar from './ClientSidebar.vue';

// O idioma é definido no boot (vide `entrypoints/dashboard.js`), antes de
// qualquer tela montar.
const { t } = useI18n({ useScope: 'global' });

const contact = computed(() => getClientSession()?.contact || {});

// Duas coisas diferentes: no desktop a barra RECOLHE (vira um trilho de
// ícones); no celular ela ABRE e FECHA como gaveta.
const isCollapsed = ref(isSidebarCollapsed());
const isMobileOpen = ref(false);

const toggleCollapse = () => {
  isCollapsed.value = !isCollapsed.value;
  setSidebarCollapsed(isCollapsed.value);
};

// O mesmo botão serve aos dois: no celular abre a gaveta, no desktop recolhe.
const toggleMenu = () => {
  if (window.matchMedia('(min-width: 768px)').matches) {
    toggleCollapse();
    return;
  }
  isMobileOpen.value = !isMobileOpen.value;
};

const sair = async () => {
  // A falha da chamada é engolida de propósito, e não deixada como `finally`
  // sem `catch`: assim a rejeição não escapa para o console. A sessão local cai
  // de todo jeito - deixar o cookie para trás depois de clicar em sair é pior
  // do que um token órfão no servidor, que sem o acesso ligado não abre nada.
  await ClientAreaAPI.logout().catch(() => {});

  clearClientSession();

  // Carga completa, e não navegação do router: a tela de login não é rota deste
  // SPA - é a página servida pelo Rails, a mesma a que `routes/index.js` manda
  // quem não tem sessão. Sair também tem de largar o estado que ficou em
  // memória, e só o recarregamento garante isso.
  window.location.assign('/app/login');
};

const { isIosSafari, isInstallable, instalarApp: instalarAppBase } =
  useAppInstallPrompt();

const instalarApp = async () => {
  const installed = await instalarAppBase();
  if (!installed && isIosSafari) {
    useAlert(t('CLIENT_AREA.INSTALL_APP_IOS_HINT'));
  }
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-screen bg-n-background">
    <header
      class="flex items-center justify-between flex-shrink-0 gap-3 px-4 py-3 border-b sm:px-6 border-n-weak bg-n-solid-1"
    >
      <button
        type="button"
        class="flex items-center justify-center flex-shrink-0 rounded-lg size-9 text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CLIENT_AREA.MENU.TOGGLE')"
        :title="t('CLIENT_AREA.MENU.TOGGLE')"
        @click="toggleMenu"
      >
        <Icon icon="i-lucide-menu" class="size-5" />
      </button>

      <div class="flex flex-col min-w-0">
        <h1 class="m-0 text-base font-medium truncate text-n-slate-12">
          {{ t('CLIENT_AREA.TITLE') }}
        </h1>
        <p v-if="contact.company_name" class="m-0 text-xs truncate text-n-slate-11">
          {{ contact.company_name }}
        </p>
      </div>

      <div class="flex items-center flex-shrink-0 gap-3">
        <span class="hidden text-sm sm:inline text-n-slate-11">
          {{ contact.name }}
        </span>
        <Button
          v-if="isInstallable"
          faded
          slate
          size="sm"
          icon="i-lucide-download"
          :label="t('CLIENT_AREA.INSTALL_APP')"
          @click="instalarApp"
        />
        <Button
          faded
          slate
          size="sm"
          icon="i-lucide-log-out"
          :label="t('CLIENT_AREA.LOGOUT')"
          @click="sair"
        />
      </div>
    </header>

    <!-- Cabeçalho em cima, menu à esquerda e conteúdo à direita - o mesmo
         arranjo do painel interno. -->
    <div class="relative flex flex-1 min-h-0 min-w-0">
      <ClientSidebar
        :is-collapsed="isCollapsed"
        :is-mobile-open="isMobileOpen"
        @toggle-collapse="toggleCollapse"
        @close-mobile="isMobileOpen = false"
      />

      <!-- Tocar fora fecha a gaveta - no celular não há espaço para um botão
           de fechar competindo com o conteúdo. -->
      <div
        v-if="isMobileOpen"
        class="fixed inset-0 z-30 bg-n-slate-12/40 md:hidden"
        @click="isMobileOpen = false"
      />

      <!-- Quem rola é cada tela, e não o `main`: com a rolagem aqui, o
           `min-h-0` das páginas não limita nada e um conteúdo longo espreme o
           que estiver acima dele (foi o que sumiu com as abas do chamado). -->
      <main class="flex flex-col flex-1 min-h-0 min-w-0 overflow-hidden">
        <router-view />
      </main>
    </div>
  </div>
</template>
