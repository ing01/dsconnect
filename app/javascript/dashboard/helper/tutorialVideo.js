// Como o video de um tutorial vai para a tela, a partir do que o administrador
// cadastrou: um link (YouTube/Vimeo viram player embutido; qualquer outro link e'
// tratado como arquivo de video) ou um arquivo enviado.

const YOUTUBE =
  /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([\w-]{11})/;
const VIMEO = /vimeo\.com\/(?:video\/)?(\d+)/;

// `iframe` (YouTube/Vimeo) ou `video` (arquivo). Sem endereco, devolve null.
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

// O que a tela mostra para um tutorial vindo do servidor: o arquivo enviado
// tem prioridade sobre o link (o servidor nunca guarda os dois).
export const tutorialVideo = tutorial =>
  resolveTutorialVideo(tutorial.video_file_url || tutorial.video_url);
