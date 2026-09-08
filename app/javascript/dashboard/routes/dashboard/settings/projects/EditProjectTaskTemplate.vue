<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import OpenChecklistSettingsButton from 'dashboard/components-next/checklist/OpenChecklistSettingsButton.vue';
import HelpButton from 'dashboard/components-next/help/HelpButton.vue';

const props = defineProps({
  taskTemplate: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const name = ref(props.taskTemplate.name || '');
const defaultTicketTitle = ref(props.taskTemplate.default_ticket_title || '');
const description = ref(props.taskTemplate.description || '');
const defaultAssigneeId = ref(props.taskTemplate.default_assignee_id || '');
const dueDays = ref(props.taskTemplate.due_days ?? 1);
const nextProjectStage = ref(props.taskTemplate.next_project_stage || '');
const checklistId = ref(props.taskTemplate.checklist_id || '');
const isSubmitting = ref(false);

const agents = computed(() => store.getters['agents/getAgents'] || []);
const checklists = computed(() => store.getters['checklists/getChecklists'] || []);
const selectedChecklist = computed(() =>
  checklists.value.find(c => c.id === Number(checklistId.value))
);

const stages = [
  { key: '', label: 'Nenhuma' },
  { key: 'pendente', label: 'Pending' },
  { key: 'onboarding', label: 'Onboarding' },
  { key: 'requisito', label: 'Requirements' },
  { key: 'em_andamento', label: 'In Progress' },
  { key: 'acompanhamento', label: 'Follow-up' },
  { key: 'pos', label: 'Post' },
  { key: 'finalizado', label: 'Completed' },
];

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('checklists/get');
});

const isFormValid = computed(() => {
  return !!name.value.trim() && !!defaultTicketTitle.value.trim() && dueDays.value >= 0;
});

const submit = async () => {
  if (!isFormValid.value || isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    await store.dispatch('projectTaskTemplates/update', {
      id: props.taskTemplate.id,
      name: name.value.trim(),
      default_ticket_title: defaultTicketTitle.value.trim(),
      description: description.value.trim(),
      default_assignee_id: defaultAssigneeId.value || null,
      due_days: Number(dueDays.value) || 0,
      next_project_stage: nextProjectStage.value || null,
      checklist_id: checklistId.value || null,
    });

    useAlert(t('PROJECT_TASKS.EDIT.SUCCESS'));
    emit('saved');
    emit('close');
  } catch (error) {
    useAlert(error.message || t('PROJECT_TASKS.EDIT.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header :header-title="t('PROJECT_TASKS.EDIT.TITLE')" />
    <form class="flex-1 overflow-y-auto p-6 flex flex-col gap-5 min-h-0" @submit.prevent="submit">
      <div class="flex justify-end -mb-2">
        <HelpButton :title="t('PROJECTS.HELP.TASK.TITLE')">
          <p>{{ t('PROJECTS.HELP.TASK.INTRO') }}</p>
          <p>{{ t('PROJECTS.HELP.TASK.CHECKLIST') }}</p>
        </HelpButton>
      </div>

      <NextInput
        v-model="name"
        :label="t('PROJECT_TASKS.FORM.NAME.LABEL')"
        :placeholder="t('PROJECT_TASKS.FORM.NAME.PLACEHOLDER')"
        required
      />

      <NextInput
        v-model="defaultTicketTitle"
        :label="t('PROJECT_TASKS.FORM.DEFAULT_TITLE.LABEL')"
        :placeholder="t('PROJECT_TASKS.FORM.DEFAULT_TITLE.PLACEHOLDER')"
        required
      />

      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-12">
          {{ t('PROJECT_TASKS.FORM.DESCRIPTION.LABEL') }}
        </label>
        <textarea
          v-model="description"
          rows="3"
          class="w-full p-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none resize-none"
          :placeholder="t('PROJECT_TASKS.FORM.DESCRIPTION.PLACEHOLDER')"
        />
      </div>

      <!-- Checklist: selecionado, nunca digitado aqui - só o cadastro central
           de Checklists (Configurações) constrói um do zero. -->
      <div class="flex flex-col gap-2 p-3.5 rounded-xl border border-n-weak bg-n-alpha-1">
        <div class="flex items-center justify-between">
          <label class="text-xs font-semibold text-n-slate-12">
            {{ t('CHECKLISTS.SELECT.LABEL') }}
          </label>
          <OpenChecklistSettingsButton />
        </div>
        <select
          v-model="checklistId"
          class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
        >
          <option value="">{{ t('CHECKLISTS.SELECT.NONE') }}</option>
          <option v-for="cl in checklists" :key="cl.id" :value="cl.id">
            {{ cl.name }} ({{ cl.items?.length || 0 }})
          </option>
        </select>

        <ul v-if="selectedChecklist?.items?.length" class="flex flex-wrap gap-1.5 mt-1">
          <li
            v-for="(item, idx) in selectedChecklist.items"
            :key="idx"
            class="flex items-center gap-1 px-2 py-0.5 rounded bg-n-slate-3 text-[11px] text-n-slate-11"
          >
            <Icon icon="i-lucide-check-square" class="size-3 text-n-slate-9" />
            {{ item.title || item }}
          </li>
        </ul>
      </div>

      <!-- Responsavel Padrão & Dias para Vencimento -->
      <div class="grid grid-cols-2 gap-4">
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-12">
            {{ t('PROJECT_TASKS.FORM.DEFAULT_ASSIGNEE.LABEL') }}
          </label>
          <select
            v-model="defaultAssigneeId"
            class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
          >
            <option value="">{{ t('PROJECT_TASKS.FORM.DEFAULT_ASSIGNEE.NONE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </div>

        <NextInput
          v-model="dueDays"
          type="number"
          min="0"
          :label="t('PROJECT_TASKS.FORM.DUE_DAYS.LABEL')"
          :placeholder="t('PROJECT_TASKS.FORM.DUE_DAYS.PLACEHOLDER')"
          required
        />
      </div>

      <!-- Etapa do Projeto pós Conclusão -->
      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-12">
          {{ t('PROJECT_TASKS.FORM.NEXT_STAGE.LABEL') }}
        </label>
        <select
          v-model="nextProjectStage"
          class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
        >
          <option v-for="st in stages" :key="st.key" :value="st.key">
            {{ t(`PROJECTS.STAGES.${st.key.toUpperCase()}`, st.label) }}
          </option>
        </select>
        <p class="text-[11px] text-n-slate-10">
          {{ t('PROJECT_TASKS.FORM.NEXT_STAGE.HINT') }}
        </p>
      </div>

      <!-- Buttons -->
      <div class="flex justify-end gap-2 pt-5 border-t border-n-weak">
        <NextButton
          faded
          slate
          type="button"
          :label="t('PROJECTS.FORM.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="submit"
          :label="t('PROJECT_TASKS.EDIT.SUBMIT')"
          :disabled="!isFormValid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
