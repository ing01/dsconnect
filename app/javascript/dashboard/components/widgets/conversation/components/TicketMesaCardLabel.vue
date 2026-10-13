<script setup>
import { computed } from 'vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';

// A Mesa da conversa, pra qualquer equipe olhando a lista saber de cara se
// aquele assunto e' dela ou de outro time. Duas fontes, por ordem:
//
// 1. A Mesa do TICKET vinculado (`ticket_team_name`) - quando existe, e' a
//    mais especifica (vem do Kanban proprio deste app).
// 2. O Time nativo da CONVERSA (`meta.team`, o "Atribuir Time" do menu da
//    conversa) - esse campo e' o que realmente existe na maioria das
//    conversas; o vinculo com um Ticket e' raro (so acontece em fluxos
//    pontuais - criar o ticket de dentro da conversa, ou uma automacao).
//    Sem este fallback, o rotulo quase nunca aparecia.
const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const mesa = computed(
  () => props.chat.ticket_team_name || props.chat.meta?.team?.name
);
</script>

<template>
  <WootLabel v-if="mesa" :label="mesa" color="iris" compact />
</template>
