<script setup>
/**
 * Roteamento automático do ticket aberto pelo Portal do Cliente, por nível de
 * prioridade da Empresa (Baixa/Média/Alta) - uma Mesa por nível, opcional.
 *
 * Fora daqui, o ticket do Portal já é roteado pela Mesa da Categoria que o
 * cliente escolheu (sem passar por Triagem manual) - esta tela só permite
 * uma Empresa de prioridade Alta (por exemplo) pular direto para uma Mesa
 * específica, não importa qual Categoria foi escolhida.
 */
import { onBeforeMount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import TicketRoutingRulesAPI from 'dashboard/api/ticketRoutingRules';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');

const LEVELS = [1, 2, 3];

const teamIdByLevel = ref({ 1: null, 2: null, 3: null });
const isLoading = ref(true);
const isSubmitting = ref(false);

const levelLabel = level =>
  t(`TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.LEVELS.${level}`);

const loadRules = async () => {
  const { data } = await TicketRoutingRulesAPI.get();
  const grouped = { 1: null, 2: null, 3: null };
  (data.payload || []).forEach(rule => {
    grouped[rule.client_level] = rule.team_id;
  });
  teamIdByLevel.value = grouped;
};

onBeforeMount(async () => {
  try {
    await store.dispatch('teams/get');
    await loadRules();
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.API.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
});

const handleSubmit = async () => {
  isSubmitting.value = true;
  try {
    const rules = LEVELS.filter(level => teamIdByLevel.value[level]).map(
      level => ({
        client_level: level,
        team_id: teamIdByLevel.value[level],
      })
    );
    await TicketRoutingRulesAPI.bulkUpdate(rules);
    useAlert(t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.TITLE')"
        :description="t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.DESCRIPTION')"
      />
    </template>

    <template #body>
      <form
        class="flex flex-col w-full max-w-2xl gap-5"
        @submit.prevent="handleSubmit"
      >
        <div
          v-if="!isLoading"
          class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
        >
          <div
            v-for="level in LEVELS"
            :key="level"
            class="flex items-center justify-between gap-4 px-5 py-4"
          >
            <div class="flex flex-col gap-1">
              <h3 class="text-heading-2 text-n-slate-12">
                {{ levelLabel(level) }}
              </h3>
              <p class="mb-0 text-body-para text-n-slate-11">
                {{ t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.ROW_HELP') }}
              </p>
            </div>
            <select v-model="teamIdByLevel[level]" class="mb-0 max-w-56">
              <option :value="null">
                {{ t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.NO_RULE') }}
              </option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="flex justify-end">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :disabled="isLoading"
            :label="t('TICKET.SETTINGS.CLIENT_PORTAL_ROUTING.SAVE')"
          />
        </div>
      </form>
    </template>
  </SettingsLayout>
</template>
