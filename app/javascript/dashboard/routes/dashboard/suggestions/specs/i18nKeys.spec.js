import fs from 'fs';
import path from 'path';
import ptBR from 'dashboard/i18n/locale/pt_BR/suggestions.json';
import en from 'dashboard/i18n/locale/en/suggestions.json';

// A regressao que isto fixa: Prioridade, Categoria e tempo gasto foram para a
// tela sem que ninguem criasse as traducoes, e os rotulos apareciam como a
// propria chave na cara do usuario - "SUGGESTIONS.PRIORITY.LABEL" no lugar de
// "Prioridade". Chave que falta e invisivel ate alguem abrir aquela tela, por
// isso o modulo inteiro e varrido aqui, como no equivalente de Tickets.
const ROOT = path.resolve(__dirname, '../../../..');

const DIRECTORIES = [
  'routes/dashboard/suggestions/components',
  'routes/dashboard/suggestions/pages',
  'routes/dashboard/settings/suggestions',
  'routes/dashboard/principal/components',
];

// A secao das listas configuraveis monta as chaves a partir de um prefixo, e
// esses usos nao aparecem em nenhuma busca por texto literal - foi exatamente
// ali que as traducoes faltaram.
const SECTION = path.join(
  ROOT,
  'routes/dashboard/settings/suggestions/SuggestionSimpleListSection.vue'
);
const SECTION_PREFIXES = [
  'SUGGESTIONS.PRIORITY_SETTINGS',
  'SUGGESTIONS.CATEGORY_SETTINGS',
];

const LOCALES = { pt_BR: ptBR, en };

const LITERAL = /\$?t\(\s*['"](SUGGESTIONS\.[A-Z0-9_.]+)['"]/g;
const PREFIXED = /tt\('([A-Z0-9_.]+)'\)/g;

const matchesOf = (source, pattern) =>
  [...source.matchAll(pattern)].map(match => match[1]);

const collectFiles = () =>
  DIRECTORIES.flatMap(directory => {
    const full = path.join(ROOT, directory);
    if (!fs.existsSync(full)) return [];
    return fs
      .readdirSync(full)
      .filter(name => name.endsWith('.vue'))
      .map(name => path.join(full, name));
  });

const lookup = (tree, dotted) =>
  dotted.split('.').reduce((node, part) => {
    if (!node || typeof node !== 'object') return undefined;
    return node[part];
  }, tree);

const literalKeys = () =>
  collectFiles().flatMap(file => {
    const source = fs.readFileSync(file, 'utf8');
    return matchesOf(source, LITERAL).map(key => [path.basename(file), key]);
  });

const prefixedKeys = () => {
  const suffixes = matchesOf(fs.readFileSync(SECTION, 'utf8'), PREFIXED);
  return SECTION_PREFIXES.flatMap(prefix =>
    suffixes.map(suffix => [
      `${path.basename(SECTION)} (${prefix})`,
      `${prefix}.${suffix}`,
    ])
  );
};

describe('suggestions i18n keys', () => {
  it('finds the components to check', () => {
    expect(collectFiles().length).toBeGreaterThan(5);
  });

  it('finds the prefixed keys of the configurable lists', () => {
    expect(prefixedKeys().length).toBeGreaterThan(20);
  });

  describe.each(Object.keys(LOCALES))('%s', locale => {
    const tree = { SUGGESTIONS: LOCALES[locale].SUGGESTIONS };

    it('resolves every literal key the screens ask for', () => {
      const missing = literalKeys()
        .filter(([, key]) => lookup(tree, key) === undefined)
        .map(([file, key]) => `${file} -> ${key}`);

      expect(missing).toEqual([]);
    });

    // Cada lista configuravel precisa do conjunto COMPLETO: uma chave a menos
    // e um botao escrito "SUGGESTIONS.CATEGORY_SETTINGS.ADD".
    it('resolves every key the configurable lists build from their prefix', () => {
      const missing = prefixedKeys()
        .filter(([, key]) => lookup(tree, key) === undefined)
        .map(([file, key]) => `${file} -> ${key}`);

      expect(missing).toEqual([]);
    });

    it('never answers a key with the key itself', () => {
      const labels = [...literalKeys(), ...prefixedKeys()]
        .map(([, key]) => lookup(tree, key))
        .filter(value => typeof value === 'string');

      labels.forEach(label => expect(label).not.toMatch(/^SUGGESTIONS\./));
    });
  });

  // As duas listas sao a mesma forma; qualquer divergencia entre elas deixa uma
  // das duas telas incompleta.
  it('keeps both configurable lists with the same shape', () => {
    const shape = tree => JSON.stringify(Object.keys(tree).sort());
    Object.values(LOCALES).forEach(locale => {
      expect(shape(locale.SUGGESTIONS.PRIORITY_SETTINGS)).toEqual(
        shape(locale.SUGGESTIONS.CATEGORY_SETTINGS)
      );
    });
  });
});
