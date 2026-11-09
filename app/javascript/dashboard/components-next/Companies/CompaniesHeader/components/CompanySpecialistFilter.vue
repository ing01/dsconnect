<script setup>
import { ref, computed, toRef, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  // Vazio = "todos os especialistas" (sem filtro).
  activeSpecialistId: {
    type: [String, Number],
    default: '',
  },
});

const emit = defineEmits(['update:specialistId']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

const isMenuOpen = ref(false);

const specialistMenus = computed(() => [
  { label: t('COMPANIES.FILTER_BY_SPECIALIST.OPTIONS.ALL'), value: '' },
  ...agents.value.map(agent => ({ label: agent.name, value: agent.id })),
]);

const activeSpecialistId = toRef(props, 'activeSpecialistId');

const activeSpecialistLabel = computed(() => {
  const selectedMenu = specialistMenus.value.find(
    menu => menu.value === activeSpecialistId.value
  );
  return selectedMenu?.label || t('COMPANIES.FILTER_BY_SPECIALIST.LABEL');
});

const isFilterActive = computed(() => activeSpecialistId.value !== '');

const handleSpecialistChange = value => {
  emit('update:specialistId', value);
};

onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
});
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-user-round"
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
          {{ t('COMPANIES.FILTER_BY_SPECIALIST.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeSpecialistId"
          :options="specialistMenus"
          :label="activeSpecialistLabel"
          sub-menu-position="left"
          @update:model-value="handleSpecialistChange"
        />
      </div>
    </div>
  </div>
</template>
