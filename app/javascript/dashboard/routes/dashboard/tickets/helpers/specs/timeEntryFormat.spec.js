import {
  formatClock,
  formatDuration,
  joinHours,
  splitHours,
} from '../timeEntryFormat';

describe('formatClock (relogio do cronometro)', () => {
  it('mostra horas, minutos e segundos com dois digitos', () => {
    expect(formatClock(0)).toBe('00:00:00');
    expect(formatClock(9)).toBe('00:00:09');
    expect(formatClock(65)).toBe('00:01:05');
    expect(formatClock(3600 + 5 * 60 + 9)).toBe('01:05:09');
  });

  it('passa de 24 horas sem voltar a zero', () => {
    expect(formatClock(100 * 3600)).toBe('100:00:00');
  });

  it('ignora a parte fracionaria e valores invalidos', () => {
    expect(formatClock(59.9)).toBe('00:00:59');
    expect(formatClock(-5)).toBe('00:00:00');
    expect(formatClock(undefined)).toBe('00:00:00');
  });
});

describe('splitHours e joinHours (editar as horas)', () => {
  it('separa as horas decimais em horas e minutos', () => {
    expect(splitHours(1.5)).toEqual({ hours: 1, minutes: 30 });
    expect(splitHours('0.25')).toEqual({ hours: 0, minutes: 15 });
    expect(splitHours(2)).toEqual({ hours: 2, minutes: 0 });
  });

  it('junta horas e minutos em horas decimais de 2 casas', () => {
    expect(joinHours(1, 30)).toBe(1.5);
    expect(joinHours(1, 25)).toBe(1.42);
    expect(joinHours(0, 15)).toBe(0.25);
    expect(joinHours('2', '')).toBe(2);
  });

  it('ida e volta nao muda o valor de minutos inteiros', () => {
    const { hours, minutes } = splitHours(joinHours(3, 45));

    expect([hours, minutes]).toEqual([3, 45]);
  });
});

describe('formatDuration (lista de apontamentos)', () => {
  it('escreve em horas e minutos', () => {
    expect(formatDuration(1.5)).toBe('1h30min');
    expect(formatDuration(2)).toBe('2h');
    expect(formatDuration(0.75)).toBe('45min');
    expect(formatDuration(1.08)).toBe('1h05min');
  });

  it('um lancamento menor que um minuto nao vira zero', () => {
    expect(formatDuration(0.01)).toBe('1min'); // 36 s arredondam para 1 min
    expect(formatDuration(0.004)).toBe('<1min');
    expect(formatDuration(0)).toBe('0min');
  });
});
