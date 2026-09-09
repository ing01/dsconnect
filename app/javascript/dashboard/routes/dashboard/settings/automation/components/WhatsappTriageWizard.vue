<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { formatMesaName } from 'dashboard/helper/mesaName';
import Button from 'dashboard/components-next/button/Button.vue';
import { buildWhatsappTriageTemplate } from '../flowSteps';

const props = defineProps({
  hasExistingSteps: { type: Boolean, default: false },
});

const emit = defineEmits(['apply']);

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const isOpen = ref(false);
const teamId = ref(null);
const ticketColumnId = ref(null);
const ticketCategoryId = ref(null);
const assistantId = ref(null);
const level3to5TeamId = ref(null);

const teams = computed(() => getters['teams/getTeams'].value || []);
const columns = computed(() =>
  teamId.value ? getters['ticketColumns/getColumns'].value(teamId.value) : []
);
const categories = computed(() =>
  teamId.value ? getters['ticketColumns/getCategories'].value(teamId.value) : []
);
const assistants = computed(
  () => getters['captainAssistants/getRecords'].value || []
);

onBeforeMount(() => {
  store.dispatch('teams/get');
  store.dispatch('captainAssistants/get');
});

// Estagio e categoria pertencem a Mesa - trocar a Mesa invalida as escolhas
// anteriores em vez de deixar um id de outra Mesa pendurado sem querer.
watch(teamId, id => {
  ticketColumnId.value = null;
  ticketCategoryId.value = null;
  if (!id) return;

  store.dispatch('ticketColumns/fetchColumns', id);
  store.dispatch('ticketColumns/fetchCategories', id);
});

const isComplete = computed(
  () =>
    teamId.value &&
    ticketColumnId.value &&
    ticketCategoryId.value &&
    assistantId.value
);

const apply = () => {
  if (!isComplete.value) return;
  if (
    props.hasExistingSteps &&
    // eslint-disable-next-line no-alert
    !window.confirm(t('AUTOMATION.FLOW.WIZARD.CONFIRM_REPLACE'))
  ) {
    return;
  }

  const steps = buildWhatsappTriageTemplate({
    teamId: teamId.value,
    ticketColumnId: ticketColumnId.value,
    ticketCategoryId: ticketCategoryId.value,
    assistantId: assistantId.value,
    level3to5TeamId: level3to5TeamId.value,
  });
  emit('apply', steps);
  useAlert(t('AUTOMATION.FLOW.WIZARD.APPLIED'));
  isOpen.value = false;
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 border rounded-lg border-n-blue-6 bg-n-blue-2"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="flex flex-col gap-1">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('AUTOMATION.FLOW.WIZARD.TITLE') }}
        </h4>
        <p class="text-xs text-n-slate-11">
          {{ t('AUTOMATION.FLOW.WIZARD.DESCRIPTION') }}
        </p>
      </div>
      <Button
        :label="
          isOpen
            ? t('AUTOMATION.FLOW.WIZARD.CLOSE')
            : t('AUTOMATION.FLOW.WIZARD.OPEN')
        "
        size="sm"
        :variant="isOpen ? 'faded' : 'solid'"
        color="blue"
        @click="isOpen = !isOpen"
      />
    </div>

    <div v-if="isOpen" class="flex flex-col gap-4 pt-2 border-t border-n-blue-6">
      <ol class="flex flex-col gap-3 pl-5 text-sm list-decimal text-n-slate-12">
        <li class="flex flex-col gap-1">
          {{ t('AUTOMATION.FLOW.WIZARD.STEP_TEAM') }}
          <select v-model="teamId" class="mb-0">
            <option :value="null">{{ t('AUTOMATION.FLOW.NOT_SET') }}</option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ formatMesaName(team.name) }}
            </option>
          </select>
        </li>
        <li class="flex flex-col gap-1">
          {{ t('AUTOMATION.FLOW.WIZARD.STEP_COLUMN') }}
          <select
            v-model="ticketColumnId"
            class="mb-0"
            :disabled="!teamId"
          >
            <option :value="null">{{ t('AUTOMATION.FLOW.NOT_SET') }}</option>
            <option v-for="column in columns" :key="column.id" :value="column.id">
              {{ column.name }}
            </option>
          </select>
        </li>
        <li class="flex flex-col gap-1">
          {{ t('AUTOMATION.FLOW.WIZARD.STEP_CATEGORY') }}
          <select
            v-model="ticketCategoryId"
            class="mb-0"
            :disabled="!teamId"
          >
            <option :value="null">{{ t('AUTOMATION.FLOW.NOT_SET') }}</option>
            <option
              v-for="category in categories"
              :key="category.id"
              :value="category.id"
            >
              {{ category.name }}
            </option>
          </select>
        </li>
        <li class="flex flex-col gap-1">
          {{ t('AUTOMATION.FLOW.WIZARD.STEP_ASSISTANT') }}
          <select v-model="assistantId" class="mb-0">
            <option :value="null">{{ t('AUTOMATION.FLOW.NOT_SET') }}</option>
            <option
              v-for="assistant in assistants"
              :key="assistant.id"
              :value="assistant.id"
            >
              {{ assistant.name }}
            </option>
          </select>
        </li>
        <li class="flex flex-col gap-1">
          {{ t('AUTOMATION.FLOW.WIZARD.STEP_LEVEL_3TO5_TEAM') }}
          <select v-model="level3to5TeamId" class="mb-0">
            <option :value="null">
              {{ t('AUTOMATION.FLOW.WIZARD.LEVEL_3TO5_TEAM_DEFAULT') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ formatMesaName(team.name) }}
            </option>
          </select>
        </li>
      </ol>

      <p class="text-xs text-n-slate-11">
        {{ t('AUTOMATION.FLOW.WIZARD.HINT') }}
      </p>

      <div class="flex justify-end">
        <Button
          :label="t('AUTOMATION.FLOW.WIZARD.APPLY')"
          size="sm"
          color="blue"
          :disabled="!isComplete"
          @click="apply"
        />
      </div>
    </div>
  </div>
</template>
