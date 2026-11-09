<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompanyNichesStore } from 'dashboard/stores/companyNiches';

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
const nichesStore = useCompanyNichesStore();

const newNicheName = ref('');

const niches = computed(() => nichesStore.getNiches);
const isCreating = computed(() => nichesStore.uiFlags.isCreating);
const options = computed(() => [
  { value: 0, label: t('COMPANIES.DETAIL.PROFILE.NICHE.NONE') },
  ...niches.value.map(niche => ({
    value: niche.id,
    label: niche.name,
  })),
]);

onMounted(() => {
  if (!niches.value.length) nichesStore.get();
});

const handleCreateNiche = async () => {
  const name = newNicheName.value.trim();
  if (!name) return;

  const existing = niches.value.find(
    niche => niche.name.toLowerCase() === name.toLowerCase()
  );
  if (existing) {
    emit('update:modelValue', existing.id);
    newNicheName.value = '';
    return;
  }

  try {
    const created = await nichesStore.create(name);
    emit('update:modelValue', created.id);
    newNicheName.value = '';
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
        v-model="newNicheName"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.NICHE.ADD_PLACEHOLDER')"
        :disabled="disabled"
        custom-input-class="h-8 !pt-1 !pb-1"
        class="flex-1"
        @keydown.enter.prevent="handleCreateNiche"
      />
      <Button
        :label="t('COMPANIES.DETAIL.PROFILE.NICHE.ADD_BUTTON')"
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isCreating"
        :disabled="disabled || !newNicheName.trim()"
        @click="handleCreateNiche"
      />
    </div>
  </div>
</template>
