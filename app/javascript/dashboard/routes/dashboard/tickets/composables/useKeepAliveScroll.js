import { nextTick, onActivated, onBeforeUnmount, onMounted } from 'vue';

// Uma tela guardada pelo KeepAlive volta com os mesmos elementos, mas o navegador zera a rolagem
// deles quando saem da pagina - e a tela voltava para o topo. Aqui a rolagem de cada elemento
// dentro da tela e' anotada enquanto a pessoa rola (no momento de sair, o DOM ja' foi tirado e
// leria zero) e devolvida quando a tela volta a ser mostrada.
export const useKeepAliveScroll = rootRef => {
  const positions = new Map();
  let root = null;

  const remember = event => {
    const element = event.target;
    if (!(element instanceof Element)) return;
    positions.set(element, {
      top: element.scrollTop,
      left: element.scrollLeft,
    });
  };

  onMounted(() => {
    root = rootRef.value;
    // `scroll` nao borbulha, mas a captura pega o de qualquer elemento de dentro.
    root?.addEventListener('scroll', remember, true);
  });

  onBeforeUnmount(() => {
    root?.removeEventListener('scroll', remember, true);
    positions.clear();
  });

  onActivated(() => {
    if (!positions.size) return;
    nextTick(() => {
      requestAnimationFrame(() => {
        positions.forEach(({ top, left }, element) => {
          if (!element.isConnected) {
            positions.delete(element);
            return;
          }
          element.scrollTop = top;
          element.scrollLeft = left;
        });
      });
    });
  });
};
