import { ref } from 'vue';

// So' reage a arrasto de ARQUIVO do computador. Arrastar texto selecionado ou um
// link dentro da pagina tambem dispara dragenter, mas sem "Files" nos types.
const carriesFiles = event =>
  Array.from(event.dataTransfer?.types || []).includes('Files');

// Zona de soltar arquivos, como no Discord: a area toda aceita o arquivo.
// `isEnabled` e `onFiles` sao funcoes para poderem olhar o estado atual da tela.
export const useFileDrop = ({ isEnabled, onFiles }) => {
  const isDragging = ref(false);
  // dragenter/dragleave disparam tambem ao passar por cada elemento filho; sem o
  // contador o aviso piscava toda vez que o arquivo cruzava uma mensagem.
  let depth = 0;

  const reset = () => {
    depth = 0;
    isDragging.value = false;
  };

  const onDragEnter = event => {
    if (!isEnabled() || !carriesFiles(event)) return;
    event.preventDefault();
    depth += 1;
    isDragging.value = true;
  };

  const onDragOver = event => {
    if (!isEnabled() || !carriesFiles(event)) return;
    // Sem o preventDefault o navegador nao aceita o drop (e abriria o arquivo).
    event.preventDefault();
    if (event.dataTransfer) event.dataTransfer.dropEffect = 'copy';
  };

  const onDragLeave = event => {
    if (!isDragging.value || !carriesFiles(event)) return;
    depth = Math.max(0, depth - 1);
    if (depth === 0) isDragging.value = false;
  };

  const onDrop = event => {
    if (!isEnabled() || !carriesFiles(event)) return;
    event.preventDefault();
    reset();
    // Pasta chega como "arquivo" de tamanho 0 e nao da para enviar.
    const files = Array.from(event.dataTransfer.files || []).filter(
      file => file.size > 0
    );
    if (files.length) onFiles(files);
  };

  return { isDragging, onDragEnter, onDragOver, onDragLeave, onDrop };
};
