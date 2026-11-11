import { moduleFromTitle, stripModule, withModule } from '../titleModule';

const NAMES = ['DS Comercial', 'DS Estoque', 'DS PDV'];

describe('moduleFromTitle', () => {
  it('reconhece o modulo no comeco do titulo', () => {
    expect(moduleFromTitle('[DS Comercial] ERRO AO GERAR NOTAS', NAMES)).toBe(
      'DS Comercial'
    );
  });

  it('nao confunde com texto no meio do titulo ou modulo desconhecido', () => {
    expect(moduleFromTitle('Erro no [DS Comercial] hoje', NAMES)).toBeNull();
    expect(moduleFromTitle('[Outro] teste', NAMES)).toBeNull();
    expect(moduleFromTitle('', NAMES)).toBeNull();
    expect(moduleFromTitle(undefined, NAMES)).toBeNull();
  });
});

describe('stripModule', () => {
  it('tira so o modulo do comeco', () => {
    expect(stripModule('[DS PDV] teste', NAMES)).toBe('teste');
    expect(stripModule('sem modulo', NAMES)).toBe('sem modulo');
  });
});

describe('withModule', () => {
  it('poe o modulo no comeco do titulo', () => {
    expect(withModule('ERRO AO GERAR NOTAS', 'DS Comercial', NAMES)).toBe(
      '[DS Comercial] ERRO AO GERAR NOTAS'
    );
  });

  it('troca o modulo que ja estava, sem acumular', () => {
    expect(withModule('[DS Comercial] teste', 'DS Estoque', NAMES)).toBe(
      '[DS Estoque] teste'
    );
  });

  it('com o titulo vazio, deixa so o modulo pronto para continuar a digitar', () => {
    expect(withModule('', 'DS PDV', NAMES)).toBe('[DS PDV] ');
  });

  it('sem modulo (limpar) tira o do comeco e preserva o resto', () => {
    expect(withModule('[DS PDV] teste', null, NAMES)).toBe('teste');
    expect(withModule('teste', null, NAMES)).toBe('teste');
  });
});
