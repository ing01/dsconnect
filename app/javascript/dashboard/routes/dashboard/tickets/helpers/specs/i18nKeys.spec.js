import fs from 'fs';
import path from 'path';
import ptBR from 'dashboard/i18n/locale/pt_BR/ticket.json';
import en from 'dashboard/i18n/locale/en/ticket.json';

// The regression this pins: the Prioridade select pointed at `TICKET.PRIORITY`,
// a namespace that never existed, so every option rendered as the raw key
// (`TICKET.PRIORITY.LOW`) in the user's face. A missing key is invisible until
// someone opens that screen, so the whole ticket module is swept here.
const ROOT = path.resolve(__dirname, '../../..');

const DIRECTORIES = [
  'tickets/components',
  'tickets/components/create',
  'tickets/components/detail',
  'tickets/components/detail/actions',
  'tickets/pages',
];

const collectFiles = () =>
  DIRECTORIES.flatMap(directory => {
    const full = path.join(ROOT, directory);
    if (!fs.existsSync(full)) return [];
    return fs
      .readdirSync(full)
      .filter(name => name.endsWith('.vue'))
      .map(name => path.join(full, name));
  });

const LOCALES = { pt_BR: ptBR, en };

const lookup = (tree, dotted) =>
  dotted.split('.').reduce((node, part) => {
    if (!node || typeof node !== 'object') return undefined;
    return node[part];
  }, tree);

// Only TICKET.* keys are checked; the rest live in other locale files.
const LITERAL = /\$?t\(\s*['"](TICKET\.[A-Z0-9_.]+)['"]/g;
// `t(\`TICKET.FORM.PRIORITY.${...}\`)` - the namespace is what has to exist.
const TEMPLATE = /\$?t\(\s*`(TICKET\.[A-Z0-9_.]*)\$\{/g;

const matchesOf = (source, pattern) =>
  [...source.matchAll(pattern)].map(match => match[1]);

describe('ticket i18n keys', () => {
  const files = collectFiles();

  it('finds the components to check', () => {
    expect(files.length).toBeGreaterThan(10);
  });

  describe.each(Object.keys(LOCALES))('%s', locale => {
    const tree = { TICKET: LOCALES[locale].TICKET };

    it('resolves every literal key the components ask for', () => {
      const missing = files.flatMap(file =>
        matchesOf(fs.readFileSync(file, 'utf8'), LITERAL)
          .filter(key => lookup(tree, key) === undefined)
          .map(key => `${path.basename(file)} -> ${key}`)
      );

      expect(missing).toEqual([]);
    });

    it('resolves every interpolated namespace to an object of labels', () => {
      const missing = files.flatMap(file =>
        matchesOf(fs.readFileSync(file, 'utf8'), TEMPLATE)
          .map(prefix => prefix.replace(/\.$/, ''))
          .filter(namespace => {
            const node = lookup(tree, namespace);
            return !node || typeof node !== 'object';
          })
          .map(namespace => `${path.basename(file)} -> ${namespace}.*`)
      );

      expect(missing).toEqual([]);
    });
  });

  // The four values the Ticket model's enum accepts.
  describe('priority labels', () => {
    it.each(['LOW', 'MEDIUM', 'HIGH', 'URGENT'])(
      'has a translation for %s in every locale',
      value => {
        Object.values(LOCALES).forEach(locale =>
          expect(locale.TICKET.FORM.PRIORITY[value]).toBeTruthy()
        );
      }
    );

    it('reads as words, never as a key', () => {
      const labels = Object.values(ptBR.TICKET.FORM.PRIORITY);

      labels.forEach(label => expect(label).not.toMatch(/^TICKET\./));
    });
  });
});
