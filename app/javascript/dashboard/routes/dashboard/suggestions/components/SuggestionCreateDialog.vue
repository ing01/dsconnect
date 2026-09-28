<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

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

// So Administradores podem ser Responsavel - mesma regra validada no backend
// (Suggestion#assignee_is_an_administrator).
const administrators = computed(() =>
  (store.getters['agents/getAgents'] || []).filter(
    agent => agent.role === 'administrator'
  )
);

onMounted(() => store.dispatch('agents/get'));

const open = () => {
  title.value = '';
  description.value = '';
  assigneeId.value = '';
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!title.value.trim()) return;
  emit('submit', {
    title: title.value.trim(),
    description: description.value.trim(),
    assigneeId: assigneeId.value || null,
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
    </div>
  </Dialog>
</template>
