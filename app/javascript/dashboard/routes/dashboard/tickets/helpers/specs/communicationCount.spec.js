import { communicationCount } from '../communicationCount';

describe('communicationCount', () => {
  it('soma os comentarios internos e as mensagens ao cliente', () => {
    const ticket = {
      internal_comments_count: 2,
      customer_communications: [{ id: 1 }, { id: 2 }, { id: 3 }],
    };

    expect(communicationCount(ticket, undefined)).toBe(5);
  });

  it('mostra so os internos quando nao ha mensagem ao cliente', () => {
    expect(communicationCount({ internal_comments_count: 2 }, undefined)).toBe(
      2
    );
  });

  it('da zero para um ticket sem nenhuma comunicacao', () => {
    expect(communicationCount({}, undefined)).toBe(0);
    expect(communicationCount(null, undefined)).toBe(0);
  });

  it('usa a lista da store quando a aba ja foi aberta, para atualizar na hora', () => {
    const ticket = {
      internal_comments_count: 2,
      customer_communications: [{ id: 1 }],
    };

    // Um terceiro comentario foi feito depois de o ticket ser lido.
    expect(communicationCount(ticket, [{}, {}, {}])).toBe(4);
    // E uma lista vazia (todos apagados) vale zero, nao o numero do servidor.
    expect(communicationCount(ticket, [])).toBe(1);
  });
});
