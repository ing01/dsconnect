<script setup>
import { ref, computed, toRef } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  // Vazio = "todas as classificações" (sem filtro). Mesma escala manual de
  // Company#classification_level (1 a 5) - independente da Prioridade.
  activeClassificationLevel: {
    type: [String, Number],
    default: '',
  },
});

const emit = defineEmits(['update:classificationLevel']);

const { t } = useI18n();

const isMenuOpen = ref(false);

const classificationMenus = [
  { label: t('COMPANIES.FILTER_BY_CLASSIFICATION.OPTIONS.ALL'), value: '' },
  { label: t('COMPANIES.DETAIL.PROFILE.CLASSIFICATION_LEVEL.L1'), value: 1 },
  { label: t('COMPANIES.DETAIL.PROFILE.CLASSIFICATION_LEVEL.L2'), value: 2 },
  { label: t('COMPANIES.DETAIL.PROFILE.CLASSIFICATION_LEVEL.L3'), value: 3 },
  { label: t('COMPANIES.DETAIL.PROFILE.CLASSIFICATION_LEVEL.L4'), value: 4 },
  { label: t('COMPANIES.DETAIL.PROFILE.CLASSIFICATION_LEVEL.L5'), value: 5 },
];

const activeClassificationLevel = toRef(props, 'activeClassificationLevel');

const activeClassificationLevelLabel = computed(() => {
  const selectedMenu = classificationMenus.find(
    menu => menu.value === activeClassificationLevel.value
  );
  return selectedMenu?.label || t('COMPANIES.FILTER_BY_CLASSIFICATION.LABEL');
});

const isFilterActive = computed(() => activeClassificationLevel.value !== '');

const handleClassificationLevelChange = value => {
  emit('update:classificationLevel', value);
};
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-gauge"
      color="slate"
      size="sm"
      variant="ghost"
      :class="isMenuOpen || isFilterActive ? 'bg-n-alpha-2' : ''"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute top-full mt-1 ltr:-right-32 rtl:-left-32 sm:ltr:right-0 sm:rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('COMPANIES.FILTER_BY_CLASSIFICATION.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeClassificationLevel"
          :options="classificationMenus"
          :label="activeClassificationLevelLabel"
          sub-menu-position="left"
          @update:model-value="handleClassificationLevelChange"
        />
      </div>
    </div>
  </div>
</template>
