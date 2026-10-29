<script setup>
defineProps({
  size: {
    type: String,
    default: 'md',
    validator: value => ['md', 'lg'].includes(value),
  },
});

// "DueBot" no mesmo degrade azul -> verde-agua dos botoes principais
// (ver Button.vue), com um brilho que passa devagar pelo texto.
const BOT_NAME = 'DueBot';
</script>

<template>
  <span
    class="duebot-name inline-flex items-center gap-1.5 font-semibold tracking-wide"
    :class="size === 'lg' ? 'text-xl' : 'text-sm'"
  >
    <img
      src="/brand-assets/duebot.webp"
      alt=""
      class="shrink-0 object-contain"
      :class="size === 'lg' ? 'size-12' : 'size-6'"
    />
    <span class="duebot-name__text">{{ BOT_NAME }}</span>
  </span>
</template>

<style scoped>
.duebot-name__text {
  background-image: linear-gradient(
    110deg,
    rgb(var(--blue-9, 59 130 246)) 0%,
    rgb(var(--teal-9, 20 184 166)) 45%,
    rgb(var(--blue-9, 59 130 246)) 90%
  );
  background-size: 200% 100%;
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  animation: duebot-shimmer 6s ease-in-out infinite;
}

@keyframes duebot-shimmer {
  0%,
  100% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
}

@media (prefers-reduced-motion: reduce) {
  .duebot-name__text {
    animation: none;
  }
}
</style>
