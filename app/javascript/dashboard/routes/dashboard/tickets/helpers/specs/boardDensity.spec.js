import {
  isCompactBoard,
  readDensityPreference,
  writeDensityPreference,
} from '../boardDensity';

describe('isCompactBoard', () => {
  it('segue a tela quando a pessoa nao escolheu', () => {
    expect(isCompactBoard(null, 1280, 800)).toBe(true);
    expect(isCompactBoard(null, 1366, 768)).toBe(true);
    // largura boa, mas altura curta: o cabecalho come o quadro
    expect(isCompactBoard(null, 1920, 820)).toBe(true);
    // altura boa, mas largura curta
    expect(isCompactBoard(null, 1280, 1024)).toBe(true);
    expect(isCompactBoard(null, 1920, 1080)).toBe(false);
    expect(isCompactBoard(null, 1440, 900)).toBe(false);
  });

  it('a escolha da pessoa vale em qualquer tela', () => {
    expect(isCompactBoard('compact', 1920, 1080)).toBe(true);
    expect(isCompactBoard('comfortable', 1280, 800)).toBe(false);
  });
});

describe('preferencia guardada', () => {
  beforeEach(() => window.localStorage.clear());

  it('comeca sem escolha', () => {
    expect(readDensityPreference()).toBeNull();
  });

  it('guarda e le a escolha, e null volta a seguir a tela', () => {
    writeDensityPreference('compact');
    expect(readDensityPreference()).toBe('compact');

    writeDensityPreference('comfortable');
    expect(readDensityPreference()).toBe('comfortable');

    writeDensityPreference(null);
    expect(readDensityPreference()).toBeNull();
  });

  it('ignora um valor estranho guardado', () => {
    window.localStorage.setItem('ticket-kanban-density', '"enorme"');
    expect(readDensityPreference()).toBeNull();
  });
});
