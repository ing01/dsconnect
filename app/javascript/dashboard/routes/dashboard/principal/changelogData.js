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
    id: 'client-portal-ticket-filters-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'feature',
    platform: 'web',
    title: 'Portal do cliente: filtros na lista de tickets',
    description:
      'No portal web, a lista de tickets agora filtra por Mesa, Estágio (da Mesa escolhida), Responsável, Status e período de abertura, igual ao aplicativo. Sem escolher um status, aparecem só os chamados abertos.',
  },
  {
    id: 'backlog-sprint-board-taller-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'Sprint ativo: o quadro ocupa a tela e a página rola',
    description:
      'No Backlog, na aba Sprint ativo, o quadro do desenvolvimento estava com as colunas muito baixas. Agora ele tem a altura da tela: role a página até o quadro para ver muito mais tickets de uma vez, e cada coluna continua rolando por dentro.',
  },
  {
    id: 'global-workspace-tabs-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'feature',
    platform: 'web',
    title: 'Abas no topo para qualquer tela do sistema',
    description:
      'Toda tela aberta pelo menu (Kanban, Backlog, Projetos, Chat Interno, Empresas e as demais) agora vira uma aba no topo, junto com os tickets abertos. O Kanban também pode ser fechado. Ao fechar a última aba você vai para a tela Principal, e as abas abertas ficam guardadas para a próxima vez.',
  },
  {
    id: 'ticket-back-to-origin-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'fix',
    platform: 'web',
    title: 'Ticket: "Voltar" retorna para a tela de onde você veio',
    description:
      'Ao abrir um ticket pelo Backlog / Sprint ativo (ou pela Triagem) e clicar em "Voltar para tickets", você volta para essa mesma tela, com os filtros que estavam aplicados, em vez de cair sempre no Kanban.',
  },
  {
    id: 'duebot-conversations-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'feature',
    platform: 'web',
    title: 'DueBot de volta nas Conversas, com histórico',
    description:
      'O assistente voltou ao lado do ícone de contato, agora com o nome DueBot e a nova logo. Tire dúvidas sobre o sistema e peça ajuda com os clientes: enquanto ele responde, aparece só um aviso de espera, sem as ações internas. O ícone de relógio no topo do painel guarda e reabre suas conversas anteriores.',
  },
  {
    id: 'contact-page-redesign-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'Contatos: página no mesmo formato de Empresas',
    description:
      'A página do contato ganhou abas no centro (Perfil, Atributos, Histórico, Notas, Mídia e Mesclar), com a quantidade de conversas e notas, e um resumo no Perfil. Saíram os campos Sobrenome, País, Cidade e Biografia; o nome agora é um campo só.',
  },
  {
    id: 'contracts-moved-commercial-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'Contratos agora só em Comercial',
    description:
      'O item "Contratos" saiu do menu Empresas. Em Comercial > Contratos, use o botão "Visualizar contratos" para abrir a lista, com busca por cliente.',
  },
  {
    id: 'agenda-team-required-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'Agenda: escolha a agenda ao criar e troque nos já criados',
    description:
      'Ao criar um compromisso, o campo "Agenda" (Suporte, Implantação etc.) vem vazio e é obrigatório, para ninguém marcar na agenda errada sem querer. Nos compromissos já criados também dá para trocar de agenda ao editar.',
  },
  {
    id: 'client-chat-blocked-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'Contato bloqueado não usa o chat do Portal',
    description:
      'Quem está bloqueado continua entrando no Portal e no app do cliente, mas o chat mostra o aviso para ligar no telefone (18) 3916-7600, e nenhuma conversa é aberta.',
  },
  {
    id: 'duerules-tokens-config-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'DueRules: tokens de Suporte e de Atendimento configuráveis',
    description:
      'No Super Admin, em DueRules, agora é possível informar a URL e os dois tokens (Suporte/Implantação e Atendimento aos clientes) sem mexer no servidor. O Copiloto continua usando o token do Suporte.',
  },
  {
    id: 'client-notifications-realtime-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'improvement',
    platform: 'mobile',
    title: 'App do cliente: notificações em tempo real',
    description:
      'Respostas da equipe no chat ou no chamado e chamados encaminhados para uma mesa agora aparecem na hora nas abas Chat e Notificações, com o contador e a faixa de aviso, sem esperar a próxima atualização.',
  },
  {
    id: 'triage-stage-select-fix-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'fix',
    platform: 'web',
    title: 'Triagem: o campo Estágio voltou a listar as opções',
    description:
      'Ao encaminhar um ticket na Triagem, o campo Estágio mostrava "Nenhum resultado encontrado" mesmo com a Mesa escolhida. Agora os estágios e as categorias da Mesa aparecem normalmente.',
  },
  {
    id: 'client-ticket-moved-notification-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'feature',
    platform: 'mobile',
    title: 'App do cliente: aviso quando o chamado é encaminhado',
    description:
      'Quando um chamado sai de "aguardando triagem" para uma mesa da equipe (ou troca de mesa), o cliente recebe uma notificação dentro do app, na aba Notificações, com o contador no ícone e a faixa de aviso. Um toque abre o chamado. Não envia push.',
  },
  {
    id: 'copilot-duerules-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'feature',
    platform: 'web',
    title: 'Copiloto consulta a base de regras do ERP (DueRules)',
    description:
      'Na aba Copiloto do ticket e da conversa, você pode perguntar sobre o ERP Duesoft (telas, rotinas, cadastros, fiscal e customizações de clientes) e o Copiloto responde com base na base de regras DueRules, sem inventar. Para ver as regras de um cliente específico, cite o nome dele na pergunta.',
  },
  {
    id: 'client-chat-notifications-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'fix',
    platform: 'mobile',
    title: 'App do cliente: resposta do chat sempre avisada',
    description:
      'Corrigimos o caso em que a resposta da equipe no chat não aparecia nas Notificações nem acendia o aviso no ícone do Chat (acontecia quando o cliente já tinha uma conversa antiga encerrada). Agora o ícone do Chat e o de Notificações mostram quantas novidades esperam, uma faixa dentro do app diz quem respondeu e o que disse (com um toque em "Ver"), e a notificação do celular mostra "Nome: mensagem". Respostas só com arquivo também são avisadas.',
  },
  {
    id: 'mobile-notifications-tab-refresh-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'fix',
    platform: 'mobile',
    title: 'App: aba Notificações sempre atualizada',
    description:
      'Os avisos que chegavam no celular com o app fechado ou em segundo plano não apareciam na aba Notificações. Agora a lista se atualiza ao voltar para o app, ao entrar na aba e a cada 30 segundos, sem precisar puxar a tela. A bolinha vermelha do Chat também acende quando a mensagem chega pela conexão em tempo real, mesmo que o aviso demore.',
  },
  {
    id: 'mobile-delete-account-hidden-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'improvement',
    platform: 'mobile',
    title: 'App: excluir conta mais protegido',
    description:
      'A opção "Excluir minha conta" saiu do menu de três pontinhos, onde ficava ao lado de "Sair". Agora ela está em "Minha conta", no fim da tela, e só libera depois de digitar EXCLUIR e a senha. Assim ninguém perde os dados por um toque sem querer.',
  },
  {
    id: 'mobile-biometric-switch-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'improvement',
    platform: 'mobile',
    title: 'App: interruptor de biometria no login',
    description:
      'Na tela de login do app, os dois botões de biometria deram lugar a um interruptor "Entrar com biometria". Ligado, o botão Entrar pede a biometria e entra (na primeira vez, use e-mail e senha para ativar). Desligado, o login pede e-mail e senha como antes. A escolha fica salva no aparelho.',
  },
  {
    id: 'mobile-chat-always-updated-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'fix',
    platform: 'mobile',
    title: 'App: o chat sempre atualiza',
    description:
      'Ao abrir o chat pela notificação, ou ao voltar para o app, as mensagens novas agora aparecem na hora, sem precisar fechar e abrir o aplicativo. A conexão em tempo real também se refaz sozinha se cair, e o chat se atualiza periodicamente enquanto está aberto.',
  },
  {
    id: 'sidebar-unread-chat-counters-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'improvement',
    platform: 'web',
    title: 'Contador de não lidas no menu lateral',
    description:
      'Conversas e Chat Interno agora mostram no menu lateral quantas mensagens ainda não foram vistas, igual às Notificações e à Triagem. O número aparece em qualquer tela e some quando você abre a conversa ou a sala.',
  },
  {
    id: 'ticket-history-details-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'improvement',
    platform: 'web',
    title: 'Histórico do ticket mais completo',
    description:
      'Ao trocar o responsável (e Mesa, estágio, empresa, solicitante, categoria e prioridade), o Histórico agora mostra os nomes em vez de números. Também passaram a ser registrados data de entrega, agendamento, descrição, complexidade, responsáveis de nível 2 a 5, anexos, apontamentos, itens do checklist e conversas vinculadas, sempre com quem fez e o antes/depois. Transferências e a criação do ticket mostram cada campo em detalhe.',
  },
  {
    id: 'email-tab-error-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'fix',
    platform: 'web',
    title: 'Aba de E-mails: fim do aviso de erro repetido',
    description:
      'Ao abrir a aba de E-mails, o aviso "Não foi possível carregar as conversas" aparecia várias vezes seguidas. Agora a lista simplesmente fica vazia enquanto o e-mail não estiver em funcionamento, sem o aviso.',
  },
  {
    id: 'ticket-close-rules-2026-10-28',
    date: '28 de outubro de 2026',
    isoDate: '2026-10-28',
    type: 'improvement',
    platform: 'web',
    title: 'Fechar ticket: menos exigências e regra para o estágio Pendente',
    description:
      'A complexidade deixou de ser obrigatória para fechar um ticket; continuam valendo a classificação no catálogo de serviços e a comunicação com o cliente. Além disso, a opção "Fechar ticket" não aparece mais para tickets que estão no estágio Pendente. No menu (três pontinhos) do card do Kanban, "Finalizar" agora se chama "Fechar", igual ao de dentro do ticket.',
  },
  {
    id: 'brand-logo-update-2026-10-27',
    date: '27 de outubro de 2026',
    isoDate: '2026-10-27',
    type: 'design',
    platform: 'web',
    title: 'Nova logo do DSConnect (versão final)',
    description:
      'Trocamos a logo por uma nova no login, nos favicons, na barra lateral e na Política de Privacidade, e no app mobile (ícone, tela de abertura e login). As logos antigas foram removidas do sistema.',
  },
  {
    id: 'mobile-biometric-login',
    date: '27 de outubro de 2026',
    isoDate: '2026-10-27',
    type: 'feature',
    platform: 'mobile',
    title: 'App: entrar com Face ID ou digital',
    description:
      'Na tela de login do app, o botão "Entrar e ativar biometria" guarda seu acesso com segurança no aparelho. Depois disso, mesmo que você saia da conta, basta tocar em "Entrar com biometria". O app também pede a biometria ao ser aberto e depois de ficar um tempo em segundo plano. Para desligar, use o menu (três pontinhos) > "Desativar biometria".',
  },
  {
    id: 'development-module-backlog-jira-layout',
    date: '26 de outubro de 2026',
    isoDate: '2026-10-26',
    type: 'feature',
    platform: 'web',
    title:
      'Backlog e Sprints: layout no estilo Jira, filtros e edição em massa',
    description:
      'As listagens de Backlog e Sprint ativo agora mostram os tickets em linhas compactas (número, título, prioridade, foto do responsável e estimativa de horas), com filtros de busca, responsável, prioridade e estágio. Também é possível selecionar vários tickets e usar "Editar campos" para alterar Estágio, Sprint, Prioridade e Responsável de todos de uma vez. Além disso, a listagem do Backlog passou a mostrar somente tickets filhos (criados pela aba "Desenvolvimento" de um chamado) que ainda não chegaram ao Estágio final da Mesa - tickets concluídos ou sem vínculo com um chamado pai não aparecem mais ali. Corrigido também um caso em que os tickets não apareciam ao abrir a aba Backlog pela primeira vez (só vinham depois de trocar para o Sprint ativo e voltar); agora o ícone de carregamento cobre toda a busca, do começo ao fim.',
  },
  {
    id: 'development-module-phase-2-backlog',
    date: '23 de outubro de 2026',
    isoDate: '2026-10-23',
    type: 'feature',
    platform: 'web',
    title: 'Backlog, Sprints e Sprint ativo do Módulo de Desenvolvimento',
    description:
      'Segunda e terceira parte do Módulo de Desenvolvimento: uma nova tela "Backlog" (menu lateral) para a Mesa com o módulo ligado, com o botão "Criar sprint", arrastar-e-soltar de tickets entre os Sprints e o Backlog, e uma visão "Sprint ativo" que reaproveita o próprio Kanban da Mesa mostrando só os tickets daquele Sprint, com um botão "Concluir sprint" (o que ainda não chegou no Estágio final vai automaticamente para o próximo Sprint; o que já chegou fica registrado no Sprint concluído). Os campos extras do módulo (tipo, resolução, feature, horas, sprint, etc.) agora também podem ser editados na tela de detalhe do ticket, não só na criação.',
  },
  {
    id: 'development-module-phase-1',
    date: '22 de outubro de 2026',
    isoDate: '2026-10-22',
    type: 'feature',
    platform: 'web',
    title: 'Módulo de Desenvolvimento (fase 1) na aba de Tickets',
    description:
      'Primeira parte do Módulo de Desenvolvimento, pensado para trazer o fluxo do time de dev (hoje no Jira) para dentro do DSConnect. Em Configurações > Times, a Mesa ganha um checkbox "Módulo de Desenvolvimento" e um checklist padrão (anexado automaticamente a cada ticket novo dela); com o módulo ligado, a abertura de ticket ganha os campos extras do módulo (tipo Bug/Tarefa, feature, resolução, retrabalho, estimativa, etc.) e o cartão do Kanban mostra o ícone do tipo. Nenhuma outra Mesa muda de comportamento.',
  },
  {
    id: 'brand-logo-update-2026-10',
    date: '21 de outubro de 2026',
    isoDate: '2026-10-21',
    type: 'design',
    platform: 'web',
    title: 'Nova logo do DSConnect',
    description:
      'Atualizada a logo usada no login, no favicon e nas demais telas da marca, com fundo transparente. O app mobile (ícone, ícone adaptativo do Android, tela de abertura, e também macOS/PWA web) foi atualizado com a mesma logo.',
  },
  {
    id: 'ticket-integration-api',
    date: '21 de outubro de 2026',
    isoDate: '2026-10-21',
    type: 'feature',
    platform: 'web',
    title: 'API de Integração de Tickets',
    description:
      'Nova API para um sistema externo ler e rotear tickets - pensada para conectar uma IA de triagem. Em Configurações > Tickets > API de Tickets, um administrador gera a chave de acesso (uma por conta, revogável). A documentação completa (Swagger) ficou disponível em /swagger, protegida por usuário e senha fora do ambiente de desenvolvimento.',
  },
  {
    id: 'ticket-kanban-performance-n-plus-one',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'improvement',
    platform: 'web',
    title: 'Kanban de tickets bem mais rápido',
    description:
      'O quadro de tickets (e a listagem/busca detalhada) fazia uma consulta extra ao banco para CADA cartão, só para ler os itens de checklist e as conversas vinculadas - numa coluna com algumas centenas de tickets isso virava algumas centenas de consultas a mais, só para desenhar a tela. Corrigido para usar os dados já carregados numa única consulta. Também foi removido o recarregamento completo do quadro a cada vez que um ticket é arrastado entre colunas - agora só o cartão movido é atualizado, igual já acontecia quando outro atendente move um ticket em tempo real.',
  },
  {
    id: 'client-area-notifications-badge-and-bigger-remove-button',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'improvement',
    platform: 'web',
    title: 'Selo de notificações no menu da Área do Cliente',
    description:
      'O menu lateral da Área do Cliente agora mostra, no item Notificações, quantas notificações existem sem precisar abrir a aba - igual já funciona no painel interno. O botão de remover uma notificação sem abri-la também ficou maior, mais fácil de acertar.',
  },
  {
    id: 'client-area-notifications-dismiss',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'feature',
    platform: 'web',
    title: 'Notificações da Área do Cliente agora podem ser removidas',
    description:
      'Na aba Notificações da Área do Cliente, abrir uma notificação agora a remove da lista (ela não fica mais aparecendo depois de já ter sido vista). Também foi adicionado um botão para remover uma notificação sem precisar abri-la, e um botão "Limpar tudo" para remover todas as que estão visíveis no momento.',
  },
  {
    id: 'ticket-list-due-date-invalid-date-fix',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'fix',
    platform: 'web',
    title: 'Coluna Prazo mostrando "Invalid Date" corrigida',
    description:
      'Na lista de tickets da Área do Cliente, a coluna Prazo mostrava "Invalid Date" em vez da data real quando o chamado tinha prazo definido. A tela tratava o prazo como se fosse o mesmo formato da data de abertura, mas o servidor manda os dois em formatos diferentes - corrigido para ler o formato certo.',
  },
  {
    id: 'ticket-sla-report-and-time-by-company',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'feature',
    platform: 'web',
    title: 'Relatório de SLA por agente/Cliente, e horas por Cliente',
    description:
      'Novo relatório em Configurações > Relatórios > "SLA por agente/Cliente": cumprimento do SLA (relógios de atendimento/estágio/solução), com quantos cumpridos, vencidos, em andamento, taxa de cumprimento, tempo realmente gasto e tempo de atraso - por agente e por Cliente, combinado ou separado por tipo de prazo, com filtro de período/Mesa/Cliente. O relatório de Horas apontadas (que já existia) ganhou o mesmo corte por Cliente e passou a aparecer no hub de Relatórios. Os dois juntos dão a base para análise de margem de lucro por Cliente.',
  },
  {
    id: 'manifestation-convert-to-suggestion',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'feature',
    platform: 'web',
    title: 'SAC: enviar manifestação para Sugestões e Melhorias',
    description:
      'No SAC, uma manifestação de melhoria/sugestão/bug interno agora pode ser enviada direto para o quadro de Sugestões e Melhorias, sem precisar virar um ticket numa Mesa. A sugestão nasce com a descrição e os anexos de imagem/vídeo da manifestação, e um link volta para o SAC de origem - igual já acontecia com "Converter em Ticket". As duas saídas são excludentes: a manifestação vira ticket OU sugestão, nunca os dois.',
  },
  {
    id: 'ticket-list-column-resize-and-hide',
    date: '20 de outubro de 2026',
    isoDate: '2026-10-20',
    type: 'improvement',
    platform: 'web',
    title: 'Lista de tickets: redimensionar e ocultar colunas',
    description:
      'Na lista de tickets (Busca detalhada e Tickets da Área do Cliente), agora dá para arrastar a borda de uma coluna pra redimensioná-la, e usar o botão "Colunas" para ocultar as que não interessam. A coluna Título já nasce mais larga por padrão, para não cortar o assunto do chamado atrás dos prefixos de Mesa/Categoria. A escolha fica salva por conta, sem precisar refazer toda vez.',
  },
  {
    id: 'ticket-development-tab-create-link',
    date: '19 de outubro de 2026',
    isoDate: '2026-10-19',
    type: 'feature',
    platform: 'web',
    title:
      'Aba Desenvolvimento: criar e vincular tickets de dev direto do chamado',
    description:
      'A aba Desenvolvimento do detalhe do chamado ganhou o botão "Criar / Vincular". Criar: abre um formulário pré-filtrado pela Mesa de Desenvolvimento (categorias limitadas a Erro e Tarefa, responsáveis só da mesa), com suporte a anexos — o ticket criado já nasce vinculado como filho do chamado atual. Vincular: busca entre tickets existentes da Mesa Dev e os vincula como filho. Os tickets filhos listados na aba abrem em nova aba ao clicar, e cada um tem botões de Desvincular e Excluir com confirmação inline.',
  },
  {
    id: 'client-delete-account-self-service',
    date: '19 de outubro de 2026',
    isoDate: '2026-10-19',
    type: 'feature',
    platform: 'web',
    title: 'Clientes podem excluir a própria conta pelo Portal e pelo app',
    description:
      'No Portal do Cliente, o menu do canto superior direito agora tem a opção "Excluir minha conta" (em vermelho). No app Android, a mesma opção aparece no menu ⋮. O cliente confirma com a senha e os dados pessoais (nome, e-mail, telefone e senha) são removidos imediatamente — o histórico de chamados continua visível para a equipe, mas sem nenhum dado pessoal vinculado. O link de instruções para o Google Play está em dsconnect.duesoft.com.br/exclusao-conta.',
  },
  {
    id: 'agent-lunch-break-auto-assignment',
    date: '15 de outubro de 2026',
    isoDate: '2026-10-15',
    type: 'feature',
    platform: 'web',
    title: 'Horário de almoço do agente, respeitado na distribuição automática',
    description:
      'Em Configurações > Agentes > editar agente, agora dá para cadastrar o horário de almoço de cada um. A distribuição automática de conversas para de atribuir novos chats a esse agente 20 minutos antes do início do almoço, e volta a atribuir normalmente no horário de retorno - sem precisar de nenhuma ação manual. Conversas já atribuídas não são afetadas.',
  },
  {
    id: 'ticket-triage-notification-fixes',
    date: '15 de outubro de 2026',
    isoDate: '2026-10-15',
    type: 'fix',
    platform: 'web',
    title: 'Notificação de Triagem: corpo vazio e sem ícone na aba',
    description:
      'A notificação de "chamado na Triagem" chegava no push só com o título, sem nenhum texto no corpo, e aparecia na aba Notificações sem ícone e sem rótulo de tipo. Agora o corpo mostra o título do chamado, e o card tem ícone e rótulo corretos. Esse tipo de notificação também passou a aparecer em Configurações > Perfil > Notificações, para quem quiser ligar o push dela (antes não tinha como habilitar pela tela).',
  },
  {
    id: 'mobile-app-launch',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'feature',
    platform: 'mobile',
    title: 'App mobile DSConnect: lançamento',
    description:
      'O sistema agora tem um aplicativo próprio para Android e iOS, para colaborador e cliente no mesmo app - o login descobre sozinho qual dos dois é, com o mesmo e-mail/senha de sempre. Colaborador acompanha "Meus tickets" com filtro por Mesa, move Estágio e muda status. Cliente acompanha "Meus chamados", abre chamado (inclusive com IA, por texto ou áudio), conversa pelo Chat com a equipe em tempo real, e recebe Notificações. Visual alinhado com o sistema web: mesma logo, cores e gradiente.',
  },
  {
    id: 'mobile-push-notifications',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'feature',
    platform: 'mobile',
    title: 'Notificações push no app, com bolinha de mensagem nova',
    description:
      'O app passou a registrar o aparelho no Firebase e recebe notificação mesmo fechado, tanto para colaborador quanto para cliente. No Chat, uma bolinha vermelha no ícone avisa que chegou mensagem nova, e some sozinha ao abrir a aba.',
  },
  {
    id: 'mobile-chat-audio-photos',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'feature',
    platform: 'mobile',
    title: 'Chat do app: enviar áudio e fotos',
    description:
      'O Chat do cliente dentro do app ganhou botão de anexar foto (câmera ou galeria) e botão de gravar áudio, direto na tela de conversa - mensagens de foto aparecem como miniatura e as de áudio com um player (tocar/pausar).',
  },
  {
    id: 'mobile-ticket-filters-search',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'improvement',
    platform: 'mobile',
    title: 'Filtro por Empresa e busca por número do chamado no app',
    description:
      'As listas "Meus tickets" (colaborador) e "Meus chamados" (cliente) ganharam filtro por Empresa e um campo de busca pelo número do chamado, com resultado em tempo real enquanto digita. Corrigido também: em alguns aparelhos o teclado numérico não tinha como confirmar a busca - agora o ícone de lupa também funciona como botão.',
  },
  {
    id: 'mobile-version-on-login',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'improvement',
    platform: 'mobile',
    title: 'Versão do app aparece na tela de login',
    description:
      'A tela de login agora mostra a versão instalada (ex: "Versão 1.0.2 (3)") - forma simples de conferir, depois de instalar um APK novo, se a atualização realmente chegou no aparelho.',
  },
  {
    id: 'projects-default-task-category',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'feature',
    platform: 'web',
    title: 'Categoria padrão no cadastro de Projeto',
    description:
      'Depois de escolher a Mesa, o cadastro de Projeto ganhou o campo "Categoria padrão das tarefas" - preenche sozinha a Categoria de cada tarefa gerada no passo 2, quando o Modelo de Tarefa não tiver uma categoria própria configurada.',
  },
  {
    id: 'settings-menu-cleanup-reports-hub',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'improvement',
    platform: 'web',
    title:
      'Menu de Configurações mais enxuto, Relatórios em cards e Atualizador automático',
    description:
      'O menu de Configurações ficou mais curto: Conta, Atribuição de Agentes, Atributos Personalizados, Robôs, Macros e Fluxos saíram da lista (as telas continuam existindo, só pararam de aparecer no menu). Novo item "Atualizador automático", que abre o link de atualização numa aba nova. E "Relatórios" deixou de ser uma lista comprida dentro do menu: agora abre uma página com um card por relatório - a Avaliação Mensal, que era um item separado, virou mais um card ali dentro.',
  },
  {
    id: 'client-portal-triage-reactivated',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'fix',
    platform: 'web',
    title: 'Triagem reativada para chamados abertos pela Área do Cliente',
    description:
      'Chamados abertos pela Área do Cliente (site ou app) estavam pulando a fila de Triagem e indo direto para o Kanban da equipe, sem aprovação - a tela de Triagem já esperava isso, só não estava recebendo nada. Agora todo chamado do cliente entra em Triagem normalmente, como já acontecia com os demais canais.',
  },
  {
    id: 'dua-groq-fixes',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'fix',
    platform: 'web',
    title: 'Dua (IA) voltou a responder no Playground usando a Groq',
    description:
      'Configurar a Dua com uma chave da Groq não funcionava: o endereço da API estava incompleto, uma configuração antiga de outra conta sobrepunha o modelo escolhido, a Groq recusa combinar resposta estruturada com uso de ferramentas (agora o sistema tenta de novo automaticamente sem isso), e um campo técnico que a Groq devolve mas não aceita de volta travava a resposta depois do uso de uma ferramenta. Também corrigido: se a busca de FAQ falhar (a Groq não faz "embeddings"), a Dua responde mesmo assim, só sem citar documentos.',
  },
  {
    id: 'team-name-capitalized',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'fix',
    title: 'Nome da Mesa/Time: primeira letra maiúscula',
    description:
      'O nome das Mesas/Times (ex: "especialista", "suporte") era sempre salvo todo em minúsculo, e aparecia assim em várias telas. Agora só a primeira letra é maiúscula - os nomes já existentes foram corrigidos, e qualquer Mesa nova ou renomeada já nasce assim.',
  },
  {
    id: 'kanban-ticket-card-assignee-photo',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'fix',
    title: 'Kanban: foto do responsável no card do ticket',
    description:
      'O card do ticket no Kanban mostrava só a inicial do nome do responsável, mesmo quando o agente tinha foto cadastrada. Agora mostra a foto de verdade, com a inicial como alternativa só para quem não tem foto.',
  },
  {
    id: 'kanban-board-tickets-limit-per-column',
    date: '14 de outubro de 2026',
    isoDate: '2026-10-14',
    type: 'fix',
    title: 'Kanban: tickets desaparecendo em Mesas com vários Estágios',
    description:
      'Em Mesas com vários Estágios, o quadro vinha escondendo tickets de verdade (ex: um ticket aparecia na busca mas não no Kanban) mesmo sem nenhum deles passar de 300 tickets. A causa era um limite de carregamento que deveria valer por Estágio, mas estava sendo aplicado à Mesa inteira de uma vez, fazendo colunas competirem pelo mesmo espaço. Agora cada Estágio tem seu próprio limite, e todos os tickets aparecem corretamente.',
  },
  {
    id: 'conversation-card-mesa-fallback-to-conversation-team',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'fix',
    title: 'Mesa no card da conversa: agora aparece de verdade',
    description:
      'A Mesa só aparecia quando havia um TICKET vinculado à conversa - e isso é raro no dia a dia (só acontece em alguns fluxos específicos), então o rótulo quase nunca era mostrado. Agora, na falta de um ticket vinculado, ele mostra o Time da própria conversa (o mesmo definido em "Atribuir Time", no menu da conversa) - que é o que realmente existe na maioria dos casos.',
  },
  {
    id: 'agenda-redesign-time-off-drag',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'feature',
    title:
      'Agenda renovada: arrastar, horário de atendimento e folga de agente',
    description:
      'A Agenda (Semana/Dia) agora mostra só o horário das 8h às 18h, com uma linha marcando a hora atual. Dá para arrastar um evento direto na grade para mudar horário/dia, e puxar a borda de baixo para mudar a duração - sem precisar abrir o formulário (eventos recorrentes continuam abrindo o formulário normalmente). Novo tipo de evento "Folga": ao criar um evento, um alternador no topo troca entre "Compromisso" e "Folga" - a folga exige marcar pelo menos um agente, assume o dia inteiro automaticamente e aparece com um ícone e visual diferentes na agenda. O filtro de agentes também ficou mais visível, mostrando os avatares de quem está filtrado direto no botão.',
  },
  {
    id: 'ticket-import-responsible-column',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'improvement',
    title: 'Importação de tickets: coluna "Responsável"',
    description:
      'A planilha de importação de tickets (Configurações > Tickets > Importar) ganhou a coluna "Responsável": o nome ou e-mail casa com um agente/administrador já cadastrado na conta e vincula automaticamente como responsável do ticket importado. Quando não encontra ninguém com esse nome, o ticket é criado normalmente, só sem responsável, e um aviso lista a linha. O modelo de planilha baixável já vem com a nova coluna.',
  },
  {
    id: 'conversation-card-ticket-mesa-always-visible',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'fix',
    title: 'Mesa do ticket no card da conversa agora sempre aparece',
    description:
      'A Mesa do ticket vinculado só aparecia quando o nome de quem atende também aparecia - e a aba "Minhas conversas" esconde esse nome de propósito, então a Mesa ficava invisível justamente na tela mais usada. Agora ela aparece sempre que há um ticket vinculado, em qualquer aba e nos dois formatos de card (compacto e expandido).',
  },
  {
    id: 'suggestion-notification-opens-right-screen',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'fix',
    title: 'Notificação de sugestão abre a tela certa, já na sugestão',
    description:
      'Clicar numa notificação de nova sugestão não abria a tela de Sugestões - caía numa tela errada. Agora abre certinho e já mostra o card da sugestão específica, sem precisar procurar no quadro. A mesma correção vale para o aviso de resposta do cliente num ticket, que também não estava abrindo o ticket certo.',
  },
  {
    id: 'assign-team-moves-ticket-mesa',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'improvement',
    title: '"Atribuir Time" na conversa agora move a Mesa do ticket junto',
    description:
      'Atribuir uma conversa a um Time, pelo menu da conversa, agora também transfere o ticket vinculado a ela para essa mesma Mesa (pelo Estágio de entrada dela) - os dois campos ficam sincronizados, e o card da lista de conversas já mostra a Mesa certa. Se o Estágio de entrada exigir algo que o ticket ainda não tem (prazo, responsável), ele fica de fora da troca, sem travar a atribuição do Time.',
  },
  {
    id: 'conversation-card-ticket-mesa',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'improvement',
    title: 'Lista de conversas mostra a Mesa do ticket vinculado',
    description:
      'Cada card da lista de conversas já mostrava o responsável pela conversa - agora, quando existe um ticket vinculado a ela, a Mesa desse ticket aparece ao lado do nome, para qualquer equipe reconhecer de cara se o assunto é dela ou de outro time.',
  },
  {
    id: 'login-wrong-password-pt-br',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'fix',
    title: 'Erro de senha errada no login agora é em português',
    description:
      'Ao digitar e-mail ou senha errados na tela de login, a mensagem aparecia em inglês ("Invalid login credentials"). Agora ela é em português e já lembra que é possível redefinir a senha pelo link "Esqueci minha senha", na mesma tela.',
  },
  {
    id: 'ticket-kanban-keeps-state',
    date: '13 de outubro de 2026',
    isoDate: '2026-10-13',
    type: 'fix',
    title:
      'Kanban de Tickets não perde mais filtro e rolagem ao abrir um ticket',
    description:
      'Abrir um ticket pelo Kanban e voltar para a tela apagava o filtro de responsável e voltava o scroll de cada coluna para o topo, porque a tela era recriada do zero a cada ida e volta. Agora ela permanece viva em segundo plano - filtro, busca e a posição da rolagem continuam exatamente como foram deixados.',
  },
  {
    id: 'client-access-error-message-fix',
    date: '9 de outubro de 2026',
    isoDate: '2026-10-09',
    type: 'fix',
    title: 'Erro ao liberar acesso ao Portal agora diz o motivo',
    description:
      'Liberar o acesso de um contato à Área do Cliente sempre mostrava "Não foi possível salvar o acesso", mesmo quando o motivo era outro. A tela agora mostra o motivo real sempre que o servidor informa um. Além disso, qualquer agente - não só administrador - já pode liberar ou desativar esse acesso.',
  },
  {
    id: 'client-area-tickets-single-list',
    date: '9 de outubro de 2026',
    isoDate: '2026-10-09',
    type: 'improvement',
    title: 'Chamados do Portal numa lista só, sem precisar trocar de Mesa',
    description:
      'A tela de chamados do cliente deixou de mostrar um quadro por Mesa de serviço - agora é uma lista única com todos os chamados de todas as Mesas juntos, cada linha já dizendo em qual Mesa e em qual Estágio o chamado está. Antes era preciso trocar de Mesa para ver cada grupo separadamente; o seletor de Mesa e a visão em Kanban saíram da tela do cliente (o painel interno continua com as duas).',
  },
  {
    id: 'agenda-recurrence',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Agenda com eventos recorrentes',
    description:
      'Eventos podem se repetir diária, semanal, mensal ou anualmente. Ao alterar ou excluir um evento recorrente, você escolhe se a mudança vale só para esta ocorrência ou para todas.',
  },
  {
    id: 'crm-contract-revisions',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Contratos: histórico de revisões e troca de representante',
    description:
      'Ao trocar o representante de um cliente, os contratos já gerados dele são regenerados automaticamente, e a versão anterior de cada um fica guardada no histórico. Também corrigido: campos vazios não aparecem mais como texto solto no PDF.',
  },
  {
    id: 'projects-task-category-and-new-client',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'improvement',
    title:
      'Projetos: categoria padrão na tarefa e cliente novo sem sair da tela',
    description:
      'O cadastro de tarefa do módulo ganhou o campo Categoria, que já vem preenchida ao criar um projeto a partir do módulo. Na tela de Projeto novo, o botão "Novo cliente" abre o cadastro de empresa e já seleciona o cliente recém-criado.',
  },
  {
    id: 'reports-monthly-satisfaction',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Relatório da Avaliação Mensal de satisfação',
    description:
      'Nova área de consulta interna com o resultado das avaliações mensais de satisfação dos clientes, para acompanhar a opinião dos clientes ao longo do tempo.',
  },
  {
    id: 'client-tutorial-first-access',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Tutorial guiado no primeiro acesso do Portal',
    description:
      'Na primeira vez que o cliente entra no Portal, um tutorial rápido mostra onde ficam Chamados, SAC, Chat, Notificações e o botão de instalar o app. Pode ser pulado a qualquer momento e revisto pelo botão "Tutorial" no topo da tela.',
  },
  {
    id: 'ticket-communication-notifications',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Notificação na troca de mensagens de um ticket com o cliente',
    description:
      'Quando o cliente responde um ticket pelo Portal, o responsável e os seguidores daquele ticket agora recebem um aviso - no site (sino, na hora) e por push, se tiverem a opção ligada (já nasce ligada, inclusive para quem já era agente). Quando é a equipe que responde, o cliente recebe um push no Portal avisando da resposta nova; se o agente marcar "não notificar" ao responder, nenhum aviso sai, igual já acontecia com o e-mail. O aviso abre direto na aba de Comunicação do ticket certo.',
  },
  {
    id: 'client-monthly-satisfaction-survey',
    date: '5 de outubro de 2026',
    isoDate: '2026-10-05',
    type: 'feature',
    title: 'Avaliação Mensal de satisfação no Portal do Cliente',
    description:
      'Novo questionário mensal e rápido no Portal: dez perguntas numa escala de 1 a 5 sobre o ERP, o suporte e a experiência geral com a Duesoft, mais um campo opcional para sugestões. Abre sozinho uma vez por mês (dá para adiar ou responder depois pelo botão "Avaliação Mensal" no cabeçalho) e nunca mais de uma vez no mesmo mês por contato - a regra é garantida no servidor, não só na tela. Cada contato só vê e responde a própria avaliação; a equipe interna já consegue consultar as respostas (empresa, contato, mês e notas) por uma rota de leitura, com média geral e por pergunta já calculadas - a tela de acompanhamento para a equipe fica para uma próxima etapa.',
  },
  {
    id: 'ticket-create-assignee-without-levels-fix',
    date: '5 de outubro de 2026',
    isoDate: '2026-10-05',
    type: 'fix',
    title:
      'Não dava para informar o responsável em Mesa sem níveis configurados',
    description:
      'Ao abrir um ticket novo para uma Mesa com os níveis de responsável DESLIGADOS - como a de Implantação -, o campo de responsável vinha sem nenhum nome para escolher, mesmo a Mesa tendo membros de verdade. A tela filtrava por um nível que só existe quando a configuração está ligada, e nenhum membro de uma Mesa sem essa configuração jamais teve nível cadastrado. Agora a tela confere diretamente se a Mesa usa níveis: quando sim, mostra um campo por nível com só quem está habilitado nele, igual a antes; quando não, mostra um campo único com todos os membros vinculados à Mesa - a mesma regra que a edição de um ticket já existente já seguia corretamente.',
  },
  {
    id: 'commercial-menu-grouped',
    date: '5 de outubro de 2026',
    isoDate: '2026-10-05',
    type: 'improvement',
    title: 'Menu lateral mais curto: Comercial agora é um único item',
    description:
      'Clientes, Vendas, Indicadores e Contratos do Painel Comercial deixaram de ocupar quatro linhas soltas no menu e passaram a ficar dentro de um único item "Comercial", com um submenu - o mesmo formato já usado em "Empresas". Quem tem permissão continua vendo os quatro atalhos, só que organizados; quem não tem a permissão comercial continua sem ver nada disso, como antes.',
  },
  {
    id: 'client-ai-draft-no-categories-fix',
    date: '5 de outubro de 2026',
    isoDate: '2026-10-05',
    type: 'fix',
    title: 'Abrir chamado com IA não mostra mais erro em código',
    description:
      'No Portal do Cliente, gerar um rascunho pela opção "Abrir com IA" podia mostrar o erro cru "no_categories" na tela, em vez de uma mensagem legível - acontecia quando a conta ainda não tinha nenhuma categoria marcada para aparecer no Portal. A opção de IA agora só aparece quando há pelo menos uma categoria disponível, já que gerar um rascunho sem nenhuma sempre falharia; e se ainda assim o servidor recusar (por exemplo, uma categoria removida enquanto a tela já estava aberta), a mensagem agora vem traduzida.',
  },
  {
    id: 'client-push-subscription-after-install',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'fix',
    title: 'Notificação do Portal não chegava para quem já tinha permitido',
    description:
      'Quem instalava o Portal do Cliente como app e permitia as notificações direto pelo Android ou pelas Configurações do aparelho, sem passar pelo botão da tela de chat, nunca chegava a receber nada - a permissão ficava concedida no navegador, mas o servidor nunca sabia o endereço para onde mandar o aviso. Agora a Area do Cliente confere isso ao abrir, em qualquer tela, e completa a inscrição sozinha quando a permissão já está concedida. Instalar o app pelo botão do cabeçalho também passou a perguntar a notificação na hora, em vez de esperar a pessoa achar o botão do chat.',
  },
  {
    id: 'client-chat-notification-polish',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'Aviso do chat do Portal: logo, botão e nada de aviso repetido',
    description:
      'A notificação que o cliente recebe do chat do Portal passou a levar a logo do sistema e um botão "Abrir conversa", que leva direto à conversa - e que também empurra para o menu de reticências o botão de inscrição que o navegador colocava sozinho. Ela também deixou de aparecer quando a pessoa JÁ está com aquela tela aberta na frente: avisa quando ela está em outra página do Portal, ou fora do site/aplicativo. E o aviso voltou a sair em português - vinha em inglês porque é montado em segundo plano, onde nada definia o idioma. Vale para os atendentes também: a conversa que está na tela não gera mais aviso dela mesma.',
  },
  {
    id: 'conversation-copilot-removed',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'Copiloto (IA) removido das Conversas por enquanto',
    description:
      'O ícone/painel do Copiloto saiu da tela de Conversas - fica só o ícone de contato no mesmo lugar. Os demais recursos de IA (melhorar resposta, resumir conversa, etc.) continuam normalmente.',
  },
  {
    id: 'conversation-resolved-lock',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Conversa resolvida bloqueia resposta até reabrir',
    description:
      'Depois de marcada como resolvida, a conversa não aceita mais mensagem pública para o cliente - a caixa de digitação fica bloqueada com um aviso, até alguém reabrir a conversa. Nota privada continua liberada normalmente, e vale até para Administrador.',
  },
  {
    id: 'ticket-ai-summarize-description',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Resumir conversa por IA na descrição do ticket',
    description:
      'Na tela do ticket, o botão "Resumir conversa" (mesmo recurso de IA do chat do atendente) aparece ao lado de Editar/Usar template sempre que o ticket tem conversa vinculada. Ele junta todas as conversas ligadas ao ticket, gera um resumo e abre a descrição já preenchida para revisar e salvar - nunca salva sozinho.',
  },
  {
    id: 'crm-dashboard',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Painel Comercial ganhou tela de indicadores',
    description:
      'Novo item "Indicadores Comercial" no menu: os mesmos números do painel comercial antigo (implantação, mensalidade, vendas, clientes únicos, ticket médio), tendência mensal e ranking de vendedor, produto e canal, com filtro por período. Administrador vê automaticamente; os demais continuam precisando da permissão do Comercial.',
  },
  {
    id: 'crm-contract-generation',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Geração de contrato em PDF/Word no Painel Comercial',
    description:
      'Novo item "Contratos": suba um modelo (.docx com marcadores [[assim]]) e o sistema aprende sozinho quais campos ele tem. Ao gerar, os dados que o cadastro do cliente já souber (endereço, representante, etc.) entram automaticamente - só preenche o que for específico daquele contrato - e o resultado sai em PDF e também em Word, para acrescentar à mão um segundo representante quando houver mais de um. O botão "O que significa cada campo?" explica cada marcador para quem for mexer num modelo.',
  },
  {
    id: 'client-portal-floating-chat-button',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'Botão flutuante de Chat no Portal do Cliente',
    description:
      'O cliente agora tem um atalho fixo no canto da tela, em qualquer página do Portal, para abrir o Chat direto - sem precisar abrir o menu lateral toda vez.',
  },
  {
    id: 'client-portal-install-link',
    date: '1 de outubro de 2026',
    isoDate: '2026-10-01',
    type: 'feature',
    title: 'Link pronto para instalar o Portal, sem precisar logar',
    description:
      '/app/client/install é uma página pública (não pede login) só com o botão de instalar o Portal como app - pronta para mandar por WhatsApp/e-mail a alguém que ainda nem tem acesso, para já instalar antes de entrar.',
  },
  {
    id: 'sac-inside-suggestions',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'SAC dos clientes agora fica dentro de Sugestões e Melhorias',
    description:
      'Os dois canais de sugestão pararam de brigar por espaço no menu. "SAC e Sugestões" deixou de ser um item separado e passou a ser alcançado por um botão "SAC dos clientes" no topo da tela de Sugestões e Melhorias - o quadro continua recebendo o que vem da equipe, e o botão leva ao que vem dos clientes pelo Portal. Qualquer atendente vê o botão; incluir sugestão e configurar colunas seguem restritos a quem já podia. O item do menu fica destacado também enquanto se navega pelo SAC, e a tela do SAC ganhou um caminho de volta para o quadro.',
  },
  {
    id: 'sac-manifestations',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'SAC e Sugestões no Portal do Cliente',
    description:
      'O cliente ganhou um canal próprio no Portal para registrar sugestões, reclamações, elogios e pedidos de melhoria sobre o ERP, o atendimento, os atendentes, a implantação e o comercial. Ele escolhe o tipo e o assunto, descreve o caso, anexa arquivos se quiser, e acompanha o andamento pelo número (SAC-1, SAC-2...) com o histórico de cada movimentação e as respostas da equipe. Empresa e solicitante são preenchidos sozinhos e ele não consegue alterá-los. Do lado de dentro, em "SAC e Sugestões", a equipe vê tudo com filtros por empresa, tipo, assunto, status, responsável e período, com contadores de pendentes e de novas; dá para mudar o status, assumir o caso, responder ao cliente e deixar anotações internas - que o cliente nunca vê. Quando o caso precisa de atendimento de verdade, "Converter em Ticket" abre um chamado pelo fluxo normal preservando empresa, solicitante, descrição e anexos, e a manifestação fica vinculada a ele sem risco de duplicar.',
  },
  {
    id: 'conversation-assignment-lock',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Só quem está atribuído responde a conversa',
    description:
      'Quando uma conversa já tem um responsável, só essa pessoa (ou Administrador) consegue mandar mensagem pro cliente - tentar responder mostra um aviso com o botão "Atribuir a mim". Conversa sem ninguém atribuído atribui sozinha a quem responder primeiro. Nota privada continua liberada pra qualquer atendente, não é afetada.',
  },
  {
    id: 'client-chat-push-every-message',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'Push do Chat do Portal avisa em toda mensagem',
    description:
      'Quem ativou as notificações do Chat do Portal (cliente) agora é avisado no celular/navegador a cada mensagem da equipe, não só na primeira de cada atendimento.',
  },
  {
    id: 'conversation-audio-transcription',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Transcrição automática de áudio nas conversas',
    description:
      'Áudio recebido em qualquer canal (WhatsApp, Chat do Portal, etc.) agora é transcrito automaticamente - o texto aparece abaixo do player, poupando de precisar ouvir pra saber o que foi dito. Roda sozinho, em segundo plano, assim que o áudio chega.',
  },
  {
    id: 'client-portal-install-app',
    date: '1 de outubro de 2026',
    isoDate: '2026-10-01',
    type: 'feature',
    title: 'Cliente pode instalar o Portal como app',
    description:
      'O Portal do Cliente agora pode ser instalado como um aplicativo, com ícone próprio na tela inicial do celular ou na área de trabalho - um botão "Instalar app" aparece no cabeçalho do Portal quando o navegador permite.',
  },
  {
    id: 'client-portal-routing',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title:
      'Roteamento automático do ticket do Portal, por prioridade da Empresa',
    description:
      'Ticket aberto pelo Portal do Cliente deixou de passar pela fila de Triagem manual - ele já cai na Mesa certa sozinho. Em Configurações > Tickets > Roteamento do Portal, dá para definir uma Mesa fixa por nível de prioridade da Empresa (Baixa/Média/Alta), que vale por cima da Categoria escolhida pelo cliente quando configurada. A Triagem manual continua existindo normalmente para os demais canais.',
  },
  {
    id: 'client-portal-company-filter',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Filtro de Empresa no Portal do Cliente',
    description:
      'Contato vinculado a mais de uma Empresa agora pode filtrar a lista/Kanban de tickets do Portal por uma Empresa específica, no cabeçalho da tela.',
  },
  {
    id: 'conversation-ai-ticket-draft',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: '"Abrir ticket automaticamente" na conversa',
    description:
      'No painel de tickets vinculados de uma conversa, novo botão "Abrir ticket automaticamente (IA)": a IA lê a conversa inteira e sugere Mesa, Categoria, título e descrição - o mesmo formulário de sempre já abre preenchido, e o atendente revisa e confirma antes de criar. Útil principalmente quando o próprio atendente inicia a conversa (ex: chat do Portal do Cliente), caso em que a automação de triagem não entra sozinha.',
  },
  {
    id: 'client-portal-chat-full',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Chat do Portal do Cliente: histórico, avaliação e avisos',
    description:
      'O Chat do Portal do Cliente (item "Chat" no menu) evoluiu bastante: dá para gravar áudio e anexar arquivos na conversa; ao encerrar o atendimento, o cliente recebe um pedido de avaliação (nota de 1 a 5) direto no chat; conversas encerradas ficam guardadas em "Ver conversas anteriores", sem misturar com a atual; e o cliente pode ativar notificações do navegador para ser avisado quando a equipe chamar, mesmo com o Portal fechado (aviso por push e por e-mail na primeira mensagem de cada atendimento). O envio de mensagem no chat também ficou instantâneo (aparece na hora, sem esperar o servidor confirmar). Também é possível, pelo painel interno, iniciar uma conversa com o cliente pelo Chat do Portal (o mesmo "Nova Conversa" de sempre, escolhendo o canal "Portal do Cliente").',
  },
  {
    id: 'client-portal-principal-page',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Nova página "Principal" no Portal do Cliente',
    description:
      'O Portal do Cliente ganhou sua própria página inicial (mesmo esquema desta tela), com novidades do PORTAL especificamente - separada das novidades internas da equipe.',
  },
  {
    id: 'internal-chat-agent-photos',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'improvement',
    title: 'Fotos dos agentes no Chat Interno',
    description:
      'O Chat Interno passou a mostrar a foto de perfil de cada agente - nas mensagens, na lista lateral de conversas, no topo da conversa, no painel de membros do canal e nas telas de nova conversa e de gerenciar membros. Antes aparecia sempre a inicial do nome, mesmo para quem tinha foto cadastrada. Quem não tem foto continua com a inicial colorida.',
  },
  {
    id: 'ticket-complexity',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Complexidade do ticket',
    description:
      'Novo campo Complexidade no ticket, disponível na abertura e na edição, com os níveis Baixo, Médio e Alto criados automaticamente. Em Configurações > Tickets > Complexidade dá para criar, renomear, ativar/desativar e excluir níveis (as ações da tabela são ícones: lápis para editar, olho para ativar/desativar e lixeira para excluir), e marcar numa matriz quais Mesas oferecem cada um - a Mesa de Suporte pode ter os três e a Comercial só o Baixo, por exemplo. O formulário mostra apenas os níveis da Mesa do ticket, e ao trocar de Mesa um nível que a nova não oferece é limpado. Um ticket não pode ser encerrado sem complexidade definida (a recusa vem do servidor, não só da tela). A Busca detalhada ganhou filtro por uma ou mais complexidades e uma coluna ordenável na listagem.',
  },
  {
    id: 'internal-chat-delete-dialog-closes',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'improvement',
    title: 'Confirmar exclusão no Chat fecha a janela',
    description:
      'Ao confirmar a exclusão de uma mensagem do Chat Interno, a janela de confirmação fecha sozinha - antes era preciso fechá-la à mão depois de apagar. A exclusão de canal também passou a perguntar numa janela do sistema, e não mais no aviso do navegador.',
  },
  {
    id: 'internal-chat-notification-opens-room',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'improvement',
    title: 'Notificação do Chat abre a conversa certa',
    description:
      'Clicar na notificação do Chat Interno agora abre a conversa ou o canal de onde veio o aviso, e não apenas a tela do Chat. Vale também quando o Chat já está aberto em outra sala - antes, nesse caso, o clique não levava a lugar nenhum.',
  },
  {
    id: 'internal-chat-manage-channel',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'improvement',
    title: 'Chat Interno: editar canal e ver os membros',
    description:
      'Três botões que não faziam nada agora funcionam. Os três pontos no cabeçalho do canal abrem a edição (nome, descrição, canal fixo e quem pode escrever), e o mesmo aparece com o botão direito sobre o canal na lista - só para Administrador. O botão de membros abre uma faixa lateral com quem está no canal, a disponibilidade de cada um e, num canal de aviso, a marca de quem pode escrever. E a confirmação de apagar mensagem virou um modal do próprio sistema, em vez do aviso do navegador.',
  },
  {
    id: 'internal-chat-announcement-channel',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'feature',
    title: 'Chat Interno: canal fixo e canal de aviso',
    description:
      'Ao criar um canal há duas opções novas. "Canal fixo" deixa o canal no topo da lista, acima dos outros - é onde fica o que todos precisam ver. E "Quem pode escrever" permite marcar "somente as pessoas autorizadas": todos leem, mas apenas quem foi autorizado escreve. Administradores escrevem sempre, sem precisar ser marcados. Quem não pode escrever vê o motivo no lugar do campo de mensagem, e o canal aparece com um cadeado na lista.',
  },
  {
    id: 'internal-chat-admin-and-delete',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'feature',
    title:
      'Chat Interno: administrador vê todos os canais, e dá para apagar mensagem',
    description:
      'Administradores agora veem todos os canais da conta, inclusive os que não criaram e os em que não entraram - canal é da empresa. Conversa entre duas pessoas continua sendo só de quem participa, para qualquer papel. Também é possível apagar mensagem: cada um apaga as suas, e o Administrador apaga qualquer uma. A mensagem sai na hora da tela de todos que estão com a sala aberta; respostas a ela continuam lá, só perdem a citação.',
  },
  {
    id: 'internal-chat-preview-and-notification',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'improvement',
    title: 'Chat Interno: prévia na lista e nome do canal na notificação',
    description:
      'Duas correções. A lista de conversas dizia "Sem mensagens ainda" em salas que tinham mensagens - ela só conseguia ler o histórico depois de a sala ser aberta, e agora a última mensagem vem junto da lista. E a notificação de mensagem de canal passou a se apresentar como "Canal - Pessoa" em vez de apenas "Chat interno", que era igual para tudo e não dizia de onde vinha.',
  },
  {
    id: 'theme-travels-between-devices',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'improvement',
    title: 'O tema escolhido vale no celular também',
    description:
      'O tema (claro/escuro) agora fica gravado na sua conta e não mais só naquele navegador: quem escolhe escuro no computador abre o sistema no celular já no escuro. A tela de login passou a respeitar a mesma escolha - antes ela seguia só o aparelho e abria clara num celular no modo claro. E há um lugar novo para escolher: Perfil > Aparência, com "Claro", "Escuro" e "Seguir o aparelho" - antes só dava pelo atalho Ctrl+K, que num celular não existe.',
  },
  {
    id: 'login-brand-on-mobile',
    date: '29 de setembro de 2026',
    isoDate: '2026-09-29',
    type: 'design',
    title: 'Tela de login com a identidade também no celular',
    description:
      'No celular a tela de login abria branca, só com a logo pequena, sem nada do painel de marca que aparece no computador. Agora a marca vem numa faixa no topo, com o mesmo fundo escuro, a mesma logo animada e a mesma frase - o formulário fica abaixo dela. No computador nada muda.',
  },
  {
    id: 'suggestions-board-column-layout',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Quadro de Sugestões desalinhado',
    description:
      'As colunas do quadro de Sugestões estavam montadas na horizontal: o nome da coluna ficava ao lado dos cards, em vez de acima deles, e as colunas se comprimiam umas contra as outras. Agora cada coluna tem largura fixa, o título em cima e os cards embaixo, no mesmo formato do Kanban de Tickets. A etiqueta de concluído também voltou a ficar legível no tema escuro.',
  },
  {
    id: 'suggestions-fields-settings-labels',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Prioridade e Categoria das sugestões nas Configurações',
    description:
      'Os campos Prioridade, Categoria e Tempo gasto (horas) da sugestão já existiam, mas os rótulos apareciam na tela como código (por exemplo "SUGGESTIONS.PRIORITY.LABEL") e não havia onde cadastrar as listas. Agora Configurações > Sugestões traz, abaixo das colunas, as seções Prioridades e Categorias, onde o Administrador adiciona, renomeia e exclui os itens - excluir um item em uso apenas desmarca as sugestões, sem apagar nada.',
  },
  {
    id: 'ticket-delete-closes-tab',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Excluir ticket fecha a aba junto com o card',
    description:
      'Ao excluir um chamado, a aba dele na barra de cima desaparece junto com o card. Antes ela continuava aberta apontando para um ticket que já não existia até recarregar a página. Vale também quando outra pessoa exclui o chamado, quando a exclusão acontece em outra aba do navegador e para os chamados filhos excluídos junto com o pai.',
  },
  {
    id: 'triage-sidebar-counter',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Contador de chamados na Triagem',
    description:
      'O item "Triagem" no menu lateral agora mostra quantos chamados estão esperando aceite, do mesmo jeito que a Caixa de entrada mostra as notificações não lidas. Dá para saber que chegou algo sem abrir a tela, e o número se atualiza sozinho quando um chamado entra na fila ou é encaminhado.',
  },
  {
    id: 'customer-communication-email-flag',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Escolher se a comunicação vai por e-mail',
    description:
      'Na aba Comunicação e no modal de fechamento do ticket há uma opção nova: "Enviar e-mail ao cliente", marcada por padrão. Desmarcando, a mensagem é apenas registrada no chamado - ela continua aparecendo para o cliente na Área do Cliente e continua valendo para fechar o ticket, mas nenhum e-mail é enviado. Serve para quando a equipe já falou com o cliente por telefone ou WhatsApp e quer só deixar isso registrado. Na lista, essas mensagens aparecem marcadas como "Sem e-mail", e o Histórico do ticket diz "Comunicação registrada (sem e-mail)".',
  },
  {
    id: 'ticket-close-no-file-prompt',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Encerrar chamado sem abrir a tela de enviar arquivo',
    description:
      'No modal de encerramento, clicar na área da mensagem abria a tela de escolher arquivo do computador. Era o campo da mensagem que estava ligado por engano ao envio de imagem do editor de artigos. Agora o clique só coloca o cursor no texto - anexo não faz parte do encerramento.',
  },
  {
    id: 'assignee-level-on-create',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Abrir chamado indicando o responsável de qualquer nível',
    description:
      'Em Mesas que usam níveis de responsável, o formulário de novo chamado agora mostra um campo por nível (Responsável 1, Responsável 2, e assim por diante), cada um listando só quem está habilitado naquele nível. Dá para abrir indicando apenas o Nível 2, ou nenhum. Antes havia um campo só, que gravava sempre no Nível 1 - e numa Mesa sem ninguém cadastrado no Nível 1 a abertura ficava travada, com o erro "não está habilitado a atuar no nível 1 desta Mesa".',
  },
  {
    id: 'whatsapp-new-conversation-automation-skip',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'WhatsApp: "Nova Conversa" não entra na triagem automática',
    description:
      'Quando você inicia uma conversa pelo botão "Nova Conversa", a resposta do cliente agora segue como conversa normal - o fluxo de triagem automática (perguntar CNPJ, etc.) não entra mais por cima de um atendimento que o próprio atendente já começou.',
  },
  {
    id: 'suggestions-admin-create-assignee',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Sugestões e Melhorias: incluir card e responsável',
    description:
      'O quadro (antes "Sugestões") passou a se chamar "Sugestões e Melhorias". Administrador agora tem um botão "Incluir" pra registrar direto no quadro algo que já está sendo produzido, e pode marcar um "Responsável" (sempre um Administrador) em cada card - visível pra todo mundo, editável só por quem gerencia o quadro.',
  },
  {
    id: 'ticket-move-parent-automation',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Automação: ticket pai muda de estágio junto com o filho',
    description:
      'Novo tipo de ação em Configurações > Estágios: quando um ticket entra num Estágio escolhido, o ticket pai dele (se tiver) pode mudar automaticamente pra um Estágio específico, até de outra Mesa. Dá pra configurar quantas regras desse tipo precisar, em pares de Mesas diferentes.',
  },
  {
    id: 'conversation-list-width',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Lista de Conversas mais larga',
    description:
      'A coluna com a lista de conversas ficou mais larga, pra caber melhor o botão "Nova conversa" e os detalhes de cada conversa sem cortar o visual.',
  },
  {
    id: 'conversations-new-conversation-button',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Botão "Nova conversa" na área de Conversas',
    description:
      'Igual já existia em Contatos, agora dá pra iniciar uma conversa nova direto pelo cabeçalho da lista de Conversas, sem precisar abrir o menu lateral.',
  },
  {
    id: 'suggestions-board',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Sugestões de melhoria: quadro Kanban novo',
    description:
      'Na tela Principal, o botão "Tem uma melhoria para sugerir? Fale conosco" abre um formulário simples (título + descrição). Cada sugestão vira um card no quadro "Sugestões" (menu lateral), com colunas configuráveis em Configurações > Sugestões. Qualquer agente ou administrador vê o quadro inteiro; só Administrador (ou quem tiver a permissão) move os cards entre colunas ou configura o quadro. Administradores recebem uma notificação a cada sugestão nova.',
  },
  {
    id: 'team-handles-flags',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Mesas podem sair de Conversas e/ou Projetos',
    description:
      'Em Configurações > Mesas, dois campos novos: "conversa com clientes" e "executa Projetos". Desmarcando, a Mesa some da aba Times em Conversas e/ou do filtro de Equipe em Projetos - por padrão os dois continuam marcados, então nenhuma Mesa muda de lugar sozinha.',
  },
  {
    id: 'ticket-delete',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Excluir ticket (Administrador)',
    description:
      'Novo item "Excluir ticket" no menu de ações do ticket, só para Administrador. Se o ticket tiver chamados filhos vinculados, pergunta se quer excluir tudo junto ou só manter os filhos, desvinculados.',
  },
  {
    id: 'ticket-stage-automation',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Ticket muda de estágio sozinho quando a conversa é atribuída',
    description:
      'Novo tipo de coluna "Em atendimento" em Configurações > Estágios (opcional): quando marcada, o ticket vinculado a uma conversa pula pra essa coluna automaticamente assim que alguém assume a conversa - pega da fila, se auto-atribui, ou é atribuído por um administrador.',
  },
  {
    id: 'custom-roles-refinement',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Funções Personalizadas mais detalhadas',
    description:
      'Painel de Implantação e Projetos agora têm permissões separadas - dá pra liberar uma Função pra ver um sem o outro. Configurações > Mesas e Filas passaram a respeitar as Funções Personalizadas também, não só Administrador.',
  },
  {
    id: 'project-client-search',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Busca de Cliente em Projetos',
    description:
      'O campo Cliente, tanto ao criar um projeto quanto no card de detalhe, virou uma busca por nome ou código em vez de uma lista longa pra rolar. No card de detalhe o campo também ganhou uma linha própria, mais larga.',
  },
  {
    id: 'whatsapp-asterezap-fix',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'WhatsApp: iniciar e responder conversa',
    description:
      'Corrigido: o WhatsApp conectado via AstereZap estava bloqueado pela regra de 24h da Meta (que não se aplica a esse tipo de conexão), e a tela de Nova Conversa só mostrava modelo, sem caixa de texto livre. Agora dá pra iniciar e responder conversas normalmente.',
  },
  {
    id: 'queue-tab-assignment-fix',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: '"Em Fila" não mostra mais quem já foi atribuído',
    description:
      'Corrigido: uma conversa que já tinha atendente continuava aparecendo na aba "Em Fila" junto de "Minhas". Agora ela some da fila assim que é atribuída, sem perder o registro de qual fila ela veio.',
  },
  {
    id: 'hide-channels-tab',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Aba "Canais" removida das Conversas',
    description:
      'A aba "Canais" (redundante com Times/Rótulos pro dia a dia de atendimento) saiu do menu lateral de Conversas.',
  },
  {
    id: 'client-session-expired',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Área do Cliente: sessão vencida volta para o login',
    description:
      'Quando o acesso do cliente era desligado, ou ele redefinia a própria senha, a sessão antiga deixava de valer - mas as telas continuavam tentando usá-la e não carregavam, sem explicar o motivo. Agora, ao detectar que a sessão venceu, a Área do Cliente limpa o acesso e leva de volta à tela de login.',
  },
  {
    id: 'push-preference',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Notificação push agora acompanha você entre os dispositivos',
    description:
      'Em Perfil > Notificações, a opção de receber notificações push virou uma preferência sua, com botão de Salvar - antes ela valia só para o navegador em que foi ligada, e entrar de outro computador mostrava tudo desligado. Agora, ao entrar de um aparelho novo, a tela não pergunta de novo se você quer receber: ela apenas avisa que falta liberar a permissão naquele navegador, com um botão para isso.',
  },
  {
    id: 'sidebar-ticket-search',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Busca do menu lateral abre o ticket pelo número',
    description:
      'O campo de busca do menu lateral ("Nº do ticket") virou busca de ticket: digite o número e aperte Enter que ele abre direto, sem passar por tela de resultados. Aceita com ou sem "#". Com o menu recolhido, o ícone de lupa abre o campo ao lado. Atenção: ele deixou de levar para a busca geral de conversas, contatos e artigos.',
  },
  {
    id: 'companies-priority-filter',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'feature',
    title: 'Filtro por Prioridade e mais dados no card de Empresas',
    description:
      'Na tela de Empresas, novo botão "Filtrar por prioridade" no cabeçalho (Todas/Baixa/Média/Alta). O card de cada empresa na lista agora mostra também Código, Prioridade, Razão Social e CNPJ, além do nome/domínio/contatos que já apareciam.',
  },
  {
    id: 'brand-duesoft',
    date: '28 de setembro de 2026',
    isoDate: '2026-09-28',
    type: 'improvement',
    title: 'Nome da marca padronizado como "Duesoft"',
    description:
      'O nome da marca aparecia com o S maiúsculo no meio, em telas, e-mails e textos de configuração. Agora é sempre "Duesoft", inclusive no rodapé dos e-mails ("Este e-mail foi enviado por Duesoft").',
  },
  {
    id: 'company-cnpj-comparison-import',
    date: '27 de setembro de 2026',
    isoDate: '2026-09-27',
    type: 'feature',
    title: 'Comparativo de CNPJ na importação',
    description:
      'Nova opção "Comparar planilha de CNPJ" na aba Planilhas de Configurações > Dados: não altera nenhum cadastro, só compara os CNPJs de uma planilha com as empresas já cadastradas e mostra quantos já existem e quantos ainda faltam, com uma lista pra baixar dos que faltam.',
  },
  {
    id: 'company-codigo-priority-import',
    date: '27 de setembro de 2026',
    isoDate: '2026-09-27',
    type: 'feature',
    title: 'Novo campo Código na Empresa + importação Código/CNPJ/Prioridade',
    description:
      'Empresas ganharam um campo "Código" (aparece pequeno, ao lado do nome, no topo do cadastro) - só é preenchido por importação, nunca editado à mão. Nova opção "Código/CNPJ/Prioridade" na aba Planilhas de Configurações > Dados: atualiza empresas já cadastradas casando por Código ou CNPJ, e preenche a Prioridade (Baixa/Média/Alta) como valor inicial para quem ainda não tem mensalidade configurada - assim que a mensalidade for definida, o cálculo automático passa a valer.',
  },
  {
    id: 'client-area',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title:
      'Área do Cliente: o contato da empresa entra e acompanha os chamados',
    description:
      'O contato cadastrado numa Empresa passa a ter acesso próprio ao sistema. Em Empresas > contato, novo botão para liberar o acesso e definir a senha - ele entra pela mesma tela de login da equipe, com o e-mail do cadastro. Lá dentro ele vê só os chamados da própria empresa, em lista separada por Estágio (com grupos que dá pra recolher) ou em Kanban, e abre chamado informando apenas Categoria, Assunto, Descrição e anexos. Dentro do ticket ele acompanha Informações gerais, Comunicação (só as mensagens que não são internas, e ele pode responder e mandar imagens), Compromissos e Checklist, esses dois só para visualizar. Também recebe notificações e pode redefinir a senha pelo "Esqueci minha senha" da tela de login.',
  },
  {
    id: 'ticket-triage',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'feature',
    title: 'Triagem dos chamados abertos pelo cliente',
    description:
      'Chamado aberto pela Área do Cliente não entra direto no Kanban da equipe: ele espera numa tela nova de Triagem, onde alguém confere e encaminha para a Mesa e o Estágio certos. Quem tem acesso à tela é avisado assim que algo chega na fila. Em Configurações > Tickets > Categorias, duas opções novas por categoria: exigir anexo na abertura (útil em "Erro", que quase sempre precisa de print ou log) e escolher quais categorias aparecem para o cliente - como Categoria é por Mesa, sem isso o mesmo nome se repetia uma vez por Mesa na lista dele.',
  },
  {
    id: 'ticket-tabs-overflow',
    date: '25 de setembro de 2026',
    isoDate: '2026-09-25',
    type: 'improvement',
    title: 'Abas de ticket não rolam mais para o lado',
    description:
      'A barra de abas deixou de ter rolagem horizontal. Quando as abas não cabem na tela, aparece um botão "+" com a lista de todos os chamados abertos, cada um com botão para fechar - e a aba que você está lendo nunca é escondida.',
  },
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
