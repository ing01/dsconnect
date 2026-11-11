<script setup>
// O "!" de aviso: nao e' contador, so' diz que ha mensagem nao lida esperando.
// Usado nas abas do topo e no menu lateral.
defineProps({
  label: { type: String, default: '' },
});
</script>

<template>
  <span
    role="img"
    data-testid="unread-alert"
    class="inline-grid flex-shrink-0 font-bold leading-none rounded-full size-4 place-items-center bg-n-ruby-9 text-white text-[10px]"
    :aria-label="label"
    :title="label"
  >
    {{ '!' }}
  </span>
</template>
