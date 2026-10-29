<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
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
</script>

<template>
  <div
    v-if="showCopilotLauncher"
    class="fixed bottom-4 ltr:right-4 rtl:left-4 z-50"
  >
    <ButtonGroup
      class="rounded-full bg-n-alpha-2 backdrop-blur-lg p-1 shadow hover:shadow-md"
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
