// Baixa as imagens ANTES de a tela aparecer, para o Chat abrir ja com as fotos em
// vez de mostrar as iniciais e ir trocando uma a uma.
//
// Nunca trava a tela: uma foto que falha conta como carregada, e o conjunto todo
// tem um teto de tempo - rede lenta ou imagem quebrada nao pode deixar o Chat
// preso no carregamento.
const loadOne = url =>
  new Promise(resolve => {
    const image = new Image();
    image.onload = resolve;
    image.onerror = resolve;
    image.src = url;
  });

export const preloadImages = (urls, { timeout = 2500, limit = 60 } = {}) => {
  const unique = [...new Set((urls || []).filter(Boolean))].slice(0, limit);
  if (!unique.length) return Promise.resolve();

  return Promise.race([
    Promise.all(unique.map(loadOne)),
    new Promise(resolve => {
      setTimeout(resolve, timeout);
    }),
  ]);
};
