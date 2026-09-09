<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompanyCategoriesStore } from 'dashboard/stores/companyCategories';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
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
const categoriesStore = useCompanyCategoriesStore();

const newCategoryName = ref('');

const categories = computed(() => categoriesStore.getCategories);
const isCreating = computed(() => categoriesStore.uiFlags.isCreating);
const options = computed(() => [
  { value: 0, label: t('COMPANIES.DETAIL.PROFILE.CATEGORY.NONE') },
  ...categories.value.map(category => ({
    value: category.id,
    label: category.name,
  })),
]);

onMounted(() => {
  if (!categories.value.length) categoriesStore.get();
});

const handleCreateCategory = async () => {
  const name = newCategoryName.value.trim();
  if (!name) return;

  const existing = categories.value.find(
    category => category.name.toLowerCase() === name.toLowerCase()
  );
  if (existing) {
    emit('update:modelValue', existing.id);
    newCategoryName.value = '';
    return;
  }

  try {
    const created = await categoriesStore.create(name);
    emit('update:modelValue', created.id);
    newCategoryName.value = '';
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
        v-model="newCategoryName"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.CATEGORY.ADD_PLACEHOLDER')"
        :disabled="disabled"
        custom-input-class="h-8 !pt-1 !pb-1"
        class="flex-1"
        @keydown.enter.prevent="handleCreateCategory"
      />
      <Button
        :label="t('COMPANIES.DETAIL.PROFILE.CATEGORY.ADD_BUTTON')"
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isCreating"
        :disabled="disabled || !newCategoryName.trim()"
        @click="handleCreateCategory"
      />
    </div>
  </div>
</template>
