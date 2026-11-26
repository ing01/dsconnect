<script setup>
import { computed } from 'vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';

// A FILA da conversa, para quem olha a lista saber de cara para qual fila o
// atendimento entrou (Comercial, Especialista, Suporte...). So' a fila, de
// proposito: a Mesa do ticket vinculado ou o Time da conversa confundiam - o
// selo dizia "Suporte" para conversa que estava na fila de outra caixa
// (pedido da Ingrid, 2026-11-26). Sem fila, nao aparece selo.
const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const queueName = computed(() => props.chat.meta?.queue?.name);
</script>

<template>
  <WootLabel v-if="queueName" :label="queueName" color="iris" compact />
</template>
