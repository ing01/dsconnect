<script setup>
import { computed } from 'vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';

// A Mesa do ticket vinculado a esta conversa (ver `ticket_team_name` no
// partial de conversa) - ao lado do nome de quem atende, pra qualquer Mesa
// olhando a lista saber se aquele assunto e' dela ou de outro time.
const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const mesa = computed(() => props.chat.ticket_team_name);
</script>

<template>
  <WootLabel v-if="mesa" :label="mesa" color="iris" compact />
</template>
