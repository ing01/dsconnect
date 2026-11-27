import {
  DRAFT_TTL,
  MAX_DRAFTS,
  clearAllDrafts,
  draftKey,
  readDraft,
  reloadDrafts,
  writeDraft,
} from '../textDrafts';
import { clearLocalStorageOnLogout } from 'dashboard/store/utils/api';

const saved = () => JSON.parse(localStorage.getItem('textDrafts') || '{}');

describe('textDrafts', () => {
  beforeEach(() => {
    localStorage.clear();
    reloadDrafts();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
  });

  it('separa por conta, usuario, tipo e destino', () => {
    const key = draftKey({ accountId: 1, userId: 2, scope: 'chat', id: 3 });

    expect(key).toBe('1:2:chat:3');
  });

  it.each([
    { userId: 2, id: 3 },
    { accountId: 1, id: 3 },
    { accountId: 1, userId: 2 },
  ])('sem conta, usuario ou destino nao ha chave: %o', parts => {
    expect(draftKey({ scope: 'chat', ...parts })).toBeNull();
  });

  it('guarda no navegador e volta depois de recarregar', () => {
    writeDraft('a', 'texto');
    reloadDrafts();

    expect(readDraft('a')).toBe('texto');
  });

  it('texto vazio apaga, mas espaco no comeco e guardado', () => {
    writeDraft('a', '  ');
    expect(readDraft('a')).toBe('  ');

    writeDraft('a', '');
    expect(saved()).toEqual({});
  });

  it('sem chave nao guarda nada', () => {
    writeDraft(null, 'texto');

    expect(saved()).toEqual({});
  });

  it('vence em 7 dias', () => {
    vi.useFakeTimers();
    writeDraft('a', 'antigo');

    vi.advanceTimersByTime(DRAFT_TTL - 1000);
    reloadDrafts();
    expect(readDraft('a')).toBe('antigo');

    vi.advanceTimersByTime(2000);
    reloadDrafts();
    expect(readDraft('a')).toBe('');
  });

  it('passando do limite, descarta os mais antigos', () => {
    vi.useFakeTimers();
    for (let index = 0; index <= MAX_DRAFTS; index += 1) {
      writeDraft(`k${index}`, 'x');
      vi.advanceTimersByTime(10);
    }

    expect(Object.keys(saved())).toHaveLength(MAX_DRAFTS);
    expect(readDraft('k0')).toBe('');
    expect(readDraft(`k${MAX_DRAFTS}`)).toBe('x');
  });

  it('nao apaga o que outra aba do navegador escreveu', () => {
    writeDraft('a', 'desta aba');
    localStorage.setItem(
      'textDrafts',
      JSON.stringify({ ...saved(), b: { text: 'da outra', at: Date.now() } })
    );

    writeDraft('a', 'desta aba, de novo');

    expect(saved().b.text).toBe('da outra');
  });

  it('com o armazenamento cheio, o texto continua na tela', () => {
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('QuotaExceededError');
    });

    writeDraft('a', 'um');
    writeDraft('b', 'dois');

    expect(readDraft('a')).toBe('um');
    expect(readDraft('b')).toBe('dois');
  });

  it('com o armazenamento bloqueado, nao quebra', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('SecurityError');
    });
    reloadDrafts();

    writeDraft('a', 'um');

    expect(readDraft('a')).toBe('um');
  });

  it.each(['{quebrado', '"texto"', '{"a":null,"b":{"text":5}}'])(
    'ignora conteudo estragado: %s',
    value => {
      localStorage.setItem('textDrafts', value);
      reloadDrafts();

      expect(readDraft('a')).toBe('');
      writeDraft('c', 'novo');
      expect(readDraft('c')).toBe('novo');
    }
  );

  it('sair da conta apaga os rascunhos', () => {
    writeDraft('a', 'segredo');

    clearLocalStorageOnLogout();

    expect(readDraft('a')).toBe('');
    expect(localStorage.getItem('textDrafts')).toBeNull();
  });

  it('clearAllDrafts nao falha sem armazenamento', () => {
    vi.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => {
      throw new Error('SecurityError');
    });

    expect(clearAllDrafts).not.toThrow();
  });
});
