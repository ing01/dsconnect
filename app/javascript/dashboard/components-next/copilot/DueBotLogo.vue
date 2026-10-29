<script setup>
// Duas versoes da logo: a de fundo claro e a de fundo escuro (so' uma aparece,
// conforme o tema). Quem usa define o tamanho e o recorte pela classe.
</script>

<template>
  <span class="inline-block shrink-0 overflow-hidden rounded-full">
    <img
      src="/brand-assets/duebot.webp"
      alt=""
      class="block size-full object-cover dark:hidden"
    />
    <img
      src="/brand-assets/duebot_dark.webp"
      alt=""
      class="hidden size-full object-cover dark:block"
    />
  </span>
</template>
