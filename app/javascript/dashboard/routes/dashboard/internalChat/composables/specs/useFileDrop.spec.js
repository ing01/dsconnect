import { useFileDrop } from '../useFileDrop';

const evento = (types = ['Files'], files = []) => ({
  dataTransfer: { types, files, dropEffect: '' },
  preventDefault: vi.fn(),
});

describe('useFileDrop', () => {
  it('mostra o aviso ao arrastar arquivo e some ao sair da area', () => {
    const drop = useFileDrop({ isEnabled: () => true, onFiles: vi.fn() });

    drop.onDragEnter(evento());
    drop.onDragEnter(evento()); // entrou num elemento filho
    expect(drop.isDragging.value).toBe(true);

    drop.onDragLeave(evento()); // saiu do filho, ainda dentro
    expect(drop.isDragging.value).toBe(true);
    drop.onDragLeave(evento());
    expect(drop.isDragging.value).toBe(false);
  });

  it('ignora arrasto de texto e de link', () => {
    const drop = useFileDrop({ isEnabled: () => true, onFiles: vi.fn() });
    const ev = evento(['text/plain']);

    drop.onDragEnter(ev);

    expect(drop.isDragging.value).toBe(false);
    expect(ev.preventDefault).not.toHaveBeenCalled();
  });

  it('ao soltar, entrega os arquivos (sem pastas) e fecha o aviso', () => {
    const onFiles = vi.fn();
    const drop = useFileDrop({ isEnabled: () => true, onFiles });
    const foto = { name: 'a.png', size: 10 };
    const pasta = { name: 'pasta', size: 0 };

    drop.onDragEnter(evento());
    const ev = evento(['Files'], [foto, pasta]);
    drop.onDrop(ev);

    expect(ev.preventDefault).toHaveBeenCalled();
    expect(onFiles).toHaveBeenCalledWith([foto]);
    expect(drop.isDragging.value).toBe(false);
  });

  it('nao reage quando a sala esta somente leitura', () => {
    const onFiles = vi.fn();
    const drop = useFileDrop({ isEnabled: () => false, onFiles });

    drop.onDragEnter(evento());
    drop.onDrop(evento(['Files'], [{ name: 'a', size: 1 }]));

    expect(drop.isDragging.value).toBe(false);
    expect(onFiles).not.toHaveBeenCalled();
  });
});
