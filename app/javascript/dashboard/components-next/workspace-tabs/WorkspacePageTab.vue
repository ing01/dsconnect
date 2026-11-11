<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUnreadAlerts } from 'dashboard/composables/useUnreadAlerts';
import UnreadAlertMark from './UnreadAlertMark.vue';
import { ALERT_KIND, alertKindForTabKey } from './unreadAlerts';

const props = defineProps({
  tab: { type: Object, required: true },
  isActive: { type: Boolean, default: false },
  closable: { type: Boolean, default: true },
});

defineEmits(['select', 'close']);

const { t } = useI18n();

// "!" quando esta tela tem mensagem nao lida para mim (conversa atribuida a mim ou
// chat interno). Nao e' contador.
const alerts = useUnreadAlerts();
const kind = computed(() => alertKindForTabKey(props.tab.key));
const hasAlert = computed(
  () =>
    (kind.value === ALERT_KIND.CONVERSATIONS && alerts.conversations.value) ||
    (kind.value === ALERT_KIND.INTERNAL_CHAT && alerts.internalChat.value)
);
const alertLabel = computed(() =>
  kind.value === ALERT_KIND.INTERNAL_CHAT
    ? t('SIDEBAR.UNREAD_ALERT.INTERNAL_CHAT')
    : t('SIDEBAR.UNREAD_ALERT.CONVERSATIONS')
);
</script>

<template>
  <div
    v-tooltip="tab.label"
    class="group flex items-center flex-shrink-0 h-9 gap-1 pl-3 border rounded-lg min-w-[120px] max-w-[220px] transition-colors"
    :class="[
      closable ? 'pr-1' : 'pr-3',
      isActive
        ? 'border-n-brand bg-n-alpha-2 text-n-slate-12'
        : 'border-n-weak bg-n-alpha-black2 text-n-slate-11 hover:border-n-slate-8',
    ]"
  >
    <button
      type="button"
      class="flex items-center min-w-0 gap-2 text-sm truncate focus-visible:outline-none"
      :class="isActive ? 'font-medium' : ''"
      :aria-current="isActive ? 'page' : undefined"
      @click="$emit('select', tab)"
    >
      <span class="flex-shrink-0 size-4" :class="tab.icon" />
      <span class="truncate">{{ tab.label }}</span>
      <UnreadAlertMark v-if="hasAlert" :label="alertLabel" />
    </button>

    <button
      v-if="closable"
      type="button"
      class="flex items-center justify-center flex-shrink-0 ml-auto rounded size-7 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :aria-label="t('TICKET.WORKSPACE.CLOSE_TAB')"
      @click.stop="$emit('close', tab)"
    >
      <span class="i-lucide-x size-[18px]" />
    </button>
  </div>
</template>
