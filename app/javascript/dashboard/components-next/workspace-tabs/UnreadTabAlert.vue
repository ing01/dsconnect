<script setup>
import { onBeforeUnmount, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useUnreadAlerts } from 'dashboard/composables/useUnreadAlerts';
import { withTitleAlert } from './unreadAlerts';

// Sem desenho: cuida de duas coisas que nao tem lugar na tela.
//  1) mantem o aviso das conversas atualizado (busca ao abrir, ao voltar para a aba
//     e ao reconectar - o resto chega pelo tempo real);
//  2) poe o "(!) " no titulo da aba do navegador e o selo no favicon enquanto ha
//     mensagem nao lida (conversa minha ou chat interno).
const store = useStore();
const { any } = useUnreadAlerts();

const refresh = () => store.dispatch('unreadAssigned/fetch');

// O titulo muda sozinho (cada tela poe o seu): observa e reaplica o aviso sem
// acumular prefixos.
let titleObserver = null;

const applyTitle = () => {
  const next = withTitleAlert(document.title, any.value);
  if (next !== document.title) document.title = next;
};

// Troca o favicon pelo da versao com selo (ja existe em /public). So' as
// versoes que existem: 16, 32 e 96.
const BADGED = ['16x16', '32x32', '96x96'];

const applyFavicon = () => {
  document.querySelectorAll('.favicon').forEach(link => {
    // Pelo atributo (`sizes="32x32"`): funciona em qualquer navegador.
    const size = link.getAttribute('sizes')?.split(' ')[0];
    if (!BADGED.includes(size)) return;

    const file = any.value
      ? `/favicon-badge-${size}.png`
      : `/favicon-${size}.png`;
    if (!link.getAttribute('href')?.endsWith(file)) link.href = file;
  });
};

const apply = () => {
  applyTitle();
  applyFavicon();
};

// O helper de som volta o favicon ao normal quando a aba fica visivel; reaplica
// depois dele, se ainda ha aviso.
const onVisible = () => {
  if (document.visibilityState !== 'visible') return;
  refresh();
  setTimeout(apply, 0);
};

onMounted(() => {
  refresh();
  document.addEventListener('visibilitychange', onVisible);
  const titleElement = document.querySelector('title');
  if (titleElement) {
    titleObserver = new MutationObserver(applyTitle);
    titleObserver.observe(titleElement, { childList: true });
  }
  apply();
});

onBeforeUnmount(() => {
  document.removeEventListener('visibilitychange', onVisible);
  titleObserver?.disconnect();
  store.dispatch('unreadAssigned/clear');
  // Sai sem deixar o aviso preso no titulo e no favicon.
  document.title = withTitleAlert(document.title, false);
});

watch(any, apply);
</script>

<template>
  <span class="hidden" aria-hidden="true" />
</template>
