<script setup>
/**
 * Tutorial guiado do Portal do Cliente - abre sozinho no primeiro acesso de
 * cada contato (ver `hasSeenTutorial`/`setTutorialSeen` em `clientSession.js`,
 * guardado por contato, nao so' por navegador) e pode ser revisto a qualquer
 * momento pelo botao "Tutorial" no cabecalho (ver `ClientLayout.vue`).
 *
 * Sem biblioteca de tour pronta no projeto (nenhuma dependencia nova) - o
 * "spotlight" e' feito com 4 divs cobrindo tudo ao redor do alvo (tecnica
 * classica, sem precisar de clip-path), e o alvo de cada passo e' achado por
 * CSS (href do item do menu, ou `data-tour-step` nos botoes do cabecalho/
 * atalho flutuante) - de proposito SEM mexer no `SidebarGroupLeaf.vue`
 * compartilhado com o painel interno.
 */
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import {
  getClientSession,
  hasSeenTutorial,
  setTutorialSeen,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['sidebar-needed']);

const { t } = useI18n({ useScope: 'global' });
const router = useRouter();

// Cada passo aponta pra um alvo real da tela - `routeName` resolve o link do
// menu lateral (sem precisar de atributo novo nele); `selector` serve pros
// elementos que a propria `ClientLayout.vue` ja marca com `data-tour-step`.
// `needsSidebar: true` avisa o layout para abrir a gaveta no celular antes de
// medir a posicao (no desktop a barra ja' esta' sempre visivel).
const steps = computed(() => [
  {
    id: 'boas-vindas',
    title: t('CLIENT_AREA.TOUR.WELCOME.TITLE'),
    description: t('CLIENT_AREA.TOUR.WELCOME.DESCRIPTION'),
  },
  {
    id: 'principal',
    title: t('CLIENT_AREA.TOUR.HOME.TITLE'),
    description: t('CLIENT_AREA.TOUR.HOME.DESCRIPTION'),
    routeName: 'client_home',
    needsSidebar: true,
  },
  {
    id: 'tickets',
    title: t('CLIENT_AREA.TOUR.TICKETS.TITLE'),
    description: t('CLIENT_AREA.TOUR.TICKETS.DESCRIPTION'),
    routeName: 'client_tickets',
    needsSidebar: true,
  },
  {
    id: 'sac',
    title: t('CLIENT_AREA.TOUR.SAC.TITLE'),
    description: t('CLIENT_AREA.TOUR.SAC.DESCRIPTION'),
    routeName: 'client_manifestations',
    needsSidebar: true,
  },
  {
    id: 'chat',
    title: t('CLIENT_AREA.TOUR.CHAT.TITLE'),
    description: t('CLIENT_AREA.TOUR.CHAT.DESCRIPTION'),
    routeName: 'client_chat',
    needsSidebar: true,
  },
  {
    id: 'notificacoes',
    title: t('CLIENT_AREA.TOUR.NOTIFICATIONS.TITLE'),
    description: t('CLIENT_AREA.TOUR.NOTIFICATIONS.DESCRIPTION'),
    routeName: 'client_notifications',
    needsSidebar: true,
  },
  {
    id: 'chat-flutuante',
    title: t('CLIENT_AREA.TOUR.FLOATING_CHAT.TITLE'),
    description: t('CLIENT_AREA.TOUR.FLOATING_CHAT.DESCRIPTION'),
    selector: '[data-tour-step="floating-chat"]',
    // Some quando a pessoa ja esta' na tela do Chat (ver `showChatShortcut`
    // em `ClientLayout.vue`) - passo opcional pra nao travar o tutorial se
    // for revisto de la'.
    optional: true,
  },
  {
    id: 'instalar-app',
    title: t('CLIENT_AREA.TOUR.INSTALL_APP.TITLE'),
    description: t('CLIENT_AREA.TOUR.INSTALL_APP.DESCRIPTION'),
    selector: '[data-tour-step="install-app"]',
    // So' aparece se o botao existir na tela agora (ver `resolveTarget`) -
    // nem todo aparelho/navegador oferece instalar (ex.: ja instalado, ou
    // iOS fora do Safari).
    optional: true,
  },
  {
    id: 'fim',
    title: t('CLIENT_AREA.TOUR.END.TITLE'),
    description: t('CLIENT_AREA.TOUR.END.DESCRIPTION'),
  },
]);

const isVisible = ref(false);
const stepIndex = ref(0);
const targetRect = ref(null);
const tooltipRef = ref(null);

const currentStep = computed(() => steps.value[stepIndex.value] || null);
const isFirstStep = computed(() => stepIndex.value === 0);
const isLastStep = computed(() => stepIndex.value === steps.value.length - 1);

const resolveTarget = step => {
  if (!step) return null;

  if (step.routeName) {
    try {
      const href = router.resolve({ name: step.routeName }).href;
      return document.querySelector(
        `aside a[href="${CSS.escape(href)}"]`
      );
    } catch {
      return null;
    }
  }

  if (step.selector) {
    return document.querySelector(step.selector);
  }

  return null;
};

const measure = () => {
  const el = resolveTarget(currentStep.value);
  targetRect.value = el ? el.getBoundingClientRect() : null;
};

let resizeHandler = null;

const goToStep = async (index, direction = 1) => {
  if (index < 0 || index >= steps.value.length) {
    // Passou dos dois limites sem achar passo nenhum valido (tutorial so'
    // com passos opcionais ausentes, caso extremo) - encerra em vez de travar.
    if (index >= steps.value.length) finish();
    return;
  }

  const step = steps.value[index];

  // Passo opcional sem alvo na tela (ex.: instalar app indisponivel, ou
  // atalho flutuante do chat escondido por ja' estar na tela do Chat) - pula
  // sozinho pro proximo NA MESMA DIRECAO, sem deixar um passo "flutuando"
  // sem nada pra apontar.
  if (step.optional && !resolveTarget(step)) {
    goToStep(index + direction, direction);
    return;
  }

  stepIndex.value = index;
  emit('sidebar-needed', Boolean(step.needsSidebar));

  // Da' tempo da gaveta do celular abrir/fechar (transicao de 200ms no
  // `ClientSidebar.vue`) antes de medir a posicao do alvo.
  await nextTick();
  setTimeout(measure, step.needsSidebar ? 260 : 50);
};

const start = () => {
  isVisible.value = true;
  goToStep(0, 1);
};

const finish = () => {
  isVisible.value = false;
  emit('sidebar-needed', false);
  const contactId = getClientSession()?.contact?.id;
  setTutorialSeen(contactId);
};

const next = () => {
  if (isLastStep.value) {
    finish();
    return;
  }
  goToStep(stepIndex.value + 1, 1);
};

const back = () => {
  if (isFirstStep.value) return;
  goToStep(stepIndex.value - 1, -1);
};

const skip = () => finish();

// Posiciona o balao perto do alvo, sem deixar vazar da tela. Sem alvo (passo
// de boas-vindas/fim), fica centralizado.
const tooltipStyle = computed(() => {
  const rect = targetRect.value;
  if (!rect) return {};

  const margem = 16;
  const larguraBalao = 320;
  const alturaEstimativa = 180;

  let top = rect.bottom + margem;
  if (top + alturaEstimativa > window.innerHeight) {
    top = Math.max(margem, rect.top - alturaEstimativa - margem);
  }

  let left = rect.left;
  if (left + larguraBalao > window.innerWidth - margem) {
    left = window.innerWidth - larguraBalao - margem;
  }
  left = Math.max(margem, left);

  return { top: `${top}px`, left: `${left}px` };
});

onMounted(() => {
  resizeHandler = () => measure();
  window.addEventListener('resize', resizeHandler);
  window.addEventListener('scroll', resizeHandler, true);

  const contactId = getClientSession()?.contact?.id;
  if (!hasSeenTutorial(contactId)) {
    // Pequeno atraso para o layout (cabecalho/menu) estar totalmente de pe'
    // antes de medir qualquer coisa.
    setTimeout(start, 400);
  }
});

onBeforeUnmount(() => {
  if (resizeHandler) {
    window.removeEventListener('resize', resizeHandler);
    window.removeEventListener('scroll', resizeHandler, true);
  }
});

defineExpose({ start });
</script>

<template>
  <Teleport to="body">
    <div v-if="isVisible" class="fixed inset-0 z-[9999]">
      <!-- Spotlight: 4 tarjas cobrindo tudo MENOS o retangulo do alvo -
           sem alvo (boas-vindas/fim), cobre a tela inteira. -->
      <template v-if="targetRect">
        <div
          class="fixed bg-n-slate-12/60"
          :style="{
            top: 0,
            left: 0,
            right: 0,
            height: `${Math.max(targetRect.top - 6, 0)}px`,
          }"
        />
        <div
          class="fixed bg-n-slate-12/60"
          :style="{
            top: `${targetRect.bottom + 6}px`,
            left: 0,
            right: 0,
            bottom: 0,
          }"
        />
        <div
          class="fixed bg-n-slate-12/60"
          :style="{
            top: `${Math.max(targetRect.top - 6, 0)}px`,
            left: 0,
            width: `${Math.max(targetRect.left - 6, 0)}px`,
            height: `${targetRect.height + 12}px`,
          }"
        />
        <div
          class="fixed bg-n-slate-12/60"
          :style="{
            top: `${Math.max(targetRect.top - 6, 0)}px`,
            left: `${targetRect.right + 6}px`,
            right: 0,
            height: `${targetRect.height + 12}px`,
          }"
        />
        <div
          class="fixed rounded-xl ring-2 ring-n-brand pointer-events-none"
          :style="{
            top: `${targetRect.top - 6}px`,
            left: `${targetRect.left - 6}px`,
            width: `${targetRect.width + 12}px`,
            height: `${targetRect.height + 12}px`,
          }"
        />
      </template>
      <div v-else class="fixed inset-0 bg-n-slate-12/60" />

      <!-- Balao do passo atual. -->
      <div
        ref="tooltipRef"
        class="fixed flex flex-col gap-3 p-4 bg-n-solid-1 rounded-xl shadow-xl w-80 max-w-[calc(100vw-2rem)]"
        :class="targetRect ? '' : 'inset-0 m-auto h-fit'"
        :style="targetRect ? tooltipStyle : {}"
      >
        <div class="flex items-center justify-between gap-2">
          <h3 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ currentStep?.title }}
          </h3>
          <span class="flex-shrink-0 text-xs text-n-slate-10">
            {{ stepIndex + 1 }}/{{ steps.length }}
          </span>
        </div>
        <p class="m-0 text-sm text-n-slate-11">
          {{ currentStep?.description }}
        </p>
        <div class="flex items-center justify-between gap-2 mt-1">
          <button
            type="button"
            class="text-xs text-n-slate-10 hover:text-n-slate-12"
            @click="skip"
          >
            {{ t('CLIENT_AREA.TOUR.SKIP') }}
          </button>
          <div class="flex items-center gap-2">
            <Button
              v-if="!isFirstStep"
              faded
              slate
              size="sm"
              :label="t('CLIENT_AREA.TOUR.BACK')"
              @click="back"
            />
            <Button
              size="sm"
              :label="isLastStep ? t('CLIENT_AREA.TOUR.FINISH') : t('CLIENT_AREA.TOUR.NEXT')"
              @click="next"
            />
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
