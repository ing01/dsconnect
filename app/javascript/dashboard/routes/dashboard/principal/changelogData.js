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
    id: 'ticket-import',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title: 'Importação de tickets de outro sistema (CSV)',
    description:
      'Nova tela em Configurações > Tickets > Importar: envie uma planilha CSV com os tickets de um sistema anterior (Número, Cliente, Título, Descrição, Status, Estágio, Contato, Time, Prioridade, Catálogo de Serviços, Ticket pai, Criado por, Criado em, Categoria, Data, Desenvolvimento, entre outros) e o sistema cria os tickets automaticamente, linkando com Mesa, Categoria, Cliente e Contato já cadastrados. A coluna "Desenvolvimento" vira a chave do Jira, mostrada na aba "Desenvolvimento" do ticket. Tem um botão para baixar um modelo de exemplo com o formato certo. A importação roda em segundo plano com uma barra de progresso - suporta planilhas com dezenas de milhares de linhas, e ignora automaticamente linhas vazias que o Excel costuma deixar ao salvar como CSV.',
  },
  {
    id: 'ticket-stage-automation',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title: 'Automação de Estágio no Kanban de tickets',
    description:
      'Em Configurações > Estágios (adicionar/editar), nova seção "Automação de estágio": configure ações que rodam sozinhas sempre que um ticket entrar naquela coluna - mudar prioridade, mudar status (resolver/fechar/cancelar/reabrir), mudar responsável, limpar data de vencimento/agendamento, ou adicionar uma nota automática no histórico do ticket. Dá pra combinar quantas ações quiser por estágio, e desativar sem perder a configuração.',
  },
  {
    id: 'kanban-finalizado-column',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title: 'Estágio "Finalizado" agora aparece no Kanban, com visual próprio',
    description:
      'O estágio "Finalizado" deixou de ficar escondido por padrão e agora aparece como uma coluna normal no quadro Kanban. Em Configurações > Estágios, novo campo para ocultar qualquer estágio do quadro (não só o Finalizado). Tickets no estágio "Finalizado" ganham um card com visual verde/concluído, diferenciando de longe os que já foram encerrados.',
  },
  {
    id: 'attendance-schedule',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title: 'Nova Configuração de Atendimento (horário de funcionamento)',
    description:
      'Nova aba em Configurações > Tickets > Configuração de Atendimento: defina os dias e horários em que a triagem automática deve funcionar, com quantos períodos precisar por dia (dá pra ter um plantão de fim de semana com horário diferente do expediente normal). Fora do horário, o cliente recebe uma mensagem de offline configurável e a conversa cai direto na fila, sem passar pelas perguntas da triagem.',
  },
  {
    id: 'flow-dedup-ticket-and-queue-fallback',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title: 'Ticket automático não duplica mais, e fluxo sem saída vai pra fila',
    description:
      'Antes de criar um ticket, a triagem (WhatsApp e Widget) agora confere se aquele contato/empresa já tem um aberto na mesma Mesa e reaproveita, em vez de duplicar. Também corrigido: quando o fluxo não sabe o que fazer (empresa bloqueada, CNPJ não encontrado, erro inesperado), a conversa agora sempre cai numa fila para um atendente pegar, em vez de ficar parada sem aparecer em lugar nenhum. Precisa clicar em "Recriar o fluxo" para automações já configuradas receberem a mudança do ticket.',
  },
  {
    id: 'queue-requeue-priority',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Conversa devolvida pra fila vai pra frente',
    description:
      'Quando um atendente desatribui uma conversa que já tinha dono, ela agora pula pro início da fila, independente da prioridade, e ganha um selo "Conversa desatribuída" no card - assim dá pra ver que ela já estava em atendimento antes. Volta ao normal assim que alguém pega a conversa de novo.',
  },
  {
    id: 'queue-order-lock',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Trava de ordem da fila, por atendente',
    description:
      'Em Configurações > Agentes, novo campo "Obrigar a pegar a próxima da fila, em ordem". Quando ligado pra um atendente, ele deixa de poder escolher livremente uma conversa da fila - só pode usar o botão "Pegar próximo da fila" (aba "Na fila"), que sempre traz a mais antiga/prioritária. Administrador nunca é afetado por essa trava, continua escolhendo livremente.',
  },
  {
    id: 'triage-clarity-check',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Triagem pede mais detalhes quando o problema está vago',
    description:
      'Quando o cliente responde algo genérico ("preciso de ajuda", só o nome de um módulo), a triagem agora pergunta uma vez "consegue detalhar melhor o que está ocorrendo?" antes de classificar - nunca mais que isso. Também corrigido: se o cliente manda só uma imagem/áudio sem legenda no meio da triagem, o bot agora avisa que precisa de uma resposta em texto, em vez de ficar mudo esperando pra sempre.',
  },
  {
    id: 'triage-flow-rewrite',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Fluxo de triagem reescrito: mais rápido e objetivo',
    description:
      'O fluxo de triagem (WhatsApp e Widget) foi redesenhado do zero: só pede CNPJ, confere se a empresa está habilitada, pergunta o problema, classifica a prioridade e já encaminha pra fila certa - sem "já tem ticket aberto?" nem outras perguntas. Novo campo "Telefone de suporte" em Configurações > Tickets > Automação, usado quando a empresa não está habilitada. Precisa clicar em "Recriar o fluxo" pra receber a mudança.',
  },
  {
    id: 'whatsapp-message-order-fix',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Corrige ordem de entrega das mensagens no WhatsApp',
    description:
      'Quando o bot mandava duas mensagens seguidas rapidamente (ex: saudação + pedido de CNPJ), elas às vezes chegavam trocadas no WhatsApp do cliente, mesmo aparecendo certas dentro do Chatwoot. Agora cada mensagem espera a anterior da mesma conversa realmente sair antes de ser despachada.',
  },
  {
    id: 'whatsapp-autoassign-vs-queue-fix',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Fila da triagem não é mais atropelada pela distribuição automática',
    description:
      'A distribuição automática do WhatsApp estava pegando conversas que a triagem por IA já tinha mandado pra uma fila (Suporte N1/N2) e atribuindo sozinha pra um atendente, sem passar por "Na Fila". Agora ela ignora qualquer conversa que já tenha fila definida.',
  },
  {
    id: 'ai-triage-priority-queues',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Fila por prioridade na triagem por IA',
    description:
      'Configurações > Tickets > Automação ganhou dois campos novos: fila pra prioridade Baixa/Média e fila pra prioridade Alta/Urgente. A triagem por IA agora manda a conversa pra fila certa automaticamente, com base na prioridade que ela mesma calculou.',
  },
  {
    id: 'ai-triage-criteria-cnpj',
    date: '24 de setembro de 2026',
    isoDate: '2026-09-24',
    type: 'feature',
    title: 'Critério de prioridade da IA e CNPJ sempre no WhatsApp',
    description:
      'A IA de triagem agora usa critérios concretos pra classificar baixa/média/alta (sistema fora do ar ou problema com dinheiro = alta; dúvida, sugestão ou algo pontual sem pressa = baixa). O WhatsApp também passou a sempre pedir o CNPJ pra identificar a empresa, no mesmo padrão do Widget do site.',
  },
  {
    id: 'ai-triage-all-levels',
    date: '23 de setembro de 2026',
    isoDate: '2026-09-23',
    type: 'feature',
    title: 'Triagem por IA para todo cliente',
    description:
      'O fluxo automático de WhatsApp/Widget agora sempre passa pela triagem por IA (classifica a prioridade e encaminha pra um atendente humano), pra qualquer nível de cliente - a etapa em que a IA tentava resolver sozinha antes de abrir o ticket foi removida. A prioridade "Alta" também passou a aparecer como "Alta" na tela, em vez de "Urgente". Automações já configuradas precisam clicar em "Recriar o fluxo" no assistente pra receber essa mudança.',
  },
  {
    id: 'contract-description-title',
    date: '23 de setembro de 2026',
    isoDate: '2026-09-23',
    type: 'feature',
    title: 'Descrição do contrato vira título',
    description:
      'Novo campo "Descrição" no contrato (protocolo, código, etc.) - agora ele aparece em todo lugar como "Descrição - Empresa", na lista, na busca da aba de Cobrança da Empresa e no PDF exportado.',
  },
  {
    id: 'contract-signed-on-pdf',
    date: '23 de setembro de 2026',
    isoDate: '2026-09-23',
    type: 'feature',
    title: 'Data de assinatura e exportação em PDF no Contrato',
    description:
      'Contratos ganharam o campo "Data de assinatura" e um botão "Exportar PDF" (abre uma versão formatada pra impressão/salvar como PDF, com tabela de produtos, valor total e linhas de assinatura).',
  },
  {
    id: 'product-groups',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Grupo de Produtos',
    description:
      'Novo cadastro em Configurações: todo Produto agora pertence a um Grupo, e ganhou um campo de Valor próprio. O Grupo soma o valor dos produtos automaticamente (ou pode ser definido na mão), e é ele - não mais o produto individual - que agora se vincula nas linhas de um Contrato.',
  },
  {
    id: 'whatsapp-csat-survey',
    date: '22 de setembro de 2026',
    isoDate: '2026-09-22',
    type: 'feature',
    title: 'Pesquisa de satisfação no WhatsApp',
    description:
      'Nova seção em Configurações > Automação: ao resolver uma conversa de WhatsApp, envia uma mensagem (editável) pedindo pro cliente avaliar de 1 a 5 digitando o número. A nota entra nos relatórios de CSAT normalmente. Desligado por padrão - precisa ser ativado.',
  },
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
