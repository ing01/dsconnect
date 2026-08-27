<script setup>
import { computed } from 'vue';
import { parseMessage } from '../helpers/messageParser';
import { TICKETS } from '../helpers/mockData';

const props = defineProps({
  body: { type: String, default: '' },
  users: { type: Array, default: () => [] },
});

const emit = defineEmits(['openTicket']);

const parts = computed(() => parseMessage(props.body, props.users));

// O título do Ticket vem de dados mockados. No sistema real isto vira uma
// leitura da API, mas o formato do que a tela desenha não muda.
const ticketFor = id => TICKETS[id];
</script>

<template>
  <span class="text-sm leading-relaxed break-words text-n-slate-12">
    <template v-for="(part, index) in parts" :key="index">
      <!-- Uma menção é um destaque, não um link: ninguém "abre" uma pessoa. -->
      <span
        v-if="part.type === 'mention'"
        class="px-1 py-0.5 rounded font-medium text-n-blue-11 bg-n-blue-3"
      >
        {{ part.value }}
      </span>

      <!-- Já a referência a um Ticket leva mesmo ao Ticket. -->
      <button
        v-else-if="part.type === 'ticket'"
        type="button"
        class="inline-flex items-baseline gap-1 px-1 py-0.5 rounded font-medium align-baseline text-n-teal-11 bg-n-teal-3 hover:bg-n-teal-4"
        :title="ticketFor(part.id)?.title"
        @click="emit('openTicket', part.id)"
      >
        {{ part.value }}
        <span
          v-if="ticketFor(part.id)"
          class="text-xs font-normal truncate max-w-[16rem]"
        >
          {{ ticketFor(part.id).title }}
        </span>
      </button>

      <template v-else>{{ part.value }}</template>
    </template>
  </span>
</template>
