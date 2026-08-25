<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticketId: {
    type: [Number, String],
    required: true,
  },
});

const ACTIVITY_ICONS = {
  created: 'i-lucide-plus-circle',
  status_changed: 'i-lucide-refresh-cw',
  column_changed: 'i-lucide-move-horizontal',
  priority_changed: 'i-lucide-flag',
  assignee_changed: 'i-lucide-user',
  team_changed: 'i-lucide-users',
  comment_added: 'i-lucide-message-square',
  resolved: 'i-lucide-check',
  reopened: 'i-lucide-rotate-ccw',
  closed: 'i-lucide-check-check',
  conversation_linked: 'i-lucide-link',
  conversation_unlinked: 'i-lucide-unlink',
};


const { t } = useI18n();
const store = useStore();

const activities = computed(() =>
  store.getters['tickets/getActivities'](props.ticketId)
);
const isLoading = computed(
  () => store.getters['tickets/getUIFlags'].isFetchingActivities
);

const activityLabel = activity => {
  const actor = activity.user?.name || t('TICKET.ACTIVITY.SYSTEM');
  return t(`TICKET.ACTIVITY.TYPES.${activity.activity_type.toUpperCase()}`, {
    actor,
  });
};

const formattedTime = activity =>
  new Date(activity.created_at * 1000).toLocaleString();

onMounted(() => store.dispatch('tickets/fetchActivities', props.ticketId));
</script>

<template>
  <div class="flex flex-col gap-3">
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner />
    </div>
    <p v-else-if="!activities.length" class="text-sm text-n-slate-11">
      {{ t('TICKET.ACTIVITY.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-4">
      <li
        v-for="activity in activities"
        :key="activity.id"
        class="flex items-start gap-2.5"
      >
        <span
          class="flex items-center justify-center size-6 flex-shrink-0 rounded-full bg-n-slate-3 text-n-slate-11 mt-0.5"
        >
          <Icon
            :icon="ACTIVITY_ICONS[activity.activity_type] || 'i-lucide-dot'"
            class="size-3.5"
          />
        </span>
        <div class="flex flex-col min-w-0">
          <p class="text-sm text-n-slate-12">{{ activityLabel(activity) }}</p>
          <span class="text-xs text-n-slate-10">{{
            formattedTime(activity)
          }}</span>
        </div>
      </li>
    </ul>
  </div>
</template>
