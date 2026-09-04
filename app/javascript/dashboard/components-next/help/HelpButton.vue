<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();
const showHelp = ref(false);
</script>

<template>
  <NextButton
    type="button"
    faded
    slate
    size="xs"
    icon="i-lucide-help-circle"
    :label="t('PROJECTS.HELP.BUTTON')"
    @click="showHelp = true"
  />

  <woot-modal v-model:show="showHelp" :on-close="() => (showHelp = false)">
    <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
      <woot-modal-header :header-title="title" />
      <div class="flex-1 overflow-y-auto p-6 flex flex-col gap-4 text-sm text-n-slate-11 min-h-0">
        <slot />
      </div>
    </div>
  </woot-modal>
</template>
