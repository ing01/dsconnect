/**
 * O título mostrado ao lado de uma referência `#numero` numa mensagem.
 *
 * AINDA É MOCK. O link já leva ao Ticket de verdade; o que não existe é a
 * consulta que traria o título. Enquanto ela não chega, um número fora desta
 * tabela aparece só como `#numero`, sem título - e continua clicável.
 */
const KNOWN_TICKETS = {
  32516: { id: 32516, title: 'Erro na emissão da nota' },
  32498: { id: 32498, title: 'Importação de XML travando' },
  32077: { id: 32077, title: 'Treinamento do módulo fiscal' },
};

/**
 * @param {number} id número do ticket citado na mensagem
 * @returns {object|undefined} o ticket, quando conhecido
 */
export const ticketPreview = id => KNOWN_TICKETS[id];
