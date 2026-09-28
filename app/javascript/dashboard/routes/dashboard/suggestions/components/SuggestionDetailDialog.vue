<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, parseISO } from 'date-fns';
import { useStore } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['delete', 'updateAssignee']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const suggestion = ref(null);

// So Administradores podem ser Responsavel - mesma regra validada no backend
// (Suggestion#assignee_is_an_administrator).
const administrators = computed(() =>
  (store.getters['agents/getAgents'] || []).filter(
    agent => agent.role === 'administrator'
  )
);

onMounted(() => store.dispatch('agents/get'));

const open = record => {
  suggestion.value = record;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const dateLabel = computed(() =>
  suggestion.value?.created_at
    ? format(parseISO(suggestion.value.created_at), 'dd/MM/yyyy HH:mm')
    : ''
);

const handleDelete = () => {
  emit('delete', suggestion.value);
  close();
};

const handleAssigneeChange = event => {
  const assigneeId = event.target.value || null;
  suggestion.value = { ...suggestion.value, assignee_id: assigneeId };
  emit('updateAssignee', { id: suggestion.value.id, assigneeId });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="suggestion?.title"
    :show-confirm-button="false"
    :cancel-button-label="t('SUGGESTIONS.DETAIL.CLOSE')"
  >
    <div v-if="suggestion" class="flex flex-col gap-3">
      <p class="text-xs text-n-slate-11 mb-0">
        {{
          t('SUGGESTIONS.DETAIL.SUBMITTED_BY', {
            name: suggestion.user_name,
            date: dateLabel,
          })
        }}
      </p>
      <p class="text-sm text-n-slate-12 whitespace-pre-wrap mb-0">
        {{ suggestion.description || t('SUGGESTIONS.DETAIL.NO_DESCRIPTION') }}
      </p>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.ASSIGNEE.LABEL') }}
        </span>
        <select
          v-if="canManage"
          :value="suggestion.assignee_id || ''"
          class="mb-0"
          @change="handleAssigneeChange"
        >
          <option value="">{{ t('SUGGESTIONS.ASSIGNEE.NONE') }}</option>
          <option
            v-for="admin in administrators"
            :key="admin.id"
            :value="admin.id"
          >
            {{ admin.name }}
          </option>
        </select>
        <span v-else class="text-sm text-n-slate-12">
          {{ suggestion.assignee_name || t('SUGGESTIONS.ASSIGNEE.NONE') }}
        </span>
      </label>

      <div v-if="props.canManage" class="flex justify-end pt-2 border-t border-n-weak">
        <Button
          ruby
          faded
          size="sm"
          icon="i-lucide-trash-2"
          :label="t('SUGGESTIONS.DETAIL.DELETE')"
          @click="handleDelete"
        />
      </div>
    </div>
  </Dialog>
</template>
