<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useDraggable } from '@vueuse/core';
import DueBotLogo from './DueBotLogo.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
const route = useRoute();

const { uiSettings, updateUISettings } = useUISettings();

// Screens with their own composer pinned to the bottom right. The launcher is
// fixed to that same corner, so on these it would sit on top of the send
// button rather than beside it.
const isComposerRoute = computed(() => {
  const COMPOSER_ROUTES = [
    'inbox_conversation',
    'conversation_through_inbox',
    'conversations_through_label',
    'team_conversations_through_label',
    'conversations_through_folders',
    'conversation_through_mentions',
    'conversation_through_unattended',
    'conversation_through_participating',
    'inbox_view_conversation',
    'internal_chat',
  ];
  return COMPOSER_ROUTES.includes(route.name);
});

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showCopilotLauncher = computed(() => {
  const isCaptainEnabled = isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CAPTAIN
  );
  return (
    isCaptainEnabled &&
    !uiSettings.value.is_copilot_panel_open &&
    !isComposerRoute.value
  );
});
const toggleSidebar = () => {
  updateUISettings({
    is_copilot_panel_open: !uiSettings.value.is_copilot_panel_open,
    is_contact_sidebar_open: false,
  });
};

// Botao arrastavel: a posicao fica salva por usuario (uiSettings), pra dar
// pra tirar da frente de um filtro ou outro botao que ele acabe cobrindo -
// pedido da Ingrid, 2026-11-11. Sem nunca arrastar, continua no canto de
// sempre (equivalente ao antigo `bottom-4 right-4`), inclusive acompanhando
// o redimensionamento da janela.
const LAUNCHER_SIZE = 56; // size-12 (48px) da logo + padding do ButtonGroup
const MARGIN = 16; // equivalente ao bottom-4/right-4 (1rem) em px

const launcherRef = ref(null);
const hasCustomPosition = computed(
  () => !!uiSettings.value.copilot_launcher_position
);

const clampToViewport = ({ x, y }) => ({
  x: Math.min(Math.max(x, 0), Math.max(window.innerWidth - LAUNCHER_SIZE, 0)),
  y: Math.min(Math.max(y, 0), Math.max(window.innerHeight - LAUNCHER_SIZE, 0)),
});

const defaultCornerPosition = () => ({
  x: window.innerWidth - LAUNCHER_SIZE - MARGIN,
  y: window.innerHeight - LAUNCHER_SIZE - MARGIN,
});

let hasMoved = false;

const { x, y, style } = useDraggable(launcherRef, {
  initialValue: () =>
    clampToViewport(
      uiSettings.value.copilot_launcher_position || defaultCornerPosition()
    ),
  onStart: () => {
    hasMoved = false;
  },
  onMove: () => {
    hasMoved = true;
  },
  onEnd: position => {
    // So' grava se realmente arrastou - um clique simples (abrir o Copilot)
    // tambem passa por aqui, e nao pode custar uma escrita de configuracao
    // a cada abertura.
    if (!hasMoved) return;
    updateUISettings({ copilot_launcher_position: clampToViewport(position) });
  },
});

// Janela redimensionada e o botao nunca foi arrastado: continua seguindo o
// canto, em vez de ficar "presa" na posicao calculada no primeiro carregamento.
const followCornerOnResize = () => {
  if (hasCustomPosition.value) return;
  const corner = defaultCornerPosition();
  x.value = corner.x;
  y.value = corner.y;
};

onMounted(() => window.addEventListener('resize', followCornerOnResize));
onUnmounted(() => window.removeEventListener('resize', followCornerOnResize));
</script>

<template>
  <div
    v-if="showCopilotLauncher"
    ref="launcherRef"
    class="fixed z-50 touch-none"
    :style="style"
  >
    <ButtonGroup
      class="rounded-full cursor-move bg-n-alpha-2 backdrop-blur-lg p-1 shadow hover:shadow-md"
    >
      <button
        type="button"
        :aria-label="$t('CONVERSATION.SIDEBAR.COPILOT')"
        class="rounded-full transition-all duration-200 ease-out hover:brightness-110 hover:scale-105 active:scale-95"
        @click="toggleSidebar"
      >
        <DueBotLogo class="size-12" />
      </button>
    </ButtonGroup>
  </div>
  <template v-else />
</template>
