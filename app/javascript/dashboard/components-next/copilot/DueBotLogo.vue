<script setup>
// Duas versoes da logo: a de fundo claro e a de fundo escuro (so' uma aparece,
// conforme o tema). Quem usa define o tamanho e o recorte pela classe.
//
// Os caminhos ficam em variaveis, e nao em `src="/brand-assets/..."` no
// template: o compilador do Vue transforma um `src` absoluto estatico em
// `import`, e o Vite nao resolve arquivo de `public/` por import - o build de
// producao (assets:precompile) falhava com "Rollup failed to resolve import".
// O arquivo e' servido direto de `public/`, igual ao Logo.vue.
const LOGO_LIGHT = '/brand-assets/duebot.webp';
const LOGO_DARK = '/brand-assets/duebot_dark.webp';
</script>

<template>
  <span class="inline-block shrink-0 overflow-hidden rounded-full">
    <img
      :src="LOGO_LIGHT"
      alt=""
      class="block size-full object-cover dark:hidden"
    />
    <img
      :src="LOGO_DARK"
      alt=""
      class="hidden size-full object-cover dark:block"
    />
  </span>
</template>
