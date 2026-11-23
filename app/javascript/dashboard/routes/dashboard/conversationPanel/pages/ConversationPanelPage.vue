<script setup>
/**
 * O Painel de Conversas: três cards (em atendimento / aguardando / esperando há
 * muito tempo) pelo tempo que o cliente espera resposta, mais indicadores, a
 * lista da faixa escolhida e a distribuição por agente e por caixa.
 *
 * Os tempos de cada faixa vêm das Configurações (nada fixo aqui). Atualiza
 * sozinho: em tempo real quando há movimento e por tempo, como garantia.
 */
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useConversationPanel } from '../useConversationPanel';
import { BAND_KEYS } from '../bands';
import { formatWait } from '../waitTime';
import PanelStatCard from '../components/PanelStatCard.vue';
import PanelConversationList from '../components/PanelConversationList.vue';
import PanelBreakdown from '../components/PanelBreakdown.vue';

const SOUND_KEY = 'cw_conversation_panel_sound';

const { t } = useI18n();
const { accountId } = useAccount();
const { data, isLoading, hasError, nowMs, refresh } = useConversationPanel();

const root = ref(null);
const selectedBand = ref(null);
const isTv = ref(false);
const soundOn = ref(null);

const counts = computed(() => data.value?.counts || {});
const settings = computed(() => data.value?.settings || {});
const updatedAt = computed(() =>
  data.value
    ? new Date(data.value.generated_at).toLocaleTimeString('pt-BR')
    : ''
);

const bandHint = band => {
  const minutes = settings.value.orange_until_minutes;
  return t(`CONVERSATION_PANEL.BANDS.${band.toUpperCase()}.HINT`, { minutes });
};

// A maior espera de cada faixa: a conversa mais antiga da lista dela.
const infoText = band =>
  t(`CONVERSATION_PANEL.BANDS.${band.toUpperCase()}.INFO`, {
    minutes: settings.value.orange_until_minutes,
  });

const longestIn = band => {
  const first = data.value?.conversations?.[band]?.[0];
  if (!first?.waiting_since) return null;
  return Math.max(
    Math.floor((nowMs.value - Date.parse(first.waiting_since)) / 1000),
    0
  );
};

const toggleBand = band => {
  selectedBand.value = selectedBand.value === band ? null : band;
};

const stats = computed(() => [
  { key: 'OPEN', value: counts.value.total ?? 0 },
  { key: 'UNASSIGNED', value: counts.value.unassigned ?? 0 },
  { key: 'PAUSED', value: counts.value.paused ?? 0 },
  { key: 'SNOOZED', value: counts.value.snoozed ?? 0 },
  {
    key: 'AVERAGE_WAIT',
    value: counts.value.average_wait_seconds
      ? formatWait(counts.value.average_wait_seconds)
      : t('CONVERSATION_PANEL.STATS.NONE'),
  },
  {
    key: 'LONGEST_WAIT',
    value: counts.value.longest_wait_seconds
      ? formatWait(counts.value.longest_wait_seconds)
      : t('CONVERSATION_PANEL.STATS.NONE'),
  },
]);

// Som: preferência de CADA pessoa (navegador); sem escolha, vale o padrão da conta.
const readSound = () => {
  try {
    const saved = window.localStorage.getItem(SOUND_KEY);
    return saved === null ? null : saved === 'true';
  } catch {
    return null;
  }
};

const isSoundEnabled = computed(() =>
  soundOn.value === null ? Boolean(settings.value.sound_enabled) : soundOn.value
);

const toggleSound = () => {
  soundOn.value = !isSoundEnabled.value;
  try {
    window.localStorage.setItem(SOUND_KEY, String(soundOn.value));
  } catch {
    // Não poder lembrar a escolha não derruba o painel.
  }
};

const beep = () => {
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    const context = new AudioContextClass();
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.value = 880;
    gain.gain.value = 0.15;
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start();
    oscillator.stop(context.currentTime + 0.35);
    oscillator.onended = () => context.close();
  } catch {
    // Navegador sem áudio liberado: o painel segue só visual.
  }
};

// O título da aba avisa o vermelho mesmo com o painel em segundo plano, e o som
// toca quando MAIS conversas entram no vermelho.
const originalTitle = document.title;
watch(
  () => counts.value.red,
  (red, previous) => {
    document.title = red > 0 ? `🔴 ${red} · ${originalTitle}` : originalTitle;
    if (isSoundEnabled.value && previous !== undefined && red > previous) {
      beep();
    }
  }
);

const onFullscreenChange = () => {
  isTv.value = Boolean(document.fullscreenElement);
};

const toggleTv = async () => {
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else await root.value?.requestFullscreen();
  } catch {
    // Tela cheia bloqueada pelo navegador: o painel continua normal.
  }
};

onMounted(() => {
  soundOn.value = readSound();
  document.addEventListener('fullscreenchange', onFullscreenChange);
});

onBeforeUnmount(() => {
  document.title = originalTitle;
  document.removeEventListener('fullscreenchange', onFullscreenChange);
});
</script>

<template>
  <div
    ref="root"
    class="flex flex-col w-full h-full min-h-0 gap-5 p-4 overflow-y-auto sm:p-6 bg-n-background"
    data-testid="conversation-panel"
  >
    <header class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex flex-col min-w-0">
        <h1 class="m-0 text-2xl font-semibold text-n-slate-12">
          {{ t('CONVERSATION_PANEL.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CONVERSATION_PANEL.SUBTITLE') }}
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <span
          class="flex items-center gap-2 text-xs text-n-slate-11"
          data-testid="panel-status"
        >
          <span
            class="size-2 rounded-full"
            :class="hasError ? 'bg-n-ruby-9' : 'bg-n-teal-9'"
          />
          {{
            hasError
              ? t('CONVERSATION_PANEL.RECONNECTING')
              : t('CONVERSATION_PANEL.LIVE')
          }}
          <template v-if="updatedAt">
            ·
            {{ t('CONVERSATION_PANEL.UPDATED_AT', { time: updatedAt }) }}
          </template>
        </span>
        <Button
          slate
          faded
          size="sm"
          icon="i-lucide-refresh-cw"
          :label="t('CONVERSATION_PANEL.REFRESH')"
          @click="refresh"
        />
        <Button
          slate
          faded
          size="sm"
          :icon="isSoundEnabled ? 'i-lucide-volume-2' : 'i-lucide-volume-x'"
          :label="
            isSoundEnabled
              ? t('CONVERSATION_PANEL.SOUND_ON')
              : t('CONVERSATION_PANEL.SOUND_OFF')
          "
          data-testid="panel-sound"
          @click="toggleSound"
        />
        <Button
          slate
          faded
          size="sm"
          :icon="isTv ? 'i-lucide-minimize' : 'i-lucide-maximize'"
          :label="
            isTv
              ? t('CONVERSATION_PANEL.EXIT_TV_MODE')
              : t('CONVERSATION_PANEL.TV_MODE')
          "
          @click="toggleTv"
        />
      </div>
    </header>

    <p v-if="isLoading" class="m-0 text-sm text-n-slate-11">
      {{ t('CONVERSATION_PANEL.LOADING') }}
    </p>

    <template v-else-if="data">
      <div
        class="grid gap-4 md:grid-cols-3"
        :class="isTv ? 'gap-6' : ''"
        data-testid="panel-cards"
      >
        <PanelStatCard
          v-for="band in BAND_KEYS"
          :key="band"
          :band="band"
          :count="counts[band] || 0"
          :total="counts.total || 0"
          :hint="bandHint(band)"
          :info="infoText(band)"
          :longest-seconds="longestIn(band)"
          :is-active="selectedBand === band"
          @select="toggleBand"
        />
      </div>

      <div
        class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6"
        data-testid="panel-stats"
      >
        <div
          v-for="stat in stats"
          :key="stat.key"
          class="flex flex-col gap-0.5 px-4 py-3 border rounded-xl border-n-weak bg-n-solid-2"
          :data-testid="`panel-stat-${stat.key}`"
        >
          <span class="text-xs text-n-slate-11">
            {{ t(`CONVERSATION_PANEL.STATS.${stat.key}`) }}
          </span>
          <span class="text-xl font-semibold tabular-nums text-n-slate-12">
            {{ stat.value }}
          </span>
        </div>
      </div>

      <PanelConversationList
        v-if="selectedBand"
        :band="selectedBand"
        :items="data.conversations[selectedBand]"
        :total="counts[selectedBand] || 0"
        :now-ms="nowMs"
        :account-id="accountId"
        @close="selectedBand = null"
      />

      <div class="grid gap-4 lg:grid-cols-2">
        <PanelBreakdown
          :title="t('CONVERSATION_PANEL.BREAKDOWN.BY_AGENT')"
          :rows="data.by_agent"
          :empty-name="t('CONVERSATION_PANEL.BREAKDOWN.UNASSIGNED')"
        />
        <PanelBreakdown
          :title="t('CONVERSATION_PANEL.BREAKDOWN.BY_INBOX')"
          :rows="data.by_inbox"
        />
      </div>
    </template>

    <p v-else-if="hasError" class="m-0 text-sm text-n-ruby-11">
      <Icon icon="i-lucide-triangle-alert" class="inline size-4" />
      {{ t('CONVERSATION_PANEL.ERROR') }}
    </p>
  </div>
</template>
