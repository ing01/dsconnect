import { plainChatText } from '../clientChatText';

describe('plainChatText', () => {
  it('troca a barra de quebra do Markdown por uma quebra de linha', () => {
    expect(plainChatText('Olá!\\\n\\\nAguarde')).toBe('Olá!\n\nAguarde');
  });

  it('aceita espaços depois da barra e quebra no estilo Windows', () => {
    expect(plainChatText('a\\ \r\nb')).toBe('a\nb');
  });

  it('mantém barras no meio da linha', () => {
    expect(plainChatText('C:\\pasta\\arquivo')).toBe('C:\\pasta\\arquivo');
  });

  it('aguenta texto vazio ou ausente', () => {
    expect(plainChatText(null)).toBe('');
    expect(plainChatText(undefined)).toBe('');
  });
});
