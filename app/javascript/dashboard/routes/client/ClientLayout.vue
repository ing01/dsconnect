<script setup>
/**
 * O enquadramento da Área do Cliente.
 *
 * Os mesmos tokens visuais do painel interno (`n-*`, a mesma tipografia, o
 * mesmo Button): para o cliente é outro sistema, mas é o mesmo produto, e uma
 * segunda linguagem visual só faria parecer remendo.
 */
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import { useAlert } from 'dashboard/composables';
import { useAppInstallPrompt } from 'dashboard/composables/useAppInstallPrompt';
import { useClientNotificationsCount } from 'dashboard/composables/useClientNotificationsCount';
import {
  clientPushPermission,
  ensureClientPushSubscribed,
  requestClientPushPermission,
} from 'dashboard/helper/clientPushHelper';
import {
  getClientSession,
  clearClientSession,
  isSidebarCollapsed,
  setSidebarCollapsed,
  hasDismissedMonthlySurvey,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ClientSidebar from './ClientSidebar.vue';
import ClientTour from './components/ClientTour.vue';
import ClientMonthlySurveyDialog from './components/ClientMonthlySurveyDialog.vue';

// O idioma é definido no boot (vide `entrypoints/dashboard.js`), antes de
// qualquer tela montar.
const { t } = useI18n({ useScope: 'global' });

const contact = computed(() => getClientSession()?.contact || {});

// Some nas telas do proprio chat (ativo ou historico) - abrir um atalho para
// a tela em que a pessoa ja esta seria inutil, so ocupando espaco por cima
// do conteudo.
const route = useRoute();
const showChatShortcut = computed(
  () =>
    ![
      'client_chat',
      'client_chat_history',
      'client_chat_history_detail',
    ].includes(route.name)
);

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

const showDeleteDialog = ref(false);
const deletePassword = ref('');
const isDeleting = ref(false);
const deleteError = ref('');

const abrirDialogExcluir = () => {
  deletePassword.value = '';
  deleteError.value = '';
  showDeleteDialog.value = true;
};

const fecharDialogExcluir = () => {
  showDeleteDialog.value = false;
};

const excluirConta = async () => {
  if (!deletePassword.value) return;
  isDeleting.value = true;
  deleteError.value = '';
  try {
    await ClientAreaAPI.deleteAccount(deletePassword.value);
    clearClientSession();
    window.location.assign('/app/login');
  } catch (erro) {
    const status = erro?.response?.status;
    deleteError.value =
      status === 401
        ? t('CLIENT_AREA.DELETE_ACCOUNT.ERROR_WRONG_PASSWORD')
        : t('CLIENT_AREA.DELETE_ACCOUNT.ERROR_GENERIC');
  } finally {
    isDeleting.value = false;
  }
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

const {
  isIosSafari,
  isInstallable,
  instalarApp: instalarAppBase,
} = useAppInstallPrompt();

const instalarApp = async () => {
  const installed = await instalarAppBase();
  if (!installed) {
    if (isIosSafari) useAlert(t('CLIENT_AREA.INSTALL_APP_IOS_HINT'));
    return;
  }

  // Quem acabou de instalar é quem mais claramente quer ser avisado -
  // pergunta a notificação no mesmo instante, em vez de esperar a pessoa achar
  // o botão na tela de chat. Só pede quando ainda não houve resposta
  // ('default'): se já foi negada, perguntar de novo só incomoda, e se já foi
  // concedida por outro caminho, `ensureClientPushSubscribed` (abaixo) já
  // resolve.
  if (clientPushPermission() === 'default') {
    await requestClientPushPermission();
  }
};

// O tutorial guiado controla a gaveta do celular sozinho enquanto roda (abre
// antes de apontar pra um item do menu, fecha nos passos que nao sao dele) -
// ver `ClientTour.vue`.
const clientTourRef = ref(null);
const abrirTutorial = () => clientTourRef.value?.start();

// A Avaliação Mensal abre sozinha no primeiro acesso do mês, se ainda não
// respondida - ver `ClientMonthlySurveyDialog.vue`. `surveyAnswered` começa
// em `true` (esconde o botão do cabeçalho) até a checagem no servidor voltar,
// para não piscar o botão à toa em quem já respondeu.
const monthlySurveyRef = ref(null);
const surveyAnswered = ref(true);
const abrirAvaliacaoMensal = () => monthlySurveyRef.value?.open();

const verificarAvaliacaoMensal = async () => {
  try {
    const { data } = await ClientAreaAPI.monthlySurveyStatus();
    surveyAnswered.value = data.answered;

    if (!data.answered) {
      const contactId = getClientSession()?.contact?.id;
      if (!hasDismissedMonthlySurvey(contactId, data.reference_month)) {
        setTimeout(abrirAvaliacaoMensal, 400);
      }
    }
  } catch {
    // Falhar a checagem nao pode travar o resto do Portal - o botao do
    // cabecalho so' fica escondido, e tenta de novo no proximo acesso.
  }
};

// A inscrição de push pode já estar concedida sem que o SERVIDOR saiba - o
// Android pergunta sozinho ao instalar o app, e também dá para ligar direto
// nas Configurações do aparelho. Garantida aqui, no enquadramento de toda a
// Área do Cliente, e não só na tela de chat: é o que cobre quem acabou de
// instalar e ainda nem abriu aquela tela.
const { refresh: atualizarContagemNotificacoes } =
  useClientNotificationsCount();

onMounted(() => {
  ensureClientPushSubscribed();
  verificarAvaliacaoMensal();
  atualizarContagemNotificacoes();
});
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
        <p
          v-if="contact.company_name"
          class="m-0 text-xs truncate text-n-slate-11"
        >
          {{ contact.company_name }}
        </p>
      </div>

      <div class="flex items-center flex-shrink-0 gap-3">
        <span class="hidden text-sm sm:inline text-n-slate-11">
          {{ contact.name }}
        </span>
        <Button
          faded
          slate
          size="sm"
          icon="i-lucide-graduation-cap"
          :label="t('CLIENT_AREA.TOUR.OPEN_BUTTON')"
          @click="abrirTutorial"
        />
        <Button
          v-if="!surveyAnswered"
          faded
          slate
          size="sm"
          icon="i-lucide-star"
          :label="t('CLIENT_AREA.MONTHLY_SURVEY.OPEN_BUTTON')"
          @click="abrirAvaliacaoMensal"
        />
        <span
          v-if="isInstallable"
          class="contents"
          data-tour-step="install-app"
        >
          <Button
            faded
            slate
            size="sm"
            icon="i-lucide-download"
            :label="t('CLIENT_AREA.INSTALL_APP')"
            @click="instalarApp"
          />
        </span>
        <Button
          faded
          slate
          size="sm"
          icon="i-lucide-log-out"
          :label="t('CLIENT_AREA.LOGOUT')"
          @click="sair"
        />
        <Button
          faded
          ruby
          size="sm"
          icon="i-lucide-trash-2"
          :label="t('CLIENT_AREA.DELETE_ACCOUNT.BUTTON')"
          @click="abrirDialogExcluir"
        />
      </div>
    </header>

    <!-- Dialog de exclusão de conta -->
    <Teleport to="body">
      <div
        v-if="showDeleteDialog"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-n-slate-12/50"
        @click.self="fecharDialogExcluir"
      >
        <div class="w-full max-w-md rounded-xl bg-n-solid-2 shadow-xl border border-n-weak p-6 flex flex-col gap-4">
          <div class="flex items-start justify-between gap-3">
            <div class="flex flex-col gap-1">
              <h2 class="text-base font-semibold text-n-slate-12 m-0">
                {{ t('CLIENT_AREA.DELETE_ACCOUNT.DIALOG_TITLE') }}
              </h2>
              <p class="text-sm text-n-slate-11 m-0">
                {{ t('CLIENT_AREA.DELETE_ACCOUNT.DIALOG_DESCRIPTION') }}
              </p>
            </div>
            <button
              type="button"
              class="flex-shrink-0 flex items-center justify-center rounded-lg size-8 text-n-slate-10 hover:bg-n-alpha-2"
              @click="fecharDialogExcluir"
            >
              <Icon icon="i-lucide-x" class="size-4" />
            </button>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('CLIENT_AREA.DELETE_ACCOUNT.PASSWORD_LABEL') }}
            </label>
            <input
              v-model="deletePassword"
              type="password"
              :placeholder="t('CLIENT_AREA.DELETE_ACCOUNT.PASSWORD_PLACEHOLDER')"
              class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand"
              @keyup.enter="excluirConta"
            />
            <p v-if="deleteError" class="text-xs text-n-ruby-9 mt-1 m-0">{{ deleteError }}</p>
          </div>

          <div class="flex justify-end gap-2">
            <Button
              faded
              slate
              size="sm"
              :label="t('CLIENT_AREA.DELETE_ACCOUNT.CANCEL')"
              :disabled="isDeleting"
              @click="fecharDialogExcluir"
            />
            <Button
              solid
              ruby
              size="sm"
              :label="t('CLIENT_AREA.DELETE_ACCOUNT.CONFIRM_BUTTON')"
              :disabled="!deletePassword || isDeleting"
              :is-loading="isDeleting"
              @click="excluirConta"
            />
          </div>
        </div>
      </div>
    </Teleport>

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

      <!-- Flutua sobre o conteudo em qualquer tela do Portal, para a pessoa
           nao precisar abrir o menu lateral toda vez que quiser falar com a
           equipe. -->
      <router-link
        v-if="showChatShortcut"
        :to="{ name: 'client_chat' }"
        data-tour-step="floating-chat"
        class="fixed z-20 flex items-center justify-center text-white rounded-full shadow-lg bottom-6 right-6 size-14 bg-n-brand hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CLIENT_AREA.CHAT.FLOATING_BUTTON')"
        :title="t('CLIENT_AREA.CHAT.FLOATING_BUTTON')"
      >
        <Icon icon="i-lucide-message-circle" class="size-6" />
      </router-link>
    </div>

    <ClientTour ref="clientTourRef" @sidebar-needed="isMobileOpen = $event" />

    <ClientMonthlySurveyDialog
      ref="monthlySurveyRef"
      @answered="surveyAnswered = true"
    />
  </div>
</template>
