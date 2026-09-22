// Curated list of product updates shown on the Principal page.
// Not auto-generated from git commits: commit messages are written for
// developers, not for the people using the product, and a real design change
// needs a human to pick the before/after colors. Add a new entry here (top of
// the array = most recent) whenever a change is worth telling the team about.
//
// `isoDate` (YYYY-MM-DD) drives the 5-day auto-hide in getVisibleChangelogEntries;
// `date` is only the pt-BR label shown on the card, so both must be kept in sync.
export const CHANGELOG_ENTRIES = [
  {
    id: 'whatsapp-auto-assignment-controls',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Controle da distribuição automática do WhatsApp',
    description:
      'Nova seção em Configurações > Automação: ligar/desligar a distribuição automática, definir um limite de conversas abertas por agente e marcar agentes que ficam de fora da distribuição automática (mas continuam podendo ser atribuídos na mão).',
  },
  {
    id: 'contracts-products',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Contratos e Produtos',
    description:
      'Nova tela de Contratos: responsável, tipo, empresas participantes e uma ou mais linhas de produto (com valor, licenças e implantação). Produtos ganharam cadastro próprio em Configurações. A cobrança da Empresa agora vem do contrato vinculado, editável manualmente quando precisar.',
  },
  {
    id: 'company-billing-layout',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'design',
    title: 'Cadastro de Empresa centralizado + data automática',
    description:
      'Corrigimos o formulário de Empresa que estava puxado pra direita. A "Data de início do uso do sistema" agora vem sozinha do Projeto de implantação quando existir um, e só é editável a mão pra clientes sem Projeto.',
  },
  {
    id: 'contact-company-search',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Busca de empresa no cadastro de contato',
    description:
      'Vincular uma Empresa a um contato agora tem busca de verdade, em vez de digitar o nome solto.',
  },
  {
    id: 'whatsapp-astere-zap',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Novo provedor de WhatsApp: AstereZap',
    description:
      'A integração de WhatsApp passou a suportar a AstereZap além da Meta, com proteção contra conversas duplicadas e simulação de digitação nas respostas automáticas.',
  },
  {
    id: 'automation-test-mode',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Modo de teste da automação do WhatsApp',
    description:
      'Nova tela em Configurações > Automação pra restringir as respostas automáticas a um único número de teste, sem precisar mexer em código.',
  },
  {
    id: 'automation-flow-descriptions',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'design',
    title: 'Fluxo de automação mais claro',
    description:
      'Cada etapa do editor de fluxo de automação agora mostra uma descrição do que ela faz.',
  },
  {
    id: 'company-priority-colors',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'design',
    title: 'Cores na prioridade do cliente',
    description:
      'Baixa, Média e Alta agora aparecem em verde, laranja e vermelho no cadastro da Empresa.',
  },
  {
    id: 'company-required-fields',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'design',
    title: 'Cadastro de Empresa mais simples',
    description:
      'Removemos o campo de domínio do cadastro de empresa. Agora só nome e CNPJ são obrigatórios.',
    comparison: {
      kind: 'text',
      before: 'Nome',
      after: 'Nome + CNPJ',
    },
  },
  {
    id: 'excel-import',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'feature',
    title: 'Importação por planilha na tela Dados',
    description:
      'Nova aba "Planilhas" em Configurações > Dados: importe Clientes (empresas e contatos) e o Catálogo de Serviços a partir de um Excel, com planilha modelo pra baixar e conferência de erros linha a linha.',
  },
  {
    id: 'projects-filters',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'design',
    title: 'Filtros da tela de Projetos renovados',
    description:
      'Seletores de Equipe, Implantador e Módulo com visual mais moderno, e as abas Ativos/Concluídos agora usam o degradê azul da marca.',
  },
  {
    id: 'principal-page',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'feature',
    title: 'Nova página "Principal"',
    description:
      'Ao entrar no sistema, você cai aqui em vez de direto nas conversas: uma saudação de boas-vindas e esta lista de novidades.',
  },
  {
    id: 'conversation-empty-state',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'design',
    title: '"Selecione uma conversa" no lugar da saudação',
    description:
      'A tela de conversas passou a mostrar a mesma ilustração de balãozinho usada nos outros estados vazios, já que a saudação agora mora na página Principal.',
  },
  {
    id: 'duesoft-logo',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'design',
    title: 'Nova logo em toda a plataforma',
    description:
      'Trocamos o ícone da aba do navegador, o login e a barra lateral pela nova marca da Duesoft.',
  },
  {
    id: 'gradient-buttons',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'design',
    title: 'Botões ganharam um novo visual',
    description:
      'Os botões principais agora usam um degradê azul → verde-água, seguindo a nova identidade visual da Duesoft.',
    comparison: {
      kind: 'color',
      before: '#2781F6',
      after: ['#2781F6', '#12A594'],
    },
  },
  {
    id: 'sidebar-size',
    date: '17 de setembro de 2026',
    isoDate: '2026-09-17',
    type: 'design',
    title: 'Menu lateral maior e mais legível',
    description:
      'Ícones e textos do menu lateral, incluindo o cabeçalho com a logo e o nome da conta, ficaram maiores.',
  },
  {
    id: 'dsconnect-rebrand',
    date: '16 de setembro de 2026',
    isoDate: '2026-09-16',
    type: 'design',
    title: 'Nova marca: DSConnect',
    description:
      'Trocamos o nome em toda a plataforma — na aba do navegador, na barra lateral e na tela de login.',
    comparison: {
      kind: 'text',
      before: 'Duesoft',
      after: 'DSConnect',
    },
  },
  {
    id: 'implementation-reports',
    date: '8 de setembro de 2026',
    isoDate: '2026-09-08',
    type: 'feature',
    title: 'Painel de Implantação',
    description:
      'Novo painel com relatórios de horas, ranking por implantador, distribuição por módulo e incidência de tickets no pós-implantação.',
  },
];

const VISIBLE_DAYS = 5;

// A novidade some a partir do 5º dia depois de `isoDate` (fica visível no dia
// da publicação + 4 dias seguintes). `referenceDate` só existe para facilitar
// teste manual; em produção sempre é "agora".
export const getVisibleChangelogEntries = (
  entries = CHANGELOG_ENTRIES,
  referenceDate = new Date()
) =>
  entries.filter(entry => {
    const cutoff = new Date(`${entry.isoDate}T00:00:00`);
    cutoff.setDate(cutoff.getDate() + VISIBLE_DAYS);
    return referenceDate < cutoff;
  });
