<script setup>
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  selectedCount: { type: Number, required: true },
});

const emit = defineEmits(['clear', 'editFields']);

const { t } = useI18n();
</script>

<template>
  <Transition
    enter-active-class="transition-all duration-200 ease-out origin-bottom"
    enter-from-class="opacity-0 scale-95 translate-y-2"
    enter-to-class="opacity-100 scale-100 translate-y-0"
    leave-active-class="transition-all duration-150 ease-in origin-bottom"
    leave-from-class="opacity-100 scale-100 translate-y-0"
    leave-to-class="opacity-0 scale-95 translate-y-2"
  >
    <div
      v-if="selectedCount > 0"
      class="px-2 fixed bottom-4 left-1/2 -translate-x-1/2 z-30 w-full max-w-md origin-bottom"
    >
      <div
        class="flex items-center justify-between gap-2 p-2 bg-n-solid-2 outline outline-1 -outline-offset-1 rounded-[10px] outline-n-weak shadow-[0_0_12px_0_rgba(27,40,59,0.08)]"
      >
        <div class="flex items-center gap-2 min-w-0">
          <span class="text-sm text-n-slate-12 px-1 truncate">
            {{
              t('TICKET.BACKLOG.BULK_SELECTED_COUNT', {
                count: selectedCount,
              })
            }}
          </span>
          <NextButton
            :label="t('TICKET.BACKLOG.BULK_CLEAR_SELECTION')"
            variant="link"
            color="slate"
            size="xs"
            @click="emit('clear')"
          />
        </div>

        <NextButton
          :label="t('TICKET.BACKLOG.BULK_EDIT_FIELDS')"
          icon="i-lucide-pencil"
          color="blue"
          size="sm"
          class="flex-shrink-0"
          @click="emit('editFields')"
        />
      </div>
    </div>
  </Transition>
</template>
