<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import SuggestionFileInput from './SuggestionFileInput.vue';

const props = defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const title = ref('');
const description = ref('');
const assigneeId = ref('');
const priorityId = ref('');
const categoryId = ref('');
const timeSpentHours = ref('');
const files = ref([]);

// So Administradores podem ser Responsavel - mesma regra validada no backend
// (Suggestion#assignee_is_an_administrator).
const administrators = computed(() =>
  (store.getters['agents/getAgents'] || []).filter(
    agent => agent.role === 'administrator'
  )
);
const priorities = computed(() => store.getters['suggestionPriorities/getItems']);
const categories = computed(() => store.getters['suggestionCategories/getItems']);

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('suggestionPriorities/get');
  store.dispatch('suggestionCategories/get');
});

const open = () => {
  title.value = '';
  description.value = '';
  assigneeId.value = '';
  priorityId.value = '';
  categoryId.value = '';
  timeSpentHours.value = '';
  files.value = [];
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!title.value.trim()) return;
  emit('submit', {
    title: title.value.trim(),
    description: description.value.trim(),
    assigneeId: assigneeId.value || null,
    priorityId: priorityId.value || null,
    categoryId: categoryId.value || null,
    timeSpentHours: timeSpentHours.value || null,
    files: [...files.value],
  });
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('SUGGESTIONS.CREATE.TITLE')"
    :description="t('SUGGESTIONS.CREATE.DESCRIPTION')"
    :cancel-button-label="t('SUGGESTIONS.CREATE.CANCEL')"
    :confirm-button-label="t('SUGGESTIONS.CREATE.SUBMIT')"
    :disable-confirm-button="!title.trim()"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4">
      <NextInput
        v-model="title"
        :label="t('SUGGESTIONS.CREATE.TITLE_FIELD.LABEL')"
        :placeholder="t('SUGGESTIONS.CREATE.TITLE_FIELD.PLACEHOLDER')"
      />
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('SUGGESTIONS.CREATE.DESCRIPTION_FIELD.LABEL') }}
        </span>
        <textarea
          v-model="description"
          rows="4"
          class="w-full mb-0"
          :placeholder="t('SUGGESTIONS.CREATE.DESCRIPTION_FIELD.PLACEHOLDER')"
        />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('SUGGESTIONS.ASSIGNEE.LABEL') }}
        </span>
        <select v-model="assigneeId" class="mb-0">
          <option value="">{{ t('SUGGESTIONS.ASSIGNEE.NONE') }}</option>
          <option
            v-for="admin in administrators"
            :key="admin.id"
            :value="admin.id"
          >
            {{ admin.name }}
          </option>
        </select>
      </label>
      <div class="grid grid-cols-2 gap-4">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('SUGGESTIONS.PRIORITY.LABEL') }}
          </span>
          <select v-model="priorityId" class="mb-0">
            <option value="">{{ t('SUGGESTIONS.PRIORITY.NONE') }}</option>
            <option
              v-for="priority in priorities"
              :key="priority.id"
              :value="priority.id"
            >
              {{ priority.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('SUGGESTIONS.CATEGORY.LABEL') }}
          </span>
          <select v-model="categoryId" class="mb-0">
            <option value="">{{ t('SUGGESTIONS.CATEGORY.NONE') }}</option>
            <option
              v-for="category in categories"
              :key="category.id"
              :value="category.id"
            >
              {{ category.name }}
            </option>
          </select>
        </label>
      </div>
      <NextInput
        v-model="timeSpentHours"
        type="number"
        min="0"
        step="0.5"
        :label="t('SUGGESTIONS.TIME_SPENT.LABEL')"
        :placeholder="t('SUGGESTIONS.TIME_SPENT.PLACEHOLDER')"
      />
      <SuggestionFileInput v-model="files" />
    </div>
  </Dialog>
</template>
