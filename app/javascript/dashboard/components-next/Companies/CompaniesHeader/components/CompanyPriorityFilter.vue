<script setup>
import { ref, computed, toRef } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  // Vazio = "todas as prioridades" (sem filtro). Mesma escala de
  // Company#client_level: 1 Baixa, 2 Media, 3 Alta.
  activeClientLevel: {
    type: [String, Number],
    default: '',
  },
});

const emit = defineEmits(['update:clientLevel']);

const { t } = useI18n();

const isMenuOpen = ref(false);

const priorityMenus = [
  { label: t('COMPANIES.FILTER_BY_PRIORITY.OPTIONS.ALL'), value: '' },
  { label: t('COMPANIES.DETAIL.PROFILE.LEVEL.L1'), value: 1 },
  { label: t('COMPANIES.DETAIL.PROFILE.LEVEL.L2'), value: 2 },
  { label: t('COMPANIES.DETAIL.PROFILE.LEVEL.L3'), value: 3 },
];

const activeClientLevel = toRef(props, 'activeClientLevel');

const activeClientLevelLabel = computed(() => {
  const selectedMenu = priorityMenus.find(
    menu => menu.value === activeClientLevel.value
  );
  return selectedMenu?.label || t('COMPANIES.FILTER_BY_PRIORITY.LABEL');
});

// O botao de fora fica destacado quando o filtro esta ativo, do mesmo jeito
// que ja fica destacado (bg-n-alpha-2) enquanto o menu esta aberto.
const isFilterActive = computed(() => activeClientLevel.value !== '');

const handleClientLevelChange = value => {
  emit('update:clientLevel', value);
};
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-list-filter"
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
          {{ t('COMPANIES.FILTER_BY_PRIORITY.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeClientLevel"
          :options="priorityMenus"
          :label="activeClientLevelLabel"
          sub-menu-position="left"
          @update:model-value="handleClientLevelChange"
        />
      </div>
    </div>
  </div>
</template>
