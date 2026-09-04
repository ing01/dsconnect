<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  checklist: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.checklist);

const name = ref(props.checklist?.name || '');
const items = ref(
  (props.checklist?.items || []).map((item, idx) => ({
    id: idx,
    title: item.title || item,
  }))
);
const newItemText = ref('');
const isSubmitting = ref(false);

const addItem = () => {
  const text = newItemText.value.trim();
  if (!text) return;
  items.value.push({ id: Date.now(), title: text });
  newItemText.value = '';
};

const removeItem = index => {
  items.value.splice(index, 1);
};

const isFormValid = computed(() => !!name.value.trim());

const submit = async () => {
  if (!isFormValid.value || isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    const payload = {
      name: name.value.trim(),
      items: items.value.map(item => ({ title: item.title })),
    };

    if (isEditing.value) {
      await store.dispatch('checklists/update', { id: props.checklist.id, ...payload });
      useAlert(t('CHECKLISTS.EDIT.SUCCESS'));
    } else {
      await store.dispatch('checklists/create', payload);
      useAlert(t('CHECKLISTS.ADD.SUCCESS'));
    }

    emit('saved');
    emit('close');
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t(isEditing.value ? 'CHECKLISTS.EDIT.ERROR' : 'CHECKLISTS.ADD.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="isEditing ? t('CHECKLISTS.EDIT.TITLE') : t('CHECKLISTS.ADD.TITLE')"
    />
    <form class="flex-1 overflow-y-auto p-6 flex flex-col gap-5 min-h-0" @submit.prevent="submit">
      <NextInput
        v-model="name"
        :label="t('CHECKLISTS.FORM.NAME.LABEL')"
        :placeholder="t('CHECKLISTS.FORM.NAME.PLACEHOLDER')"
        required
      />

      <div class="flex flex-col gap-2 p-3.5 rounded-xl border border-n-weak bg-n-alpha-1">
        <label class="text-xs font-semibold text-n-slate-12">
          {{ t('CHECKLISTS.FORM.ITEMS.LABEL') }}
        </label>
        <div class="flex gap-2">
          <input
            v-model="newItemText"
            type="text"
            class="flex-1 h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
            :placeholder="t('CHECKLISTS.FORM.ITEMS.PLACEHOLDER')"
            @keydown.enter.prevent="addItem"
          />
          <NextButton
            size="sm"
            type="button"
            icon="i-lucide-plus"
            :label="t('CHECKLISTS.FORM.ITEMS.ADD')"
            @click="addItem"
          />
        </div>

        <ul v-if="items.length" class="flex flex-col gap-1.5 mt-1">
          <li
            v-for="(item, idx) in items"
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
              @click="removeItem(idx)"
            >
              <Icon icon="i-lucide-trash-2" class="size-3.5" />
            </button>
          </li>
        </ul>
        <p v-else class="text-[11px] text-n-slate-10">
          {{ t('CHECKLISTS.FORM.ITEMS.EMPTY') }}
        </p>
      </div>

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
          :label="isEditing ? t('CHECKLISTS.EDIT.SUBMIT') : t('CHECKLISTS.ADD.SUBMIT')"
          :disabled="!isFormValid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
