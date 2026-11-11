import {
  categoryForTeamName,
  formatClock,
  formatDuration,
  hoursToClock,
  hoursToSeconds,
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

describe('hoursToSeconds e hoursToClock (a dica ao passar o mouse)', () => {
  it('converte as horas gravadas em segundos exatos', () => {
    expect(hoursToSeconds(1.5)).toBe(5400);
    expect(hoursToSeconds('0.0333')).toBe(120);
    expect(hoursToSeconds(0.0167)).toBe(60);
  });

  it('a dica mostra o mesmo tempo da lista, e nao horas decimais', () => {
    expect(hoursToClock('0.0333')).toBe('00:02:00');
    expect(hoursToClock('1.5')).toBe('01:30:00');
  });
});

describe('splitHours e joinHours (editar as horas)', () => {
  it('separa as horas decimais em horas e minutos', () => {
    expect(splitHours(1.5)).toEqual({ hours: 1, minutes: 30 });
    expect(splitHours('0.25')).toEqual({ hours: 0, minutes: 15 });
    expect(splitHours(2)).toEqual({ hours: 2, minutes: 0 });
  });

  it('junta horas e minutos em horas decimais de 4 casas', () => {
    expect(joinHours(1, 30)).toBe(1.5);
    expect(joinHours(1, 25)).toBe(1.4167);
    expect(joinHours(0, 1)).toBe(0.0167);
    expect(joinHours('2', '')).toBe(2);
  });

  it('ida e volta nao muda o valor de minutos inteiros', () => {
    [1, 2, 7, 25, 59].forEach(minutes => {
      expect(splitHours(joinHours(0, minutes)).minutes).toBe(minutes);
    });
    expect(splitHours(joinHours(3, 45))).toEqual({ hours: 3, minutes: 45 });
  });

  it('1 minuto mais 2 minutos dao 3 minutos (com 2 casas davam 2)', () => {
    const total = joinHours(0, 1) + joinHours(0, 2);

    expect(formatDuration(total)).toBe('3min');
  });
});

describe('formatDuration (lista e total dos apontamentos)', () => {
  it('escreve em horas e minutos', () => {
    expect(formatDuration(1.5)).toBe('1h30min');
    expect(formatDuration(2)).toBe('2h');
    expect(formatDuration(0.75)).toBe('45min');
  });

  it('mostra os segundos, sem arredondar para o minuto', () => {
    expect(formatDuration(0.0353)).toBe('2min07s');
    expect(formatDuration(0.0167)).toBe('1min');
    expect(formatDuration(0.0003)).toBe('1s');
    expect(formatDuration(1 + 5 / 60 + 12 / 3600)).toBe('1h05min12s');
  });

  it('zero e invalido viram 0min', () => {
    expect(formatDuration(0)).toBe('0min');
    expect(formatDuration(undefined)).toBe('0min');
  });
});

describe('categoryForTeamName (a Mesa define a categoria do apontamento)', () => {
  it('Mesa de Implantacao -> implantacao', () => {
    expect(categoryForTeamName('Implantação')).toBe('implantacao');
    expect(categoryForTeamName('Mesa de Implantacao')).toBe('implantacao');
  });

  it('Mesa de Desenvolvimento -> desenvolvimento', () => {
    expect(categoryForTeamName('Desenvolvimento')).toBe('desenvolvimento');
    expect(categoryForTeamName('DS DESENVOLVIMENTO')).toBe('desenvolvimento');
  });

  it('Dev geral -> dev_geral', () => {
    expect(categoryForTeamName('Dev geral')).toBe('dev_geral');
    expect(categoryForTeamName('Dev. Geral')).toBe('dev_geral');
  });

  it('ignora acento e maiuscula', () => {
    expect(categoryForTeamName('IMPLANTAÇÃO')).toBe('implantacao');
    expect(categoryForTeamName('DESENVOLVIMENTO')).toBe('desenvolvimento');
  });

  it('outra Mesa nao decide: devolve null para valer o padrao', () => {
    expect(categoryForTeamName('Suporte')).toBeNull();
    expect(categoryForTeamName('')).toBeNull();
    expect(categoryForTeamName(undefined)).toBeNull();
  });
});
