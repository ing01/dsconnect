<script setup>
import { computed } from 'vue';

const props = defineProps({
  // Em pixels (ex.: 24) ou pelo nome do tamanho: 'xs' | 'sm' | 'md' | 'lg' | 'xl'.
  size: {
    type: [Number, String],
    default: 24,
  },
});

const DEFAULT_SIZE = 24;
const MIN_SIZE = 8;
const MAX_SIZE = 64;
const SIZE_NAMES = { xs: 12, sm: 16, md: 24, lg: 32, xl: 40 };

// Sempre devolve um numero de pixels valido. Um width/height que o <svg> nao
// entende (ex.: size="lg") faz o icone ocupar o container inteiro - era o
// "icone gigantesco" que estourava a tela ate a pagina carregar.
const pixelSize = computed(() => {
  const raw = props.size;
  const named =
    typeof raw === 'string' ? SIZE_NAMES[raw.trim().toLowerCase()] : undefined;
  const value = named ?? Number.parseFloat(raw);
  if (!Number.isFinite(value) || value <= 0) return DEFAULT_SIZE;
  return Math.min(Math.max(value, MIN_SIZE), MAX_SIZE);
});
</script>

<template>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    :width="pixelSize"
    :height="pixelSize"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="8"
    strokeLinecap="round"
    strokeLinejoin="round"
    class="animate-spin"
  >
    <path d="M21 12a9 9 0 1 1-6.219-8.56" />
  </svg>
</template>
