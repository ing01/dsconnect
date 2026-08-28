<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  formatSlaDuration,
  slaRemainingSeconds,
  slaState,
} from 'dashboard/helper/ticketSlaHelper';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();

// Um card único com os três prazos, cada um com estado próprio: atendimento
// pode estar cumprido enquanto o estágio venceu e a solução ainda corre.
const KINDS = ['response', 'stage', 'resolution'];

// A contagem regressiva é só apresentação - quem decide vencimento, cumprimento
// e extensão é o backend, que manda `status` e `due_at` prontos.
const now = ref(Date.now());
let timer = null;

onMounted(() => {
  timer = setInterval(() => {
    now.value = Date.now();
  }, 30000);
});

onBeforeUnmount(() => clearInterval(timer));

const slaByKind = computed(() =>
  Object.fromEntries((props.ticket.slas || []).map(sla => [sla.kind, sla]))
);

const STATE_PRESENTATION = {
  hit: { icon: 'i-lucide-check', color: 'text-n-teal-11' },
  missed: { icon: 'i-lucide-triangle-alert', color: 'text-n-ruby-11' },
  running: { icon: 'i-lucide-circle', color: 'text-n-slate-11' },
};

function describe(sla, state, kind) {
  if (!sla) return t('TICKET.DETAIL.SLA.NOT_CONFIGURED');
  if (state === 'hit') return t('TICKET.DETAIL.SLA.STATE.HIT');
  if (state === 'missed') return t('TICKET.DETAIL.SLA.STATE.MISSED');
  if (kind === 'response')
    return new Date(sla.due_at * 1000).toLocaleString([], {
      dateStyle: 'short',
      timeStyle: 'short',
    });

  return formatSlaDuration(slaRemainingSeconds(sla, now.value));
}

const rows = computed(() =>
  KINDS.map(kind => {
    const sla = slaByKind.value[kind];
    const state = slaState(sla);

    return {
      kind,
      sla,
      state,
      ...STATE_PRESENTATION[state],
      label: t(`TICKET.DETAIL.SLA.KIND.${kind.toUpperCase()}`),
      // Cumprido e vencido dizem o que aconteceu; em andamento mostra quanto
      // falta. O prazo de atendimento é o único que a tela mostra como data,
      // porque é o compromisso que o cliente enxerga.
      value: describe(sla, state, kind),
    };
  })
);

const hasAnySla = computed(() => (props.ticket.slas || []).length > 0);
</script>

<template>
  <Accordion :title="t('TICKET.DETAIL.SLA.TITLE')">
    <div class="flex flex-col gap-3 pt-2 min-w-0">
      <p v-if="!hasAnySla" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.SLA.EMPTY') }}
      </p>

      <template v-else>
        <div
          v-for="row in rows"
          :key="row.kind"
          class="flex flex-col gap-0.5 min-w-0"
        >
          <span class="text-sm text-n-slate-11">{{ row.label }}</span>
          <span class="flex items-center gap-1.5 min-w-0" :class="row.color">
            <Icon :icon="row.icon" class="flex-shrink-0 size-4" />
            <span class="text-sm font-medium truncate">{{ row.value }}</span>
          </span>
        </div>
      </template>
    </div>
  </Accordion>
</template>
