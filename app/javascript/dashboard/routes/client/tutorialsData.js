// Os tutoriais da Área do Cliente (aba "Tutoriais"). Mantidos por código, como as
// novidades do Portal (`principalData.js`): para publicar um vídeo, preencha
// `videoUrl` do tutorial correspondente - sem ele, a tela mostra "vídeo em breve".
//
// `videoUrl` aceita:
//  - link do YouTube (watch?v=, youtu.be/ ou embed/) ou do Vimeo - vira player embutido;
//  - um arquivo de vídeo (.mp4, .webm) - por exemplo um arquivo colocado em
//    `public/tutoriais/ativar-notificacoes.mp4` e informado como
//    '/tutoriais/ativar-notificacoes.mp4'.
//
// Os textos (título, descrição e passos) ficam em `CLIENT_AREA.TUTORIALS.<KEY>`
// nos arquivos de idioma; aqui só a ordem, a chave e o vídeo.
export const TUTORIALS = [
  {
    id: 'notifications',
    key: 'NOTIFICATIONS',
    icon: 'i-lucide-bell-ring',
    videoUrl: '',
  },
];

const YOUTUBE =
  /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([\w-]{11})/;
const VIMEO = /vimeo\.com\/(?:video\/)?(\d+)/;

// Como o vídeo vai para a tela: `iframe` (YouTube/Vimeo) ou `video` (arquivo).
// Sem endereço, devolve null.
export const resolveTutorialVideo = url => {
  const value = (url || '').trim();
  if (!value) return null;

  const youtube = value.match(YOUTUBE);
  if (youtube) {
    return {
      type: 'iframe',
      src: `https://www.youtube.com/embed/${youtube[1]}`,
    };
  }

  const vimeo = value.match(VIMEO);
  if (vimeo) {
    return {
      type: 'iframe',
      src: `https://player.vimeo.com/video/${vimeo[1]}`,
    };
  }

  return { type: 'video', src: value };
};
