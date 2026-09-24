<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WootLabel from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const isRequeued = computed(() => !!props.chat.requeued_at);
const label = computed(() => t('CHAT_LIST.QUEUE.REQUEUED_LABEL'));
</script>

<template>
  <WootLabel v-if="isRequeued" :label="label" color="amber" compact />
</template>
