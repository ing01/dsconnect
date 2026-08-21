<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useSystemModulesStore } from 'dashboard/stores/systemModules';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const systemModulesStore = useSystemModulesStore();

const newModuleName = ref('');

const modules = computed(() => systemModulesStore.getModules);
const isCreating = computed(() => systemModulesStore.uiFlags.isCreating);
const selectedIds = computed(() => new Set(props.modelValue.map(Number)));

onMounted(() => {
  if (!modules.value.length) systemModulesStore.get();
});

const toggleModule = moduleId => {
  if (props.disabled) return;

  const next = selectedIds.value.has(moduleId)
    ? props.modelValue.filter(id => Number(id) !== moduleId)
    : [...props.modelValue, moduleId];
  emit('update:modelValue', next);
};

const handleCreateModule = async () => {
  const name = newModuleName.value.trim();
  if (!name) return;

  const existing = modules.value.find(
    m => m.name.toLowerCase() === name.toLowerCase()
  );
  if (existing) {
    if (!selectedIds.value.has(existing.id)) toggleModule(existing.id);
    newModuleName.value = '';
    return;
  }

  try {
    const created = await systemModulesStore.create(name);
    emit('update:modelValue', [...props.modelValue, created.id]);
    newModuleName.value = '';
  } catch {
    // Error surfaced via the API response; keep the typed text so the agent can retry.
  }
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div v-if="modules.length" class="flex flex-wrap gap-2">
      <button
        v-for="module_ in modules"
        :key="module_.id"
        type="button"
        class="px-2.5 py-1 text-xs rounded-full border transition-colors"
        :class="
          selectedIds.has(module_.id)
            ? 'bg-n-blue-9 border-n-blue-9 text-white'
            : 'border-n-weak text-n-slate-11 hover:border-n-slate-6'
        "
        :disabled="disabled"
        @click="toggleModule(module_.id)"
      >
        {{ module_.name }}
      </button>
    </div>
    <div class="flex items-end gap-1">
      <Input
        v-model="newModuleName"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.MODULES.ADD_PLACEHOLDER')"
        :disabled="disabled"
        custom-input-class="h-8 !pt-1 !pb-1"
        class="flex-1"
        @keydown.enter.prevent="handleCreateModule"
      />
      <Button
        :label="t('COMPANIES.DETAIL.PROFILE.MODULES.ADD_BUTTON')"
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isCreating"
        :disabled="disabled || !newModuleName.trim()"
        @click="handleCreateModule"
      />
    </div>
  </div>
</template>
