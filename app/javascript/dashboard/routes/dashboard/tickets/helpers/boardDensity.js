import { LocalStorage } from 'shared/helpers/localStorage';

// O Kanban tem dois tamanhos: confortavel (cards cheios, colunas de 288 px) e compacto
// (colunas de 240 px e cards de poucas linhas, para caberem varios tickets na tela). Sem
// escolha da pessoa, o tamanho segue a tela: em monitor pequeno (ex.: 1280x800) o compacto
// entra sozinho. Uma vez escolhido no botao do Kanban, vale a escolha, em qualquer tela.
const DENSITY_KEY = 'ticket-kanban-density';

export const DENSITY_COMPACT = 'compact';
export const DENSITY_COMFORTABLE = 'comfortable';

// Abaixo disto a tela e' "pequena" para o Kanban confortavel. 1440 de largura separa o
// notebook/monitor de 1280 e 1366 dos de 1600 ou mais; 860 de altura pega as telas 16:10
// de 800 e as de 768, onde o cabecalho do Kanban ja' come metade da altura.
export const AUTO_COMPACT_WIDTH = 1440;
export const AUTO_COMPACT_HEIGHT = 860;

/**
 * A escolha guardada da pessoa, se houver.
 * @returns {'compact'|'comfortable'|null} null = segue o tamanho da tela
 */
export const readDensityPreference = () => {
  const stored = LocalStorage.get(DENSITY_KEY);
  return stored === DENSITY_COMPACT || stored === DENSITY_COMFORTABLE
    ? stored
    : null;
};

/**
 * Guarda a escolha da pessoa; null volta a seguir a tela.
 * @param {'compact'|'comfortable'|null} density escolha
 */
export const writeDensityPreference = density => {
  if (density) LocalStorage.set(DENSITY_KEY, density);
  else LocalStorage.remove(DENSITY_KEY);
};

/**
 * O Kanban deve usar o modo compacto?
 * @param {'compact'|'comfortable'|null} preference escolha da pessoa
 * @param {number} width largura da janela (px)
 * @param {number} height altura da janela (px)
 * @returns {boolean} true para compacto
 */
export const isCompactBoard = (preference, width, height) => {
  if (preference === DENSITY_COMPACT) return true;
  if (preference === DENSITY_COMFORTABLE) return false;

  return width < AUTO_COMPACT_WIDTH || height < AUTO_COMPACT_HEIGHT;
};
