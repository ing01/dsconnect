/**
 * Dados de demonstração do protótipo do Chat Interno.
 *
 * Tudo aqui é mock: nenhuma tabela, nenhum endpoint. O objetivo é validar a
 * experiência antes de decidir a arquitetura, então este arquivo é o único
 * lugar que precisa desaparecer quando o backend real entrar.
 */

const minutesAgo = minutes => Date.now() - minutes * 60 * 1000;

export const CURRENT_USER_ID = 1;

export const USERS = [
  { id: 1, name: 'João Vitor', role: 'Suporte', status: 'online' },
  { id: 2, name: 'Maria Silva', role: 'Suporte', status: 'online' },
  { id: 3, name: 'Carla Reis', role: 'Implantação', status: 'online' },
  { id: 4, name: 'Diego Melo', role: 'Desenvolvimento', status: 'offline' },
  { id: 5, name: 'Bruno Souza', role: 'Comercial', status: 'offline' },
];

/**
 * Tickets que o Chat consegue exibir quando alguém escreve `#numero`.
 * No sistema real isto vira uma consulta; aqui é uma tabela de apoio.
 */
export const TICKETS = {
  32516: { id: 32516, title: 'Erro na emissão da nota', status: 'open' },
  32498: { id: 32498, title: 'Importação de XML travando', status: 'open' },
  32077: { id: 32077, title: 'Treinamento do módulo fiscal', status: 'closed' },
};

const message = (id, userId, body, minutes, extras = {}) => ({
  id,
  userId,
  body,
  createdAt: minutesAgo(minutes),
  reactions: [],
  ...extras,
});

export const CHANNELS = [
  {
    id: 'c-geral',
    name: 'geral',
    description: 'Avisos que valem para a empresa toda',
    memberIds: [1, 2, 3, 4, 5],
    unread: 0,
    messages: [
      message('m-g1', 5, 'Pessoal, a reunião de quinta mudou para 15h.', 320),
      message('m-g2', 3, 'Anotado, obrigada!', 318),
    ],
  },
  {
    id: 'c-suporte',
    name: 'suporte',
    description: 'Canal da equipe de suporte',
    memberIds: [1, 2, 3, 4, 5, 6, 7, 8],
    unread: 5,
    messages: [
      message('m-s1', 2, 'O cliente da ROMAFELE retornou?', 62),
      message(
        'm-s2',
        1,
        'Sim. Vinculei a conversa ao Ticket #32516 para não perdermos o histórico.',
        58
      ),
      message('m-s3', 3, 'O problema parece estar na versão nova.', 47),
      message(
        'm-s4',
        3,
        'Consegui reproduzir com o XML que eles mandaram.',
        46
      ),
      message('m-s5', 4, '@Carla Reis consegue me mandar esse XML?', 41, {
        mentions: [3],
      }),
      message('m-s6', 3, 'Claro, segue o retorno da SEFAZ.', 38, {
        attachment: {
          kind: 'file',
          name: 'log-erro.txt',
          size: '24 KB',
        },
      }),
      message('m-s7', 4, 'Vou verificar com desenvolvimento.', 30, {
        reactions: [{ emoji: '👍', userIds: [1, 2, 3] }],
      }),
      message(
        'm-s8',
        2,
        'Enquanto isso avisei o cliente que estamos analisando.',
        22,
        { replyTo: 'm-s7' }
      ),
    ],
  },
  {
    id: 'c-implantacao',
    name: 'implantação',
    description: 'Acompanhamento das implantações em andamento',
    memberIds: [1, 3, 5],
    unread: 0,
    messages: [
      message('m-i1', 3, 'Implantação da Nortex fechada hoje.', 180),
      message('m-i2', 5, 'Ótimo. Já aviso o comercial.', 176),
    ],
  },
  {
    id: 'c-comercial',
    name: 'comercial',
    description: 'Negociações, propostas e renovações',
    memberIds: [1, 5],
    unread: 0,
    messages: [message('m-co1', 5, 'Proposta da Vale Verde enviada.', 240)],
  },
  {
    id: 'c-desenvolvimento',
    name: 'desenvolvimento',
    description: 'Bugs, releases e revisão de código',
    memberIds: [1, 4],
    unread: 2,
    messages: [
      message('m-d1', 4, 'Subi a correção do #32498 em homologação.', 95),
      message('m-d2', 4, 'Precisa de um teste antes de ir para produção.', 94),
    ],
  },
];

export const DIRECTS = [
  {
    id: 'd-maria',
    userId: 2,
    unread: 3,
    messages: [
      message('m-dm1', 2, 'Conseguiu verificar o retorno da ROMAFELE?', 35),
      message('m-dm2', 1, 'Estou olhando agora, já te falo.', 33),
      message('m-dm3', 2, 'Combinado. O #32516 é o mesmo caso?', 28, {}),
      message('m-dm4', 2, 'Mandei o print da tela do cliente:', 26, {
        attachment: {
          kind: 'image',
          name: 'tela-erro.png',
          size: '318 KB',
          // Placeholder desenhado localmente: nenhum host externo, porque a
          // política de conteúdo do produto bloqueia imagem de fora.
          color: '#3f5c78',
        },
      }),
      message('m-dm5', 2, 'Conseguiu verificar?', 25),
    ],
  },
  {
    id: 'd-carlos',
    userId: 4,
    unread: 0,
    messages: [
      message('m-dc1', 4, 'Bom dia! O deploy de ontem passou limpo.', 400),
      message('m-dc2', 1, 'Perfeito, obrigado por avisar.', 395),
    ],
  },
  {
    id: 'd-ana',
    userId: 3,
    unread: 0,
    messages: [
      message(
        'm-da1',
        3,
        'Te mandei o cronograma da implantação por e-mail.',
        500
      ),
    ],
  },
];

export const QUICK_REACTIONS = ['👍', '❤️', '😂', '✅'];
