import {
  keepCurrentMembers,
  readAgentFilter,
  writeAgentFilter,
} from '../boardAgentFilter';

describe('boardAgentFilter (o filtro de agente do Kanban sobrevive a troca de aba)', () => {
  beforeEach(() => window.localStorage.clear());

  it('guarda e devolve os agentes filtrados, por conta e por Mesa', () => {
    writeAgentFilter(1, 10, [5, 7]);

    expect(readAgentFilter(1, 10)).toEqual([5, 7]);
    expect(readAgentFilter(1, 11)).toEqual([]);
    expect(readAgentFilter(2, 10)).toEqual([]);
  });

  it('lista vazia apaga o registro (voltar a todos)', () => {
    writeAgentFilter(1, 10, [5]);

    writeAgentFilter(1, 10, []);

    expect(readAgentFilter(1, 10)).toEqual([]);
    expect(
      window.localStorage.getItem('ticket-kanban-agent-filter::1::10')
    ).toBeNull();
  });

  it('ignora um registro estragado', () => {
    window.localStorage.setItem('ticket-kanban-agent-filter::1::10', '"texto"');
    expect(readAgentFilter(1, 10)).toEqual([]);

    window.localStorage.setItem(
      'ticket-kanban-agent-filter::1::10',
      '[5,"x",-1,null,7]'
    );
    expect(readAgentFilter(1, 10)).toEqual([5, 7]);
  });
});

describe('keepCurrentMembers', () => {
  it('tira do filtro quem saiu da Mesa e mantem quem continua', () => {
    expect(keepCurrentMembers([5, 7, 9], [{ id: 5 }, { id: 9 }])).toEqual([
      5, 9,
    ]);
  });
});
