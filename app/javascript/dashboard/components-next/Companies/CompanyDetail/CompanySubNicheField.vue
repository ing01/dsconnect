<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompanySubNichesStore } from 'dashboard/stores/companySubNiches';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

defineProps({
  modelValue: {
    type: [Number, String],
    default: 0,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const subNichesStore = useCompanySubNichesStore();

const newSubNicheName = ref('');

const subNiches = computed(() => subNichesStore.getSubNiches);
const isCreating = computed(() => subNichesStore.uiFlags.isCreating);
const options = computed(() => [
  { value: 0, label: t('COMPANIES.DETAIL.PROFILE.SUB_NICHE.NONE') },
  ...subNiches.value.map(subNiche => ({
    value: subNiche.id,
    label: subNiche.name,
  })),
]);

onMounted(() => {
  if (!subNiches.value.length) subNichesStore.get();
});

const handleCreateSubNiche = async () => {
  const name = newSubNicheName.value.trim();
  if (!name) return;

  const existing = subNiches.value.find(
    subNiche => subNiche.name.toLowerCase() === name.toLowerCase()
  );
  if (existing) {
    emit('update:modelValue', existing.id);
    newSubNicheName.value = '';
    return;
  }

  try {
    const created = await subNichesStore.create(name);
    emit('update:modelValue', created.id);
    newSubNicheName.value = '';
  } catch {
    // Error surfaced via the API response; keep the typed text so the agent can retry.
  }
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <Select
      :model-value="modelValue"
      :options="options"
      :disabled="disabled"
      @update:model-value="value => emit('update:modelValue', value)"
    />
    <div class="flex items-end gap-1">
      <Input
        v-model="newSubNicheName"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.SUB_NICHE.ADD_PLACEHOLDER')"
        :disabled="disabled"
        custom-input-class="h-8 !pt-1 !pb-1"
        class="flex-1"
        @keydown.enter.prevent="handleCreateSubNiche"
      />
      <Button
        :label="t('COMPANIES.DETAIL.PROFILE.SUB_NICHE.ADD_BUTTON')"
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isCreating"
        :disabled="disabled || !newSubNicheName.trim()"
        @click="handleCreateSubNiche"
      />
    </div>
  </div>
</template>
