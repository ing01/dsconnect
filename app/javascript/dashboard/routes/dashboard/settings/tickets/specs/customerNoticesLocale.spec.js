import ptBR from 'dashboard/i18n/locale/pt_BR/ticket.json';
import en from 'dashboard/i18n/locale/en/ticket.json';

// Chaves duplas no texto de uma traducao sao sintaxe invalida do vue-i18n: o
// formulario de Mensagens ao cliente chegou a ficar em branco por causa disso.
const values = node =>
  typeof node === 'string' ? [node] : Object.values(node).flatMap(values);

describe('textos de Mensagens ao cliente', () => {
  it.each([
    ['pt_BR', ptBR],
    ['en', en],
  ])('%s nao usa chaves duplas nas traducoes', (_name, locale) => {
    const texts = values(locale.TICKET.SETTINGS.NOTICES);

    expect(texts.length).toBeGreaterThan(10);
    texts.forEach(text => expect(text).not.toContain('{{'));
  });
});
