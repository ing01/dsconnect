import {
  continuesBlock,
  dayLabel,
  startsNewDay,
} from '../helpers/messageParser';

const at = (day, hour = 12, minute = 0) =>
  Math.floor(new Date(2026, 10, day, hour, minute).getTime() / 1000);

describe('mudanca de dia no chat interno', () => {
  it('a primeira mensagem abre um dia', () => {
    expect(startsNewDay({ createdAt: at(9) }, undefined)).toBe(true);
  });

  it('mensagens no mesmo dia nao abrem um dia novo', () => {
    expect(
      startsNewDay({ createdAt: at(9, 18) }, { createdAt: at(9, 8) })
    ).toBe(false);
  });

  it('o dia muda na virada da meia-noite, mesmo com poucos minutos de diferenca', () => {
    const before = { createdAt: at(4, 23, 58) };
    const after = { createdAt: at(5, 0, 1) };

    expect(startsNewDay(after, before)).toBe(true);
  });

  it('a data sai por extenso em portugues', () => {
    expect(dayLabel(at(9), 'pt_BR')).toBe('9 de novembro de 2026');
    expect(dayLabel(at(4), 'pt-BR')).toBe('4 de novembro de 2026');
  });

  it('quem escreve logo depois da virada do dia volta a mostrar avatar e nome', () => {
    const before = { userId: 1, createdAt: at(4, 23, 58) };
    const after = { userId: 1, createdAt: at(5, 0, 1) };

    expect(continuesBlock(after, before)).toBe(false);
  });

  it('o agrupamento no mesmo dia continua igual', () => {
    const before = { userId: 1, createdAt: at(4, 10, 0) };
    const after = { userId: 1, createdAt: at(4, 10, 2) };

    expect(continuesBlock(after, before)).toBe(true);
  });
});
