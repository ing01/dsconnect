import { onBeforeUnmount, watch } from 'vue';

// Quanto da ultima mensagem pode estar fora da tela e a conversa ainda contar como "no fim".
export const STICK_THRESHOLD_PX = 80;

/**
 * Mantem a conversa colada na ultima mensagem, como um chat.
 *
 * - `follow()` leva ao fim e liga o "acompanhar": usado ao abrir a conversa e ao enviar.
 * - Enquanto acompanha, qualquer crescimento do conteudo (mensagem nova, imagem que termina de
 *   carregar, previa) rola de novo ate o fim - por isso a conversa abre na ultima mensagem mesmo
 *   que a altura mude depois da primeira rolagem.
 * - Se a pessoa rola para cima para ler o historico, o acompanhar desliga e nada a puxa de volta;
 *   ao voltar ate o fim ele liga de novo.
 *
 * O elemento que rola e o que cresce nem sempre existem na montagem (a conversa so aparece depois
 * de escolhida), por isso a ligacao acontece quando as referencias aparecem.
 *
 * @param {import('vue').Ref<HTMLElement|null>} scrollerRef quem rola
 * @param {import('vue').Ref<HTMLElement|null>} contentRef quem cresce (o miolo da lista)
 */
export const useStickToBottom = (scrollerRef, contentRef) => {
  let pinned = true;

  const distanceFromEnd = element =>
    element.scrollHeight - element.clientHeight - element.scrollTop;

  const toBottom = () => {
    const element = scrollerRef.value;
    if (element) element.scrollTop = element.scrollHeight;
  };

  const follow = () => {
    pinned = true;
    toBottom();
  };

  const onScroll = () => {
    const element = scrollerRef.value;
    if (element) pinned = distanceFromEnd(element) <= STICK_THRESHOLD_PX;
  };

  const stopWatching = watch(
    [scrollerRef, contentRef],
    ([scroller, content], _previous, onCleanup) => {
      if (!scroller) return;

      scroller.addEventListener('scroll', onScroll, { passive: true });
      let observer = null;
      if (content && typeof ResizeObserver !== 'undefined') {
        observer = new ResizeObserver(() => {
          if (pinned) toBottom();
        });
        observer.observe(content);
      }

      onCleanup(() => {
        scroller.removeEventListener('scroll', onScroll);
        observer?.disconnect();
      });
    },
    { immediate: true, flush: 'post' }
  );

  onBeforeUnmount(stopWatching);

  return { follow, isFollowing: () => pinned };
};
