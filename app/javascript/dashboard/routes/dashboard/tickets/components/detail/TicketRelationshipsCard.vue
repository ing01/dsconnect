<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

// Four distinct relations, each with its own meaning: the parent this ticket
// hangs under, the children opened from it, the ticket it was grouped into, and
// the tickets grouped into it. Grouping deliberately moves no content, so these
// links are the only way back to the merged ticket's own comments and files.
const groups = computed(() =>
  [
    {
      key: 'PARENT',
      icon: 'i-lucide-corner-left-up',
      items: props.ticket.parent ? [props.ticket.parent] : [],
    },
    {
      key: 'CHILDREN',
      icon: 'i-lucide-git-branch',
      items: props.ticket.children || [],
    },
    {
      key: 'MERGED_INTO',
      icon: 'i-lucide-combine',
      items: props.ticket.merged_into ? [props.ticket.merged_into] : [],
    },
    {
      key: 'MERGED_TICKETS',
      icon: 'i-lucide-combine',
      items: props.ticket.merged_tickets || [],
    },
  ].filter(group => group.items.length > 0)
);

const openTicket = ticket => {
  router.push(
    frontendURL(`accounts/${route.params.accountId}/tickets/${ticket.id}`)
  );
};
</script>

<template>
  <!-- Hidden entirely when the ticket stands alone: an empty relationships card
       on every unrelated ticket is noise, not information. -->
  <section
    v-if="groups.length"
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.RELATIONSHIPS.TITLE') }}
    </h2>

    <div
      v-for="group in groups"
      :key="group.key"
      class="flex flex-col gap-1 min-w-0"
    >
      <span class="text-xs text-n-slate-10">
        {{ t(`TICKET.DETAIL.RELATIONSHIPS.${group.key}`) }}
      </span>
      <button
        v-for="item in group.items"
        :key="item.id"
        type="button"
        class="flex items-center gap-2 min-w-0 text-sm text-left transition-colors text-n-slate-11 hover:text-n-slate-12"
        @click="openTicket(item)"
      >
        <Icon :icon="group.icon" class="flex-shrink-0 size-3.5" />
        <span class="flex-shrink-0 text-n-slate-10">#{{ item.display_id }}</span>
        <span class="truncate min-w-0">{{ item.title }}</span>
      </button>
    </div>
  </section>
</template>
