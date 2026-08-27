/**
 * Conteúdo de demonstração do protótipo do Chat Interno.
 *
 * As **pessoas não são mock**: o diretório vem dos agentes reais da conta, que
 * é com quem se espera conversar. O que continua simulado são as conversas e as
 * mensagens, montadas sobre esses agentes para que a tela tenha o que mostrar
 * antes de existir backend.
 *
 * As mensagens de exemplo referem-se aos agentes por posição (`slot`), e não por
 * id: assim o mesmo roteiro funciona em qualquer conta, tenha ela dois agentes
 * ou vinte.
 */

const minutesAgo = minutes => Date.now() - minutes * 60 * 1000;

/**
 * Tickets que o Chat exibe quando alguém escreve `#numero`.
 * No sistema real isto vira uma consulta; aqui é uma tabela de apoio.
 */
export const TICKETS = {
  32516: { id: 32516, title: 'Erro na emissão da nota', status: 'open' },
  32498: { id: 32498, title: 'Importação de XML travando', status: 'open' },
  32077: { id: 32077, title: 'Treinamento do módulo fiscal', status: 'closed' },
};

export const QUICK_REACTIONS = ['👍', '❤️', '😂', '✅'];

// Roteiro dos canais. `slot` é a posição no diretório de agentes.
const CHANNEL_TEMPLATES = [
  {
    id: 'c-geral',
    name: 'geral',
    description: 'Avisos que valem para a empresa toda',
    unread: 0,
    script: [
      {
        slot: 0,
        body: 'Pessoal, a reunião de quinta mudou para 15h.',
        at: 320,
      },
      { slot: 1, body: 'Anotado, obrigado!', at: 318 },
    ],
  },
  {
    id: 'c-suporte',
    name: 'suporte',
    description: 'Canal da equipe de suporte',
    unread: 5,
    script: [
      { slot: 1, body: 'O cliente da ROMAFELE retornou?', at: 62 },
      {
        slot: 0,
        body: 'Sim. Vinculei a conversa ao Ticket #32516 para não perdermos o histórico.',
        at: 58,
      },
      { slot: 2, body: 'O problema parece estar na versão nova.', at: 47 },
      {
        slot: 2,
        body: 'Consegui reproduzir com o XML que eles mandaram.',
        at: 46,
      },
      { slot: 3, body: '@{2} consegue me mandar esse XML?', at: 41 },
      {
        slot: 2,
        body: 'Claro, segue o retorno da SEFAZ.',
        at: 38,
        attachment: { kind: 'file', name: 'log-erro.txt', size: '24 KB' },
      },
      {
        slot: 3,
        body: 'Vou verificar com desenvolvimento.',
        at: 30,
        reactedBySlots: ['👍', [0, 1, 2]],
      },
      {
        slot: 1,
        body: 'Enquanto isso avisei o cliente que estamos analisando.',
        at: 22,
        replyToIndex: 6,
      },
    ],
  },
  {
    id: 'c-implantacao',
    name: 'implantação',
    description: 'Acompanhamento das implantações em andamento',
    unread: 0,
    script: [
      { slot: 2, body: 'Implantação da Nortex fechada hoje.', at: 180 },
      { slot: 0, body: 'Ótimo. Já aviso o comercial.', at: 176 },
    ],
  },
  {
    id: 'c-comercial',
    name: 'comercial',
    description: 'Negociações, propostas e renovações',
    unread: 0,
    script: [{ slot: 0, body: 'Proposta da Vale Verde enviada.', at: 240 }],
  },
  {
    id: 'c-desenvolvimento',
    name: 'desenvolvimento',
    description: 'Bugs, releases e revisão de código',
    unread: 2,
    script: [
      { slot: 3, body: 'Subi a correção do #32498 em homologação.', at: 95 },
      {
        slot: 3,
        body: 'Precisa de um teste antes de ir para produção.',
        at: 94,
      },
    ],
  },
];

// Conversas privadas de exemplo: `with` é a posição do colega no diretório,
// contando a partir do usuário logado.
const DIRECT_TEMPLATES = [
  {
    with: 1,
    unread: 3,
    script: [
      {
        fromMe: false,
        body: 'Conseguiu verificar o retorno da ROMAFELE?',
        at: 35,
      },
      { fromMe: true, body: 'Estou olhando agora, já te falo.', at: 33 },
      { fromMe: false, body: 'Combinado. O #32516 é o mesmo caso?', at: 28 },
      {
        fromMe: false,
        body: 'Mandei o print da tela do cliente:',
        at: 26,
        attachment: {
          kind: 'image',
          name: 'tela-erro.png',
          size: '318 KB',
          // Desenhado localmente: a política de conteúdo do produto bloqueia
          // imagem de host externo.
          color: '#3f5c78',
        },
      },
      { fromMe: false, body: 'Conseguiu verificar?', at: 25 },
    ],
  },
  {
    with: 2,
    unread: 0,
    script: [
      {
        fromMe: false,
        body: 'Bom dia! O deploy de ontem passou limpo.',
        at: 400,
      },
      { fromMe: true, body: 'Perfeito, obrigado por avisar.', at: 395 },
    ],
  },
  {
    with: 3,
    unread: 0,
    script: [
      {
        fromMe: false,
        body: 'Te mandei o cronograma da implantação por e-mail.',
        at: 500,
      },
    ],
  },
];

/**
 * Resolve a posição de um roteiro num agente de verdade.
 * Quando a conta tem menos agentes que o roteiro pede, as posições dão a volta,
 * para que nenhuma mensagem fique órfã.
 * @param {Array} users diretório de agentes
 * @param {number} slot posição pedida pelo roteiro
 * @returns {object|null} agente correspondente
 */
const at = (users, slot) => (users.length ? users[slot % users.length] : null);

/**
 * Monta as conversas de demonstração sobre os agentes reais da conta.
 * @param {Array} users diretório de agentes (o logado em primeiro)
 * @param {number} currentUserId id do usuário logado
 * @returns {{channels: Array, directs: Array}} salas prontas para o store
 */
export const buildDemoRooms = (users, currentUserId) => {
  if (!users.length) return { channels: [], directs: [] };

  const memberIds = users.map(user => user.id);

  const channels = CHANNEL_TEMPLATES.map(template => {
    const messages = template.script.map((line, index) => {
      const author = at(users, line.slot);
      const message = {
        id: `${template.id}-${index}`,
        userId: author.id,
        // `@{2}` no roteiro vira a menção ao agente daquela posição.
        body: line.body.replace(
          /@\{(\d+)\}/g,
          (_, slot) => `@${at(users, Number(slot)).name}`
        ),
        createdAt: minutesAgo(line.at),
        reactions: [],
      };

      if (line.attachment) message.attachment = line.attachment;
      if (line.replyToIndex !== undefined) {
        message.replyTo = `${template.id}-${line.replyToIndex}`;
      }
      if (line.reactedBySlots) {
        const [emoji, slots] = line.reactedBySlots;
        message.reactions = [
          { emoji, userIds: slots.map(slot => at(users, slot).id) },
        ];
      }
      return message;
    });

    return {
      id: template.id,
      name: template.name,
      description: template.description,
      memberIds,
      unread: template.unread,
      messages,
    };
  });

  // Uma conversa privada por colega, até três, para a tela nascer com conteúdo.
  const colleagues = users.filter(user => user.id !== currentUserId);
  const directs = DIRECT_TEMPLATES.slice(0, colleagues.length).map(
    (template, index) => {
      const peer = colleagues[index];
      return {
        id: `d-${peer.id}`,
        userId: peer.id,
        unread: template.unread,
        messages: template.script.map((line, position) => ({
          id: `d-${peer.id}-${position}`,
          userId: line.fromMe ? currentUserId : peer.id,
          body: line.body,
          createdAt: minutesAgo(line.at),
          reactions: [],
          ...(line.attachment ? { attachment: line.attachment } : {}),
        })),
      };
    }
  );

  return { channels, directs };
};
