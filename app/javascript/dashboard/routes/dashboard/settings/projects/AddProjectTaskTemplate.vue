<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const name = ref('');
const defaultTicketTitle = ref('');
const description = ref('');
const defaultAssigneeId = ref('');
const dueDays = ref(1);
const nextProjectStage = ref('');
const checklistItems = ref([]);
const newChecklistText = ref('');
const isSubmitting = ref(false);

const agents = computed(() => store.getters['agents/getAgents'] || []);

const stages = [
  { key: '', label: 'Nenhuma' },
  { key: 'pendente', label: 'Pendente' },
  { key: 'onboarding', label: 'Onboarding' },
  { key: 'requisito', label: 'Requisito' },
  { key: 'em_andamento', label: 'Em Andamento' },
  { key: 'acompanhamento', label: 'Acompanhamento' },
  { key: 'pos', label: 'Pós' },
  { key: 'finalizado', label: 'Finalizado' },
];

onMounted(() => {
  store.dispatch('agents/get');
});

const addChecklistItem = () => {
  const text = newChecklistText.value.trim();
  if (!text) return;
  checklistItems.value.push({ id: Date.now(), title: text });
  newChecklistText.value = '';
};

const removeChecklistItem = index => {
  checklistItems.value.splice(index, 1);
};

const isFormValid = computed(() => {
  return !!name.value.trim() && !!defaultTicketTitle.value.trim() && dueDays.value >= 0;
});

const submit = async () => {
  if (!isFormValid.value || isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    await store.dispatch('projectTaskTemplates/create', {
      name: name.value.trim(),
      default_ticket_title: defaultTicketTitle.value.trim(),
      description: description.value.trim(),
      default_assignee_id: defaultAssigneeId.value || null,
      due_days: Number(dueDays.value) || 0,
      next_project_stage: nextProjectStage.value || null,
      checklist: checklistItems.value.map(item => ({ title: item.title })),
    });

    useAlert(t('PROJECT_TASKS.ADD.SUCCESS'));
    emit('saved');
    emit('close');
  } catch (error) {
    useAlert(error.message || t('PROJECT_TASKS.ADD.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header :header-title="t('PROJECT_TASKS.ADD.TITLE')" />
    <form class="flex-1 overflow-y-auto p-6 flex flex-col gap-4 min-h-0" @submit.prevent="submit">
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

      <div class="flex flex-col gap-1">
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

      <!-- Checklist Builder -->
      <div class="flex flex-col gap-2 p-3.5 rounded-xl border border-n-weak bg-n-alpha-1">
        <label class="text-xs font-semibold text-n-slate-12">
          {{ t('PROJECT_TASKS.FORM.CHECKLIST.LABEL') }}
        </label>
        <div class="flex gap-2">
          <input
            v-model="newChecklistText"
            type="text"
            class="flex-1 h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
            :placeholder="t('PROJECT_TASKS.FORM.CHECKLIST.PLACEHOLDER')"
            @keydown.enter.prevent="addChecklistItem"
          />
          <NextButton
            size="sm"
            type="button"
            icon="i-lucide-plus"
            :label="t('PROJECT_TASKS.FORM.CHECKLIST.ADD')"
            @click="addChecklistItem"
          />
        </div>

        <ul v-if="checklistItems.length" class="flex flex-col gap-1.5 mt-1">
          <li
            v-for="(item, idx) in checklistItems"
            :key="item.id"
            class="flex items-center justify-between px-3 py-1.5 rounded-lg bg-n-solid-1 border border-n-weak text-xs text-n-slate-12"
          >
            <div class="flex items-center gap-2 min-w-0">
              <Icon icon="i-lucide-check-square" class="size-3.5 text-n-slate-9 flex-shrink-0" />
              <span class="truncate">{{ item.title }}</span>
            </div>
            <button
              type="button"
              class="text-n-ruby-11 hover:text-n-ruby-12 p-1"
              @click="removeChecklistItem(idx)"
            >
              <Icon icon="i-lucide-trash-2" class="size-3.5" />
            </button>
          </li>
        </ul>
      </div>

      <!-- Responsavel Padrão & Dias para Vencimento -->
      <div class="grid grid-cols-2 gap-3">
        <div class="flex flex-col gap-1">
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
      <div class="flex flex-col gap-1">
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
      <div class="flex justify-end gap-2 pt-4 border-t border-n-weak">
        <NextButton
          faded
          slate
          type="button"
          :label="t('PROJECTS.FORM.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="submit"
          :label="t('PROJECT_TASKS.ADD.SUBMIT')"
          :disabled="!isFormValid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
