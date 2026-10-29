<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import DropdownSection from 'dashboard/components-next/dropdown-menu/base/DropdownSection.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { FLOW_STEP_CATEGORIES, FLOW_STEP_TYPES } from '../../flowSteps';

const emit = defineEmits(['add']);

const { t } = useI18n();

const isOpen = ref(false);

const groups = computed(() =>
  FLOW_STEP_CATEGORIES.map(category => ({
    ...category,
    title: t(`AUTOMATION.FLOW.CANVAS.CATEGORY.${category.key.toUpperCase()}`),
    steps: FLOW_STEP_TYPES.filter(step => step.category === category.key),
  })).filter(group => group.steps.length)
);

const colorClasses = {
  blue: 'bg-n-blue-3 text-n-blue-11',
  indigo: 'bg-n-indigo-3 text-n-indigo-11',
  amber: 'bg-n-amber-3 text-n-amber-11',
  teal: 'bg-n-teal-3 text-n-teal-11',
  violet: 'bg-n-violet-3 text-n-violet-11',
};
</script>

<template>
  <Popover align="start" @show="isOpen = true" @hide="isOpen = false">
    <template #default>
      <Button
        icon="i-lucide-plus"
        size="sm"
        color="blue"
        :variant="isOpen ? 'faded' : 'solid'"
        :label="t('AUTOMATION.FLOW.ADD_STEP')"
      />
    </template>
    <template #content="{ hide }">
      <div class="flex flex-col gap-1 p-2 w-80 max-h-[26rem] overflow-y-auto">
        <DropdownSection
          v-for="group in groups"
          :key="group.key"
          :title="group.title"
          height="max-h-none"
        >
          <li v-for="definition in group.steps" :key="definition.type">
            <button
              type="button"
              class="flex items-start w-full gap-3 p-2 text-left rounded-lg hover:bg-n-alpha-2"
              @click="
                emit('add', definition.type);
                hide();
              "
            >
              <span
                class="flex items-center justify-center rounded-lg size-7 shrink-0"
                :class="colorClasses[group.color]"
              >
                <Icon :icon="definition.icon" class="size-4" />
              </span>
              <span class="flex flex-col min-w-0">
                <span class="text-sm font-medium text-n-slate-12">
                  {{
                    t(`AUTOMATION.FLOW.STEP.${definition.type.toUpperCase()}`)
                  }}
                </span>
                <span class="text-xs text-n-slate-10 line-clamp-2">
                  {{
                    t(
                      `AUTOMATION.FLOW.STEP_DESCRIPTION.${definition.type.toUpperCase()}`
                    )
                  }}
                </span>
              </span>
            </button>
          </li>
        </DropdownSection>
      </div>
    </template>
  </Popover>
</template>
