// O modulo do sistema (DS Comercial, DS Estoque...) no inicio do titulo do ticket, no
// formato que a equipe ja usa: "[DS Comercial] ERRO AO GERAR NOTAS EM LOTE".
// Nada e' guardado a parte: o modulo e' so' texto do titulo, entao aqui ele e' sempre
// reconhecido pelo proprio titulo - sem estado para ficar fora de sincronia.

const tag = name => `[${name}] `;

/**
 * O modulo que o titulo ja traz no comeco, se for um dos conhecidos.
 * @param {string} title titulo digitado
 * @param {string[]} names nomes dos modulos cadastrados
 * @returns {string|null} o nome do modulo, ou null
 */
export const moduleFromTitle = (title, names = []) => {
  const text = String(title || '');
  return names.find(name => text.startsWith(tag(name))) || null;
};

/**
 * O titulo sem o modulo do comeco.
 * @param {string} title titulo digitado
 * @param {string[]} names nomes dos modulos cadastrados
 * @returns {string} o titulo sem o "[Modulo] " inicial
 */
export const stripModule = (title, names = []) => {
  const text = String(title || '');
  const current = moduleFromTitle(text, names);
  return current ? text.slice(tag(current).length) : text;
};

/**
 * Poe o modulo no comeco do titulo, trocando o que ja estava la.
 * @param {string} title titulo digitado
 * @param {string|null} name modulo escolhido; vazio tira o modulo
 * @param {string[]} names nomes dos modulos cadastrados
 * @returns {string} o titulo com `[Modulo] ` no inicio (ou sem modulo)
 */
export const withModule = (title, name, names = []) => {
  const bare = stripModule(title, names);
  return name ? `${tag(name)}${bare}` : bare;
};
