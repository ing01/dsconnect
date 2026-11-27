import { mount } from '@vue/test-utils';
import MessageBody from '../components/MessageBody.vue';
import { parseMessage } from '../helpers/messageParser';

const links = (body, users) =>
  parseMessage(body, users).filter(part => part.type === 'link');
const text = (body, users) =>
  parseMessage(body, users)
    .map(part => part.value)
    .join('');

describe('Chat Interno - links', () => {
  it('abre o endereco em uma nova aba', () => {
    const wrapper = mount(MessageBody, {
      props: { body: 'veja http://pop-suporte-duesoft.netlify.app/#nfse' },
    });
    const anchor = wrapper.find('a');

    expect(anchor.attributes('href')).toBe(
      'http://pop-suporte-duesoft.netlify.app/#nfse'
    );
    expect(anchor.attributes('target')).toBe('_blank');
    expect(anchor.attributes('rel')).toBe('noopener noreferrer');
  });

  it('nao confunde numero ou nome dentro do endereco', () => {
    const body = 'https://site.com/#1234/@Ana e o ticket #38016';
    const parts = parseMessage(body, [{ id: 1, name: 'Ana' }]);

    expect(parts.map(part => part.type)).toEqual(['link', 'text', 'ticket']);
    expect(parts[0].value).toBe('https://site.com/#1234/@Ana');
  });

  it('deixa a pontuacao da frase fora do link', () => {
    const body = '(veja https://a.com/x). Ou www.b.com.br, ok?';

    expect(links(body).map(part => part.value)).toEqual([
      'https://a.com/x',
      'www.b.com.br',
    ]);
    expect(links(body)[1].href).toBe('https://www.b.com.br');
    expect(text(body)).toBe(body);
  });

  it('mantem o parentese que faz parte do endereco', () => {
    expect(links('https://a.com/wiki/Nota_(fiscal)')[0].value).toBe(
      'https://a.com/wiki/Nota_(fiscal)'
    );
  });

  it('segue marcando mencao e ticket, com ou sem lista de pessoas', () => {
    expect(parseMessage('#38016')[0]).toMatchObject({
      type: 'ticket',
      id: 38016,
    });
    expect(parseMessage('@Ana', [{ id: 1, name: 'Ana' }])[0]).toMatchObject({
      type: 'mention',
      id: 1,
    });
  });

  it('nao cria link para outros protocolos', () => {
    // eslint-disable-next-line no-script-url
    expect(links('javascript:alert(1)')).toEqual([]);
  });
});
