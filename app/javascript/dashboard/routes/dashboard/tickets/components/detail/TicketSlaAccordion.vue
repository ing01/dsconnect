<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();

// The deadline is the ticket's own `due_at`. The SLA that already exists in this
// product (AppliedSla) is attached to a Conversation and computes its due dates
// from it, so it has nothing to say about a ticket - and a ticket opened
// straight from the Kanban has no conversation at all.
const dueAt = computed(() =>
  props.ticket.due_at
    ? new Date(props.ticket.due_at * 1000).toLocaleString()
    : null
);

const isOverdue = computed(
  () =>
    !!props.ticket.due_at &&
    props.ticket.status === 'open' &&
    props.ticket.due_at * 1000 < Date.now()
);

const extensions = computed(() => props.ticket.sla_extensions || []);

const totalHours = computed(() =>
  extensions.value.reduce((sum, extension) => sum + Number(extension.hours), 0)
);
</script>

<template>
  <Accordion :title="t('TICKET.DETAIL.SLA.TITLE')">
    <div class="flex flex-col gap-2 pt-2 min-w-0">
      <p v-if="!dueAt" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.SLA.EMPTY') }}
      </p>

      <template v-else>
        <div class="flex items-center justify-between gap-2 min-w-0">
          <span class="text-sm text-n-slate-11">
            {{ t('TICKET.DETAIL.SLA.DUE_AT') }}
          </span>
          <span
            class="text-sm font-medium truncate"
            :class="isOverdue ? 'text-n-ruby-11' : 'text-n-slate-12'"
          >
            {{ dueAt }}
          </span>
        </div>

        <div
          v-if="extensions.length"
          class="flex items-center justify-between gap-2 min-w-0"
        >
          <span class="text-sm text-n-slate-11">
            {{ t('TICKET.DETAIL.SLA.EXTENDED_BY') }}
          </span>
          <span class="text-sm text-n-slate-12">
            {{ t('TICKET.DETAIL.SLA.HOURS_COUNT', { hours: totalHours }) }}
          </span>
        </div>
      </template>
    </div>
  </Accordion>
</template>
