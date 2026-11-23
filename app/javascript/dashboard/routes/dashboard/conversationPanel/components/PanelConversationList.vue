<script setup>
/**
 * A lista de conversas da faixa escolhida, da que espera há mais tempo para a
 * que espera há menos. O "esperando há" anda sozinho (relógio do painel).
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { BANDS } from '../bands';
import { formatWait, waitSeconds } from '../waitTime';

const props = defineProps({
  band: { type: String, required: true },
  items: { type: Array, default: () => [] },
  total: { type: Number, default: 0 },
  nowMs: { type: Number, required: true },
  accountId: { type: [Number, String], required: true },
});

defineEmits(['close']);

const { t } = useI18n();
const style = computed(() => BANDS[props.band]);
const bandTitle = computed(() =>
  t(`CONVERSATION_PANEL.BANDS.${style.value.i18n}.TITLE`)
);

const waitLabel = item => {
  const seconds = waitSeconds(item.waiting_since, props.nowMs);
  return seconds === null
    ? t('CONVERSATION_PANEL.LIST.REPLIED')
    : t('CONVERSATION_PANEL.LIST.WAITING', { time: formatWait(seconds) });
};

const conversationUrl = item =>
  `/app/accounts/${props.accountId}/conversations/${item.display_id}`;
</script>

<template>
  <section
    class="flex flex-col gap-3 p-4 border rounded-2xl border-n-weak bg-n-solid-2"
    data-testid="panel-list"
  >
    <div class="flex items-center justify-between gap-2">
      <h2 class="m-0 text-base font-semibold text-n-slate-12">
        {{ t('CONVERSATION_PANEL.LIST.TITLE', { band: bandTitle }) }}
      </h2>
      <button
        type="button"
        class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12"
        @click="$emit('close')"
      >
        <Icon icon="i-lucide-x" class="size-4" />
        {{ t('CONVERSATION_PANEL.CARD.CLOSE_LIST') }}
      </button>
    </div>

    <p v-if="total > items.length" class="m-0 text-xs text-n-slate-11">
      {{
        t('CONVERSATION_PANEL.LIST.TRUNCATED', {
          shown: items.length,
          total,
        })
      }}
    </p>

    <p v-if="!items.length" class="m-0 text-sm text-n-slate-11">
      {{ t('CONVERSATION_PANEL.LIST.EMPTY') }}
    </p>

    <ul class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="item in items"
        :key="item.id"
        class="flex flex-wrap items-center gap-x-4 gap-y-1 px-3 py-2 border-l-4 rounded-lg bg-n-alpha-1"
        :class="style.row"
        :data-testid="`panel-row-${item.id}`"
      >
        <div class="flex flex-col min-w-0 grow basis-64">
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ item.contact_name || `#${item.display_id}` }}
            <span v-if="item.company_name" class="font-normal text-n-slate-11">
              · {{ item.company_name }}
            </span>
          </span>
          <span class="text-xs truncate text-n-slate-11">
            {{ item.last_message || t('CONVERSATION_PANEL.LIST.NO_MESSAGE') }}
          </span>
        </div>

        <span class="text-xs text-n-slate-11">{{ item.inbox_name }}</span>
        <span class="text-xs text-n-slate-12">
          {{ item.assignee_name || t('CONVERSATION_PANEL.LIST.UNASSIGNED') }}
        </span>
        <span class="text-sm font-semibold tabular-nums" :class="style.number">
          {{ waitLabel(item) }}
        </span>
        <a
          :href="conversationUrl(item)"
          class="px-3 text-sm font-medium rounded-lg h-8 inline-flex items-center text-n-brand bg-n-alpha-2 hover:bg-n-alpha-3"
        >
          {{ t('CONVERSATION_PANEL.LIST.OPEN') }}
        </a>
      </li>
    </ul>
  </section>
</template>
