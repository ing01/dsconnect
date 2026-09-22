<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import TicketTimeReportsAPI from 'dashboard/api/ticketTimeReports';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');

const filters = ref({ from: '', to: '', teamId: '', level: '', userId: '' });
const report = ref(null);
const isLoading = ref(false);

const load = async () => {
  isLoading.value = true;
  try {
    // Só o que foi preenchido vai na consulta: um filtro vazio nao deve
    // restringir nada.
    const { data } = await TicketTimeReportsAPI.fetch({
      from: filters.value.from || undefined,
      to: filters.value.to || undefined,
      team_id: filters.value.teamId || undefined,
      level: filters.value.level || undefined,
      user_id: filters.value.userId || undefined,
    });
    report.value = data;
  } catch (error) {
    useAlert(t('TICKET_TIME_REPORTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

// Os niveis do relatorio saem das Mesas, e nao de uma lista escrita aqui: a
// quantidade e configuracao de cada Mesa, e uma copia no frontend voltaria a
// divergir do servidor no primeiro nivel novo. Com uma Mesa escolhida, sao os
// niveis dela; sem, o maior numero entre as que usam niveis - a mesma conta que
// o Tickets::TimeEntriesReportBuilder faz.
const LEVELS = computed(() => {
  const comNiveis = (teams.value || []).filter(
    team => team.assignee_levels_enabled
  );
  const escolhida = filters.value.teamId
    ? comNiveis.filter(team => team.id === Number(filters.value.teamId))
    : comNiveis;
  const maximo = escolhida.reduce(
    (maior, team) => Math.max(maior, team.assignee_levels_count || 2),
    2
  );

  return Array.from({ length: maximo }, (_, indice) => indice + 1);
});

// Trocar a Mesa pode deixar o nivel escolhido fora da lista dela; voltar ao
// vazio evita consultar um nivel que aquela Mesa nao usa.
watch(LEVELS, niveis => {
  if (filters.value.level && !niveis.includes(Number(filters.value.level))) {
    filters.value.level = '';
  }
});

const clear = () => {
  filters.value = { from: '', to: '', teamId: '', level: '', userId: '' };
  load();
};

// As pessoas agrupadas por nivel, que e como o relatorio e lido:
// "Nivel 1: Joao 12h30, Maria 08h20".
const usersByLevel = computed(() => {
  const rows = report.value?.by_user || [];

  return [...LEVELS.value, null].map(level => ({
    level,
    hours: report.value?.by_level?.find(row => row.level === level)?.hours || 0,
    users: rows.filter(row => row.level === level),
  }));
});

const levelLabel = level =>
  level
    ? t('TICKET_TIME_REPORTS.LEVEL', { level })
    : t('TICKET_TIME_REPORTS.NO_LEVEL');

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  load();
});
</script>

<template>
  <div class="flex flex-col gap-4 p-6 overflow-auto">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('TICKET_TIME_REPORTS.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('TICKET_TIME_REPORTS.DESC') }}
      </p>
    </div>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3 xl:grid-cols-5 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_TIME_REPORTS.FILTERS.FROM') }}
        </span>
        <input v-model="filters.from" type="date" class="w-full mb-0 text-sm" />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_TIME_REPORTS.FILTERS.TO') }}
        </span>
        <input v-model="filters.to" type="date" class="w-full mb-0 text-sm" />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_TIME_REPORTS.FILTERS.TEAM') }}
        </span>
        <select v-model="filters.teamId" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_TIME_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_TIME_REPORTS.FILTERS.LEVEL') }}
        </span>
        <select v-model="filters.level" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_TIME_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="level in LEVELS" :key="level" :value="level">
            {{ levelLabel(level) }}
          </option>
        </select>
      </label>
      <!-- Independente do nivel, como pedido: da para ver o total de uma
           pessoa mesmo sem escolher nivel nenhum. -->
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_TIME_REPORTS.FILTERS.USER') }}
        </span>
        <select v-model="filters.userId" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_TIME_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
    </div>

    <div class="flex gap-2">
      <Button
        type="button"
        :label="t('TICKET_TIME_REPORTS.FILTERS.APPLY')"
        :is-loading="isLoading"
        @click="load"
      />
      <Button
        faded
        slate
        type="button"
        :label="t('TICKET_TIME_REPORTS.FILTERS.CLEAR')"
        @click="clear"
      />
    </div>

    <div v-if="isLoading" class="flex items-center gap-2 py-6">
      <Spinner />
      <span class="text-sm text-n-slate-11">
        {{ t('TICKET_TIME_REPORTS.LOADING') }}
      </span>
    </div>

    <template v-else-if="report">
      <div
        class="flex items-center gap-6 px-4 py-3 border rounded-lg border-n-weak bg-n-alpha-black2"
      >
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_TIME_REPORTS.TOTAL_HOURS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ t('TICKET_TIME_REPORTS.HOURS', { hours: report.totals.hours }) }}
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_TIME_REPORTS.TOTAL_ENTRIES') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ report.totals.entries }}
          </span>
        </div>
      </div>

      <!-- Um bloco por nivel, com o total e quem contribuiu. O nivel sem
           apontamento aparece zerado de proposito: significa que nada foi
           escalado, e nao que a informacao falta. -->
      <section
        v-for="group in usersByLevel"
        :key="group.level ?? 'none'"
        class="flex flex-col gap-2"
      >
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-sm font-medium text-n-slate-12">
            {{ levelLabel(group.level) }}
          </h2>
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('TICKET_TIME_REPORTS.HOURS', { hours: group.hours }) }}
          </span>
        </div>

        <p v-if="!group.users.length" class="text-sm text-n-slate-10">
          {{ t('TICKET_TIME_REPORTS.NO_ENTRIES') }}
        </p>

        <ul v-else class="flex flex-col gap-1">
          <li
            v-for="row in group.users"
            :key="`${group.level}-${row.user_id}`"
            class="flex items-center justify-between gap-2 px-3 py-2 text-sm rounded-lg bg-n-alpha-1"
          >
            <span class="truncate text-n-slate-12">{{ row.user_name }}</span>
            <span class="flex-shrink-0 text-n-slate-11">
              {{ t('TICKET_TIME_REPORTS.HOURS', { hours: row.hours }) }}
            </span>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
