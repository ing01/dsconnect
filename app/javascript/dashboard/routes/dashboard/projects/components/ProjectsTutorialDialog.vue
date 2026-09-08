<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();

const STEPS = ['STEP1', 'STEP2', 'STEP3', 'STEP4', 'STEP5', 'STEP6'];
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header :header-title="t('PROJECTS.HELP.TUTORIAL.TITLE')" />
    <div class="flex-1 overflow-y-auto p-6 flex flex-col gap-3 min-h-0">
      <div
        v-for="step in STEPS"
        :key="step"
        class="flex items-start gap-2 p-3 rounded-lg bg-n-alpha-1 border border-n-weak"
      >
        <Icon icon="i-lucide-info" class="size-4 flex-shrink-0 mt-0.5 text-n-teal-11" />
        <p class="text-sm text-n-slate-11">
          {{ t(`PROJECTS.HELP.TUTORIAL.${step}`) }}
        </p>
      </div>
    </div>
  </div>
</template>
