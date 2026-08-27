<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  attachment: { type: Object, default: null },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const style = computed(() => ({
  background: `linear-gradient(135deg, ${props.attachment?.color || '#3f5c78'}, #23303d)`,
}));
</script>

<template>
  <div
    v-if="attachment"
    class="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 p-6 bg-black/70"
    role="dialog"
    aria-modal="true"
    @click.self="emit('close')"
    @keydown.esc="emit('close')"
  >
    <button
      type="button"
      class="absolute p-2 text-white rounded top-4 end-4 hover:bg-white/10"
      :title="t('INTERNAL_CHAT.IMAGE.CLOSE')"
      @click="emit('close')"
    >
      <Icon icon="i-lucide-x" class="size-5" />
    </button>

    <div
      class="flex items-center justify-center w-full max-w-3xl h-[60vh] rounded-lg text-white/80"
      :style="style"
    >
      {{ attachment.name }}
    </div>
    <p class="text-sm text-white/70">
      {{ attachment.name }} · {{ attachment.size }}
    </p>
  </div>
</template>
