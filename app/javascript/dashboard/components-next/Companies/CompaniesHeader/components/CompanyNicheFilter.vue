<script setup>
import { ref, computed, toRef, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompanyNichesStore } from 'dashboard/stores/companyNiches';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  // Vazio = "todos os nichos" (sem filtro).
  activeCompanyNicheId: {
    type: [String, Number],
    default: '',
  },
});

const emit = defineEmits(['update:companyNicheId']);

const { t } = useI18n();
const nichesStore = useCompanyNichesStore();

const isMenuOpen = ref(false);

const niches = computed(() => nichesStore.getNiches);
const nicheMenus = computed(() => [
  { label: t('COMPANIES.FILTER_BY_NICHE.OPTIONS.ALL'), value: '' },
  ...niches.value.map(niche => ({ label: niche.name, value: niche.id })),
]);

const activeCompanyNicheId = toRef(props, 'activeCompanyNicheId');

const activeCompanyNicheLabel = computed(() => {
  const selectedMenu = nicheMenus.value.find(
    menu => menu.value === activeCompanyNicheId.value
  );
  return selectedMenu?.label || t('COMPANIES.FILTER_BY_NICHE.LABEL');
});

const isFilterActive = computed(() => activeCompanyNicheId.value !== '');

const handleCompanyNicheChange = value => {
  emit('update:companyNicheId', value);
};

onMounted(() => {
  if (!niches.value.length) nichesStore.get();
});
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-tag"
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
          {{ t('COMPANIES.FILTER_BY_NICHE.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeCompanyNicheId"
          :options="nicheMenus"
          :label="activeCompanyNicheLabel"
          sub-menu-position="left"
          @update:model-value="handleCompanyNicheChange"
        />
      </div>
    </div>
  </div>
</template>
