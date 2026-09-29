<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, parseISO } from 'date-fns';
import { useStore } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['delete', 'update']);

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
const priorities = computed(
  () => store.getters['suggestionPriorities/getItems']
);
const categories = computed(
  () => store.getters['suggestionCategories/getItems']
);

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('suggestionPriorities/get');
  store.dispatch('suggestionCategories/get');
});

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

const completedLabel = computed(() =>
  suggestion.value?.completed_at
    ? format(parseISO(suggestion.value.completed_at), 'dd/MM/yyyy HH:mm')
    : ''
);

const handleDelete = () => {
  emit('delete', suggestion.value);
  close();
};

const handleAssigneeChange = event => {
  const assigneeId = event.target.value || null;
  suggestion.value = { ...suggestion.value, assignee_id: assigneeId };
  emit('update', { id: suggestion.value.id, assigneeId });
};

const handlePriorityChange = event => {
  const priorityId = event.target.value || null;
  suggestion.value = { ...suggestion.value, priority_id: priorityId };
  emit('update', { id: suggestion.value.id, priorityId });
};

const handleCategoryChange = event => {
  const categoryId = event.target.value || null;
  suggestion.value = { ...suggestion.value, category_id: categoryId };
  emit('update', { id: suggestion.value.id, categoryId });
};

const handleTimeSpentChange = event => {
  const timeSpentHours = event.target.value || null;
  suggestion.value = { ...suggestion.value, time_spent_hours: timeSpentHours };
  emit('update', { id: suggestion.value.id, timeSpentHours });
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

      <p
        v-if="suggestion.completed_at"
        class="flex items-center gap-1.5 px-2.5 py-1.5 mb-0 text-xs font-medium rounded-lg bg-n-teal-9 text-white w-fit"
      >
        <Icon icon="i-lucide-circle-check" class="size-3.5" />
        {{ t('SUGGESTIONS.CARD.COMPLETED_ON', { date: completedLabel }) }}
      </p>

      <div v-if="suggestion.attachments?.length" class="flex flex-col gap-1.5">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.ATTACHMENTS.LABEL') }}
        </span>
        <div class="flex flex-wrap gap-2">
          <a
            v-for="attachment in suggestion.attachments"
            :key="attachment.id"
            :href="attachment.url"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center justify-center overflow-hidden border rounded-lg size-16 border-n-weak bg-n-solid-2"
          >
            <img
              v-if="attachment.kind === 'image'"
              :src="attachment.thumb || attachment.url"
              :alt="attachment.name"
              class="object-cover w-full h-full"
            />
            <Icon v-else icon="i-lucide-video" class="size-5 text-n-slate-10" />
          </a>
        </div>
      </div>

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

      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('SUGGESTIONS.PRIORITY.LABEL') }}
          </span>
          <select
            v-if="canManage"
            :value="suggestion.priority_id || ''"
            class="mb-0"
            @change="handlePriorityChange"
          >
            <option value="">{{ t('SUGGESTIONS.PRIORITY.NONE') }}</option>
            <option
              v-for="priority in priorities"
              :key="priority.id"
              :value="priority.id"
            >
              {{ priority.name }}
            </option>
          </select>
          <Label
            v-else-if="suggestion.priority_name"
            compact
            class="w-fit"
            :label="suggestion.priority_name"
            :color="suggestion.priority_color || 'slate'"
          />
          <span v-else class="text-sm text-n-slate-12">
            {{ t('SUGGESTIONS.PRIORITY.NONE') }}
          </span>
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('SUGGESTIONS.CATEGORY.LABEL') }}
          </span>
          <select
            v-if="canManage"
            :value="suggestion.category_id || ''"
            class="mb-0"
            @change="handleCategoryChange"
          >
            <option value="">{{ t('SUGGESTIONS.CATEGORY.NONE') }}</option>
            <option
              v-for="category in categories"
              :key="category.id"
              :value="category.id"
            >
              {{ category.name }}
            </option>
          </select>
          <Label
            v-else-if="suggestion.category_name"
            compact
            class="w-fit"
            :label="suggestion.category_name"
            :color="suggestion.category_color || 'slate'"
          />
          <span v-else class="text-sm text-n-slate-12">
            {{ t('SUGGESTIONS.CATEGORY.NONE') }}
          </span>
        </label>
      </div>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.TIME_SPENT.LABEL') }}
        </span>
        <input
          v-if="canManage"
          type="number"
          min="0"
          step="0.5"
          class="mb-0"
          :value="suggestion.time_spent_hours || ''"
          :placeholder="t('SUGGESTIONS.TIME_SPENT.PLACEHOLDER')"
          @change="handleTimeSpentChange"
        />
        <span v-else class="text-sm text-n-slate-12">
          {{
            suggestion.time_spent_hours
              ? t('SUGGESTIONS.TIME_SPENT.HOURS', {
                  count: suggestion.time_spent_hours,
                })
              : t('SUGGESTIONS.TIME_SPENT.NONE')
          }}
        </span>
      </label>

      <div
        v-if="props.canManage"
        class="flex justify-end pt-2 border-t border-n-weak"
      >
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
