<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  column: { type: Object, required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const name = ref(props.column.name || '');
const completed = ref(Boolean(props.column.completed));
const isSubmitting = ref(false);

const isInvalid = computed(() => !name.value.trim());

const submit = async () => {
  if (isInvalid.value) return;
  isSubmitting.value = true;
  try {
    await store.dispatch('suggestionColumns/update', {
      id: props.column.id,
      name: name.value.trim(),
      completed: completed.value,
    });
    useAlert(t('SUGGESTIONS.SETTINGS.API.UPDATE_SUCCESS'));
    emit('close');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('SUGGESTIONS.SETTINGS.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="t('SUGGESTIONS.SETTINGS.EDIT_TITLE')" />
    <form class="flex flex-col w-full gap-4 p-8" @submit.prevent="submit">
      <NextInput
        v-model="name"
        :label="t('SUGGESTIONS.SETTINGS.FORM.NAME.LABEL')"
        :placeholder="t('SUGGESTIONS.SETTINGS.FORM.NAME.PLACEHOLDER')"
      />
      <label class="flex items-center gap-2">
        <input v-model="completed" type="checkbox" class="mb-0" />
        <span class="text-sm text-n-slate-12">
          {{ t('SUGGESTIONS.SETTINGS.FORM.COMPLETED.LABEL') }}
        </span>
      </label>
      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="button"
          :label="t('SUGGESTIONS.SETTINGS.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="submit"
          :label="t('SUGGESTIONS.SETTINGS.UPDATE')"
          :disabled="isInvalid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
