<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const name = ref('');
const isSubmitting = ref(false);

const isInvalid = computed(() => !name.value.trim());

const submit = async () => {
  if (isInvalid.value) return;
  isSubmitting.value = true;
  try {
    await store.dispatch('suggestionColumns/create', { name: name.value.trim() });
    useAlert(t('SUGGESTIONS.SETTINGS.API.CREATE_SUCCESS'));
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
    <woot-modal-header :header-title="t('SUGGESTIONS.SETTINGS.ADD_TITLE')" />
    <form class="flex flex-col w-full gap-4 p-8" @submit.prevent="submit">
      <NextInput
        v-model="name"
        :label="t('SUGGESTIONS.SETTINGS.FORM.NAME.LABEL')"
        :placeholder="t('SUGGESTIONS.SETTINGS.FORM.NAME.PLACEHOLDER')"
      />
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
          :label="t('SUGGESTIONS.SETTINGS.SUBMIT')"
          :disabled="isInvalid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
