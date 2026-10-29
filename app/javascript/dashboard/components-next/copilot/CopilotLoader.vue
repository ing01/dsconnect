<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';

// Enquanto a resposta nao chega, so' frases leves que se revezam - nada de
// mostrar as acoes/ferramentas que a IA esta usando por tras.
const PHRASE_KEYS = [
  'CAPTAIN.COPILOT.LOADER_PHRASES.ONE',
  'CAPTAIN.COPILOT.LOADER_PHRASES.TWO',
  'CAPTAIN.COPILOT.LOADER_PHRASES.THREE',
  'CAPTAIN.COPILOT.LOADER_PHRASES.FOUR',
];
const ROTATE_EVERY_MS = 3500;

const index = ref(0);
const phraseKey = computed(() => PHRASE_KEYS[index.value]);
let timer = null;

onMounted(() => {
  timer = setInterval(() => {
    index.value = Math.min(index.value + 1, PHRASE_KEYS.length - 1);
  }, ROTATE_EVERY_MS);
});

onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <div class="flex justify-start" role="status" aria-live="polite">
    <div class="flex items-center gap-2">
      <span class="i-lucide-sparkles size-4 text-n-teal-9 animate-pulse" />
      <span class="text-n-slate-11 font-medium">
        {{ $t(phraseKey) }}
      </span>
      <div class="flex space-x-1">
        <div
          class="w-1.5 h-1.5 rounded-full bg-n-teal-9 animate-bounce [animation-delay:-0.3s]"
        />
        <div
          class="w-1.5 h-1.5 rounded-full bg-n-teal-9 animate-bounce [animation-delay:-0.15s]"
        />
        <div class="w-1.5 h-1.5 rounded-full bg-n-teal-9 animate-bounce" />
      </div>
    </div>
  </div>
</template>
