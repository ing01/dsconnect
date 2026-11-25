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
    id: 'projects-compact-cards-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'improvement',
    title: 'Projetos: botão "Cards compactos"',
    description:
      'No quadro de Projetos, ao lado da busca, há o mesmo botão de "Cards compactos" dos tickets: colunas mais estreitas e cards com nome, cliente, progresso e prazo em poucas linhas, para caberem mais projetos na tela. A escolha vale para os dois quadros.',
  },
  {
    id: 'agenda-full-text-and-time-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'improvement',
    title: 'Agenda mostra o horário e o título completo',
    description:
      'Na Agenda, os eventos agora mostram o horário antes do título, inclusive na visão de mês, e o título quebra linha em vez de ser cortado. Nas visões de semana e dia, passe o mouse sobre um evento curto para ele crescer e mostrar todo o texto.',
  },
  {
    id: 'kanban-shows-resolved-and-closed-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'improvement',
    title: 'Kanban mostra também os tickets resolvidos e finalizados',
    description:
      'Tickets com status Resolvido ou Finalizado agora continuam aparecendo no quadro Kanban, no estágio em que estiverem. Em cada coluna, os abertos vêm primeiro e os concluídos depois, do mais recente para o mais antigo. Cards finalizados não podem ser arrastados. Só os cancelados saem do quadro.',
  },
  {
    id: 'paused-chat-respects-open-chats-limit-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'fix',
    title: 'Chat pausado que volta não estoura mais o limite do agente',
    description:
      'Quando o cliente de um chat pausado responde e o atendente já está no limite de chats abertos, a conversa não volta mais para ele: segue para a fila ou para o rodízio, para outro atendente com vaga. Se o próprio atendente reabrir o chat, ele continua com a conversa.',
  },
  {
    id: 'kb-tree-bigger-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'improvement',
    title: 'Artigos do portal: árvore e leitor maiores',
    description:
      'Na visão em árvore dos Artigos, a área agora usa a largura toda da tela (antes ficava limitada ao centro), é mais alta e tem a árvore mais larga. Sem artigo aberto, o leitor ocupa o espaço que sobrava no lado direito; ao abrir um artigo, o painel de detalhes aparece como antes.',
  },
  {
    id: 'ticket-development-tab-columns-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'improvement',
    title:
      'Aba Desenvolvimento mostra prioridade, status, estágio e responsável',
    description:
      'Na aba Desenvolvimento do ticket, os tickets de desenvolvimento vinculados agora aparecem numa tabela com Prioridade, Status, Estágio e Responsável. Dá para saber se o dev já finalizou sem precisar abrir cada ticket.',
  },
  {
    id: 'dev-child-close-without-customer-message-2026-11-25',
    date: '25 de novembro de 2026',
    isoDate: '2026-11-25',
    platform: 'web',
    type: 'improvement',
    title: 'Ticket filho do Desenvolvimento encerra sem comunicação ao cliente',
    description:
      'Ao encerrar um ticket filho numa Mesa de Desenvolvimento, a comunicação com o cliente deixou de ser obrigatória: quem fala com o cliente é o ticket pai. Categoria, Catálogo, Resolução e checklist continuam sendo exigidos.',
  },
  {
    id: 'ticket-communication-count-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'improvement',
    title: 'Ticket: a aba Comunicação mostra a quantidade',
    description:
      'Na tela do ticket, a aba Comunicação agora mostra quantas comunicações existem, por exemplo "Comunicação (2)". O número soma os comentários internos e as mensagens trocadas com o cliente, e já aparece sem abrir a aba. Ao comentar ou apagar um comentário, ele se atualiza na hora.',
  },
  {
    id: 'ticket-assign-to-me-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'improvement',
    title: 'Ticket: botão "Atribuir a mim" ao lado do responsável',
    description:
      'Na tela do ticket, ao lado de cada campo de responsável (e de cada nível, nas Mesas com níveis), há o botão "Atribuir a mim". Com um clique você assume o ticket. Ele só aparece se você pode editar o ticket, ainda não é o responsável daquele campo e está habilitado naquele nível. Em tela estreita, o botão desce para a linha de baixo.',
  },
  {
    id: 'portal-hides-child-tickets-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Portal do Cliente não mostra mais tickets filhos de Mesas internas',
    description:
      'O parâmetro "Aparece no Portal do Cliente" da Mesa agora vale também para o que o cliente enxerga: tickets filhos de uma Mesa fora do Portal (e tickets de Mesas com Módulo de Desenvolvimento) deixam de aparecer. O cliente vê só o ticket pai, mesmo que ele passe por uma Mesa interna.',
  },
  {
    id: 'impediment-release-frees-child-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Impedimento retirado no ticket pai também libera o filho',
    description:
      'Quando o impedimento do ticket pai (que veio de um ticket filho) é retirado, o impedimento do filho também é retirado, e o responsável pelo filho recebe o aviso. A resolução fica registrada no comentário e no histórico dos dois tickets.',
  },
  {
    id: 'suggestion-block-button-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'feature',
    title: 'Sugestões: botão "Impedir" avisa quem abriu',
    description:
      'No detalhe de uma sugestão, quem gerencia o quadro pode clicar em "Impedir" e explicar quais detalhes faltam. Quem abriu a sugestão recebe uma notificação com esse texto, e o card ganha o selo "Impedida" até alguém clicar em "Remover impedimento".',
  },
  {
    id: 'internal-chat-sidebar-sections-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'improvement',
    title: 'Chat interno: canais no topo e seções recolhíveis',
    description:
      'Na barra lateral do Chat interno, os Canais agora aparecem antes das conversas privadas, sem precisar rolar a lista de conversas até o fim. Os títulos "Canais" e "Conversas" podem ser recolhidos com um clique (o navegador lembra sua escolha); recolhida, a seção mostra quantas mensagens não lidas tem. Ao buscar, tudo aparece de novo para o resultado não ficar escondido.',
  },
  {
    id: 'agenda-color-follows-assignee-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Agenda: a cor segue o responsável atribuído',
    description:
      'Na Agenda, a cor do evento agora é a da pessoa atribuída (o participante), e não a de quem criou. Se um gestor agenda algo para outra pessoa, o evento aparece na cor dela. Com mais de um participante, vale o de menor cadastro, para a cor não mudar de um momento para o outro; sem participantes, segue quem criou, como antes.',
  },
  {
    id: 'ticket-creator-opens-chat-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'improvement',
    title: 'Ticket: clique no nome de quem criou para abrir o chat interno',
    description:
      'No cartão "Origem" do ticket, o nome em "Criado por" agora é um link: ao clicar, o Chat interno abre direto na conversa com a pessoa (e cria a conversa se ainda não existir). Quando o ticket foi criado por você mesmo, o nome continua só como texto.',
  },
  {
    id: 'app-session-expired-relogin-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'mobile',
    type: 'fix',
    title: 'App do cliente: sessão expirada pede o login de novo',
    description:
      'Quando a sessão do cliente deixava de valer (por exemplo, ao sair no portal pelo navegador ou redefinir a senha), o app mostrava "Sessão inválida ou acesso à Área do Cliente desativado" nas telas. Agora o app volta para o login com o aviso "Sua sessão expirou. Entre novamente." e, se a biometria estiver ativa, já pede a leitura para entrar de novo, sem digitar a senha.',
  },
  {
    id: 'triage-summary-scroll-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Triagem: resumo do chamado rola quando a descrição é grande',
    description:
      'Na janela "Resumo do chamado" da Triagem, uma descrição longa empurrava os botões para fora da tela e não dava para clicar em "Abrir e encaminhar". Agora só o texto rola dentro da janela, e os botões "Ver ticket completo" e "Abrir e encaminhar" ficam sempre visíveis.',
  },
  {
    id: 'transfer-keeps-extra-assignees-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Transferir ticket com dois responsáveis não trava mais',
    description:
      'Ao transferir um ticket para uma Mesa que não usa níveis de responsável (ou onde a pessoa não está habilitada no nível), a transferência era recusada com o aviso de que a Mesa não aceita o responsável. Agora a transferência acontece e quem não cabe como responsável na Mesa nova continua no ticket como seguidor, sem perder o acompanhamento. Vale também ao arrastar o ticket no Kanban para outra Mesa.',
  },
  {
    id: 'client-chat-line-breaks-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Chat do cliente mostra as quebras de linha corretamente',
    description:
      'Mensagens da equipe com mais de uma linha (como a de boas-vindas do atendimento) chegavam na Área do Cliente com uma barra "\\" solta no fim de cada linha. Agora a quebra de linha aparece como a equipe escreveu, no portal e no app, tanto no chat de agora quanto no histórico.',
  },
  {
    id: 'triage-forwarded-leaves-queue-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Chamado encaminhado pela tela do ticket sai da Triagem',
    description:
      'Quando alguém mudava a Mesa ou o Estágio de um chamado pela tela do ticket (ou movia no Kanban, ou transferia) em vez de usar "Abrir e encaminhar", o chamado seguia para o lugar escolhido mas continuava parado na fila da Triagem. Agora, encaminhar por qualquer um desses caminhos já tira o chamado da Triagem e registra quem decidiu.',
  },
  {
    id: 'app-tutorial-video-in-app-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'mobile',
    type: 'improvement',
    title: 'App: tutoriais tocam dentro do app',
    description:
      'Ao tocar em "Assistir vídeo" na aba Tutoriais, o vídeo agora abre numa tela do próprio app, com controles de pausar, avançar e tela cheia. Antes o arquivo era baixado ou aberto fora do app. Vale para vídeos do YouTube, do Vimeo e para os arquivos enviados pela equipe.',
  },
  {
    id: 'ticket-communication-full-text-2026-11-24',
    date: '24 de novembro de 2026',
    isoDate: '2026-11-24',
    platform: 'web',
    type: 'fix',
    title: 'Comunicações enviadas mostram a mensagem completa',
    description:
      'No ticket, a lista "Comunicações enviadas" agora mostra o texto inteiro do que foi enviado ao cliente, com as quebras de linha como foram escritas. Antes a mensagem aparecia cortada em uma linha só.',
  },
  {
    id: 'images-faster-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'improvement',
    title: 'Imagens carregam mais rápido',
    description:
      'As imagens dos tickets, do chat interno e das conversas agora chegam em uma requisição só (antes eram duas) e ficam guardadas no seu navegador: ao abrir de novo a mesma tela, elas aparecem na hora, sem baixar outra vez. O cache é só do navegador de quem está logado, então o acesso continua protegido por login.',
  },
  {
    id: 'integration-api-family-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'feature',
    title: 'API de Integração: pai e filhos do ticket',
    description:
      'A consulta de tickets da API (a lista e o detalhe) passa a trazer parent_ticket_id (o id do pai, ou nulo) e child_tickets (os filhos, com id, display_id, team_id, ticket_column_id e status; lista vazia quando não há).',
  },
  {
    id: 'ticket-cancel-permission-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'feature',
    title: 'Permissão para cancelar tickets',
    description:
      'Cancelar um ticket continua só para administradores, mas agora dá para liberar a quem você quiser: em Configurações > Funções personalizadas há a nova permissão "Cancelar tickets". Ela vem desmarcada em todas as funções. Quem não pode cancelar deixa de ver a opção "Cancelado" no ticket e no menu do cartão, em vez de tentar e receber um erro de permissão.',
  },
  {
    id: 'internal-chat-stick-bottom-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title: 'Chat interno: a conversa fica na última mensagem',
    description:
      'A conversa abre na última mensagem e continua nela: mensagens novas que chegam passam a rolar a tela sozinhas, e imagens ou anexos que terminam de carregar não tiram mais você do fim. Se você sobe para ler o histórico, a tela não puxa você de volta; ao voltar até o fim, ela volta a acompanhar.',
  },
  {
    id: 'impediment-released-notice-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'feature',
    title: 'Impedimento removido avisa o responsável pelo ticket filho',
    description:
      'Quando um impedimento é removido ou concluído, o responsável pelo ticket filho recebe uma notificação que abre o ticket dele. Se o impedimento era do próprio filho, avisa o responsável dele; se era do ticket pai, avisa o filho de onde ele veio (ou todos os filhos abertos, quando o impedimento era do próprio pai). Quem removeu o impedimento não avisa a si mesmo. Além disso, as funções personalizadas ganharam a permissão "Ver a aba Notificações": ela vem marcada nas funções novas e foi concedida a todas as existentes, então ninguém fica sem a aba (administradores e agentes sempre veem). Quem quiser tirar a aba de uma função desmarca a permissão em Configurações > Funções personalizadas.',
  },
  {
    id: 'conversation-panel-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    type: 'feature',
    platform: 'web',
    title: 'Painel de Conversas',
    description:
      'Novo item "Painel de Conversas" no menu: três cards mostram as conversas em atendimento com um atendente (verde), aguardando na fila (laranja) e esperando há muito tempo na fila, sem atendente (vermelho), com totais, maior espera e lista por card. Atualiza em tempo real, tem modo TV e aviso sonoro. O tempo para a fila ficar vermelha é configurado em Configurações > Painel de Conversas. Administradores sempre veem; para outras pessoas, marque "Ver o Painel de Conversas" na Função personalizada.',
  },
  {
    id: 'client-chat-first-connect-race-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title: 'Área do Cliente: mensagem de automação não sumia mais que no F5',
    description:
      'Quando uma automação (como a mensagem de boas-vindas ao atribuir a Mesa) respondia quase na mesma hora em que o cliente mandava a primeira mensagem de uma conversa nova, essa resposta podia não aparecer na tela ao vivo - só depois de um F5. Corrigido dos dois lados: o chat agora resincroniza logo na primeira conexão (não só ao reconectar depois de uma queda), e o envio dessas automações no chat do Portal do Cliente passa a esperar alguns instantes, dando tempo da tela terminar de se conectar antes da mensagem chegar. Os demais canais (WhatsApp, e-mail, Website Widget) continuam respondendo na hora, sem esse atraso.',
  },
  {
    id: 'client-chat-resolved-start-new-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title:
      'Chat da Área do Cliente: a avaliação não se perde mais, e "Iniciar novo chat"',
    description:
      'Ao encerrar o atendimento, a pesquisa de satisfação agora continua visível mesmo depois de um F5 ou de trocar de aba - antes, a tela voltava em branco e a avaliação ficava impossível de responder. No lugar da caixa de mensagem, aparece um botão "Iniciar novo chat" para começar uma conversa nova quando quiser. Também foi removido o botão duplicado de ativar notificações dentro do Chat (o do cabeçalho já faz isso).',
  },
  {
    id: 'message-image-chip-retry-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title: 'Conversas: imagem não trava mais em "Falha no carregamento"',
    description:
      'Uma falha passageira de rede ao carregar a miniatura de uma imagem enviada junto com texto travava a mensagem em "Falha no carregamento" para sempre, mesmo a imagem estando disponível. Agora ela tenta carregar de novo automaticamente antes de desistir, como já acontecia com imagens enviadas sozinhas.',
  },
  {
    id: 'ticket-transfer-keep-assignee-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title: 'Transferir ticket: o Responsável atual vem preenchido',
    description:
      'Ao abrir "Transferir ticket" para um chamado de outra Mesa depois de já ter usado a tela com um ticket diferente, o campo Responsável aparecia sempre vazio ("Sem responsável"), mesmo o ticket já tendo alguém. Agora o Responsável atual do ticket vem preenchido corretamente ao abrir, e trocar a Mesa continua limpando o campo normalmente.',
  },
  {
    id: 'client-chat-reconnect-paste-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title:
      'Área do Cliente: chat atualiza sozinho e aceita colar imagem/arquivo',
    description:
      'Se a conexão caísse e voltasse (celular sem sinal, notebook que dormiu), mensagens recebidas nesse intervalo só apareciam depois de um F5. Agora o chat resincroniza sozinho ao reconectar. Também passou a aceitar colar (Ctrl+V) uma imagem ou arquivo copiado direto na caixa de mensagem, sem precisar escolher pelo clipe.',
  },
  {
    id: 'service-catalog-loading-fix-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'fix',
    title:
      'Catálogo de Serviços: corrigido erro que travava a classificação do ticket',
    description:
      'Em contas com um catálogo grande, abrir o seletor de Catálogo de Serviços (ao fechar ou classificar um ticket) podia travar e dar erro, deixando a lista sempre vazia. Corrigida a causa no servidor, e o seletor agora mostra um indicador de carregamento enquanto busca, em vez de parecer vazio.',
  },
  {
    id: 'client-management-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    platform: 'web',
    type: 'feature',
    title: 'Gestão de clientes, Nível na lista e filtros por nicho',
    description:
      'Nova tela Gestão de clientes (Empresas > Gestão de clientes, só administradores): filtre, marque vários clientes e altere de uma vez nicho, subnicho, nível, especialista, módulos, tipo de cobrança e a nova Situação (Ativo/Inativo; todos começam Ativos). A Prioridade do cliente foi removida (lista, ficha, filtros, limiares de mensalidade, roteamento do Portal por prioridade e a coluna Prioridade da planilha Código/CNPJ); a lista mostra o Nível do cliente. Na Gestão avançada de tickets há filtros novos por nicho, subnicho e nível da empresa.',
  },
  {
    id: 'kanban-drag-fix-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'fix',
    title: 'Kanban: arrastar tickets ficou mais firme',
    description:
      'Ao arrastar um ticket entre estágios, o cartão fica onde foi solto na hora, sem travar nem voltar ao lugar por causa de atualizações que chegam no meio do movimento. Se o estágio recusar a mudança (por exemplo, exige responsável), o cartão volta para onde estava. A coluna inteira, até o fim da altura, aceita o ticket, e as colunas vazias ficaram mais fáceis de acertar.',
  },
  {
    id: 'backlog-keep-state-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'fix',
    title: 'Backlog e Sprint ativo voltam como estavam',
    description:
      'Ao trocar de aba (ou abrir um ticket) e voltar, o Backlog e o Sprint ativo mantêm a visão escolhida, os filtros e o ponto da rolagem, e releem os tickets para mostrar o que mudou. Projetos e o Kanban também voltam no mesmo ponto da rolagem.',
  },
  {
    id: 'mobile-client-tutorials-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'mobile',
    type: 'feature',
    title: 'App: aba Tutoriais para o cliente',
    description:
      'No app, o cliente ganhou a aba Tutoriais, igual à da Área do Cliente: os módulos aparecem como cards e, ao tocar, mostram os vídeos de dentro. O vídeo abre no player do aparelho (YouTube, Vimeo ou arquivo). O conteúdo é o mesmo cadastrado em Configurações > Tutoriais do Portal.',
  },
  {
    id: 'client-chat-sending-state-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'improvement',
    title: 'Chat do cliente: áudio e anexos mostram "Enviando…"',
    description:
      'No chat do Portal, ao enviar um áudio ou anexo, a mensagem agora mostra um indicador de carregamento ("Enviando áudio…") até o envio ser confirmado, em vez de aparecer uma bolha vazia.',
  },
  {
    id: 'ticket-image-gallery-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'improvement',
    title: 'Imagens do ticket: navegar entre elas e visualizar maior',
    description:
      'Ao abrir uma imagem de um ticket que tem mais de uma, dá para passar para a anterior e a próxima com as setas do teclado ou com os botões nas laterais, e o contador mostra em qual você está. A janela da imagem ficou bem maior.',
  },
  {
    id: 'tabs-keep-state-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'fix',
    title: 'Abas: as telas mantêm o que você fez ao trocar de aba',
    description:
      'Ao trocar de aba e voltar, Tickets (Kanban), Projetos, Relatórios de implantação, Agenda e o Comercial (Clientes, Vendas e Dashboard) mantêm filtros, busca e rolagem, em vez de recomeçar do zero. Projetos e o Kanban releem os dados ao voltar. As Conversas ainda recarregam ao trocar de aba.',
  },
  {
    id: 'projects-shortcuts-implementation-profile-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'fix',
    title:
      'Projetos: atalhos de Módulos e Tarefas para o perfil de implantação',
    description:
      'Quem tem o perfil de acesso de implantação clicava em Tarefas (ou Módulos) na tela de Projetos e caía em outra tela, porque elas só abriam para administradores. Agora esse perfil abre as duas telas e pode personalizar os Módulos e as Tarefas.',
  },
  {
    id: 'clearable-date-fields-2026-11-23',
    date: '23 de novembro de 2026',
    isoDate: '2026-11-23',
    type: 'improvement',
    platform: 'web',
    title: 'Campos de data com (x) para limpar',
    description:
      'Os campos de data dos filtros agora têm um (x) ao lado para apagar a data com um clique, sem precisar selecionar e apagar na mão. Vale para a Busca detalhada e as ações em lote da Gestão avançada de tickets, os relatórios de tickets, o SAC e as Sugestões.',
  },
  {
    id: 'integration-api-niches-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'feature',
    title: 'API de Integração: Nicho e Sub-nicho de empresas e agentes',
    description:
      'A consulta de empresas da API passa a trazer o Nicho e o Sub-nicho de cada empresa, e a consulta de usuários traz os Nichos e Sub-nichos que cada agente atende. Dá para cruzar os dois e filtrar por niche_id e sub_niche_id para descobrir quem deve ser o responsável por um ticket.',
  },
  {
    id: 'filter-unassigned-tickets-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'feature',
    title: 'Filtro "Sem responsável" nos tickets',
    description:
      'No filtro de agentes do Kanban, do Backlog e do Sprint ativo, há uma nova opção Sem responsável, que mostra só os tickets que ninguém assumiu. Ela pode ser usada sozinha ou junto de agentes, e fica lembrada por Mesa.',
  },
  {
    id: 'agent-niches-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'feature',
    title: 'Nichos e sub-nichos por agente',
    description:
      'Em Configurações > Nichos por agente, cada analista passa a ter a lista de nichos e sub-nichos de empresa que atende, e dá para editar e buscar por agente ou por nicho. Os cinco analistas já vêm cadastrados e os nichos que faltavam foram criados. Por enquanto é só cadastro e consulta, nada muda sozinho nas empresas.',
  },
  {
    id: 'proposal-send-email-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'feature',
    title: 'Enviar a proposta de melhoria por e-mail ao criá-la',
    description:
      'Na aba Valorização, a nova proposta tem uma caixinha para enviar ou não a proposta por e-mail ao solicitante, com o PDF em anexo. A caixinha vem marcada, e a proposta mostra quando e para qual e-mail foi enviada. Sem e-mail do solicitante, a caixinha fica desligada.',
  },
  {
    id: 'estimated-hours-regular-tickets-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'feature',
    title: 'Horas estimadas nos tickets e na mensagem ao cliente',
    description:
      'Os tickets das Mesas comuns ganharam o campo Horas estimadas nas propriedades (é o mesmo campo da Estimativa original do Desenvolvimento). Nas Mensagens ao cliente existe a nova variável {{horas}}, trocada pelo número de horas do ticket no envio.',
  },
  {
    id: 'new-ticket-followers-chips-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'improvement',
    title: 'Remover seguidores ao abrir um ticket ficou direto',
    description:
      'No Novo ticket, cada seguidor agora aparece como uma etiqueta com um x para remover na hora, e há o botão Limpar para tirar todos de uma vez. Antes era preciso reabrir a lista e desmarcar o nome.',
  },
  {
    id: 'tabs-middle-click-close-2026-11-19',
    date: '19 de novembro de 2026',
    isoDate: '2026-11-19',
    platform: 'web',
    type: 'improvement',
    title: 'Fechar aba com o botão do meio do mouse',
    description:
      'Nas abas do topo da tela, clicar com o botão do meio (a rodinha) do mouse agora fecha a aba, como no navegador. Vale também para a lista de abas do botão +.',
  },
  {
    id: 'published-forms-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    platform: 'web',
    type: 'feature',
    title: 'Formulários publicados na Central de Ajuda, para clientes e equipe',
    description:
      'Ao publicar um formulário e vinculá-lo a um artigo, ele aparece na Central de Ajuda com o botão Preencher, e o cliente completa o passo a passo sem sair do artigo. Em cada formulário você escolhe se só o cliente logado preenche ou se o link é aberto, define a mensagem de depois do envio e copia os links. As respostas ficam guardadas na lista do formulário, sem criar chamado, e mostram quem respondeu e de onde veio. A equipe também preenche direto do artigo no painel, com o número do chamado opcional.',
  },
  {
    id: 'knowledge-base-tree-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    platform: 'web',
    type: 'feature',
    title: 'Base de Conhecimento em árvore: pastas, subartigos e referências',
    description:
      'A tela de Artigos agora mostra a estrutura em árvore, com pastas, subpastas e subartigos que abrem e recolhem. Ao escolher um artigo, o conteúdo aparece no centro e os detalhes, a estrutura e os formulários vinculados ficam ao lado. Dá para arrastar para reorganizar (ou usar Mover para...), inserir no texto links para outros artigos e formulários, e consultar ou preencher o formulário direto do artigo. A busca continua a mesma e a lista de antes está no botão Lista.',
  },
  {
    id: 'integration-api-companies-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    platform: 'web',
    type: 'feature',
    title:
      'API de Integração: consulta de empresas e movimento para estágios com regras',
    description:
      'A API passa a ter a consulta de empresas (por nome, CNPJ ou código), já com o Nível da empresa, e a Estimativa original (horas) do ticket pode ser consultada e alterada. Ao mover um ticket pela API, o responsável, o prazo e o agendamento enviados na mesma chamada valem para os estágios que os exigem, e a lista de Mesas mostra o que cada estágio exige.',
  },
  {
    id: 'chat-detail-report-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title: 'Novo relatório: Chat detalhado',
    description:
      'Em Relatórios, o novo "Chat detalhado" lista cada chat em uma linha (cliente, origem, quem iniciou, quando foi assumido, espera, duração, responsável, grupo, departamento, status, telefone, avaliação, catálogo e ticket vinculado), com o resumo do período (chats atendidos, cancelados, tickets vinculados, média de atendimento e de espera, tempo total). Dá para filtrar por período, responsável, grupo, origem e status, e exportar para Excel com as abas Chat Detalhado e Resumo.',
  },
  {
    id: 'ticket-export-full-excel-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'improvement',
    platform: 'web',
    title: 'Exportação para Excel com todos os dados do ticket',
    description:
      'Na Busca detalhada, a exportação para Excel agora traz todos os dados do ticket em colunas próprias: descrição, observação, resolução, empresa (com razão social, CNPJ e nível), solicitante, todos os responsáveis, pai e filhos, impedimento, datas, SLA, campos do desenvolvimento, e o resumo de anexos, comunicações, comentários, apontamentos, checklist, compromissos e histórico. O que não estiver preenchido fica vazio. O PDF continua com o resumo.',
  },
  {
    id: 'impediment-parent-child-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title:
      'Impedimento do ticket filho sobe para o pai (e a resolução fica registrada)',
    description:
      'Ao registrar um impedimento num ticket filho, o ticket pai também fica impedido (com a indicação do filho de origem). Ao retirar o impedimento do filho, o do pai sai junto, a menos que outro filho continue impedido. Ao retirar, dá para informar a resolução do impedimento (opcional): ela fica nos comentários e no histórico do filho e do pai.',
  },
  {
    id: 'ticket-observation-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title: 'Observação no ticket (e na API)',
    description:
      'Os tickets das Mesas comuns ganharam o campo Observação, logo abaixo da Descrição, escrito no mesmo editor (formatação, modal grande) e com botão para remover. O cartão fica minimizado quando não há observação e aberto quando há (dá para abrir e fechar pelo título). Na API de Integração, a observação sai ao consultar o ticket (detalhe e lista) e pode ser inserida, alterada ou removida (enviando vazio ou null) ao criar ou alterar o ticket. As mudanças aparecem no Histórico.',
  },
  {
    id: 'client-push-tap-opens-ticket-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'fix',
    platform: 'mobile',
    title: 'App do cliente: tocar na notificação abre o chamado da resposta',
    description:
      'Ao tocar numa notificação push de resposta da equipe, o app agora abre direto o chamado em que houve a comunicação (e a notificação do Chat abre o Chat), esteja o app aberto, em segundo plano ou fechado. Antes o toque só abria o app onde ele estava.',
  },
  {
    id: 'api-company-level-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'improvement',
    platform: 'web',
    title: 'API de Integração: empresa do ticket e Nível da empresa',
    description:
      'Na API de Integração, criar ou atualizar um ticket aceita agora `company_id` (a empresa do ticket) e `company_classification_level` (o Nível da empresa, de 1 a 5). Nas respostas, o ticket traz o Nível da empresa (`company.classification_level` no detalhe e `company_classification_level` na lista). O Nível é um campo da empresa, então vale para todos os tickets dela.',
  },
  {
    id: 'kanban-child-completed-badge-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title: 'Kanban: selo "Filho concluído" no ticket pai',
    description:
      'Quando um ticket filho de uma Mesa de desenvolvimento é concluído, o cartão do ticket pai no Kanban ganha o selo verde "Filho concluído", ao vivo e para todo mundo que acompanha o quadro. Clique no selo para marcar como visto e tirá-lo do cartão.',
  },
  {
    id: 'child-ticket-completed-notice-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title:
      'Aviso ao ticket pai quando o ticket filho de desenvolvimento é concluído',
    description:
      'Quando um ticket filho de uma Mesa com o módulo de desenvolvimento é concluído (status finalizado), o responsável pelo ticket pai recebe uma notificação que abre o pai, e o Histórico do pai ganha uma nota com o número e o título do filho. A notificação pode ser desligada em Configurações do perfil > Notificações.',
  },
  {
    id: 'client-announcements-board-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title: 'Mural de Avisos no Portal do Cliente',
    description:
      'Em Configurações > Avisos do Portal (só administrador), publique comunicados para os clientes: título, texto, tipo (informativo, atenção, novidade ou urgente), período, link opcional e público. O público pode ser todos os clientes ou só quem combina com Empresa, Nicho, Subnicho e Nível. Dentro do período, o aviso aparece na tela Principal do Portal e abre em uma janela a cada login, que o cliente precisa fechar antes de continuar.',
  },
  {
    id: 'company-niche-select-and-subniche-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'fix',
    platform: 'web',
    title: 'Empresa: seletor de Nicho voltou a funcionar e Subnicho na tela',
    description:
      'Na tela da Empresa, a lista de Nicho aparecia sempre vazia e o botão de adicionar um Nicho novo não funcionava. Corrigido. A tela da Empresa também ganhou o campo Subnicho, que funciona como o Nicho: escolha um existente ou crie um novo na hora.',
  },
  {
    id: 'dua-playground-image-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'feature',
    platform: 'web',
    title: 'Dua: anexe imagens no Playground para testar',
    description:
      'No teste do assistente (Playground), o botão de anexar permite enviar até 3 imagens por mensagem, de até 6 MB cada. A Dua enxerga a imagem de verdade na resposta, como acontece com o cliente no Portal e no WhatsApp.',
  },
  {
    id: 'client-push-company-viewers-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'fix',
    platform: 'mobile',
    title:
      'App do cliente: notificação push chega a quem vê o chamado pela empresa',
    description:
      'A resposta da equipe num chamado só gerava notificação push (fora do app) para o solicitante do ticket, enquanto o aviso dentro do app aparecia para todos que enxergam os chamados da empresa. Agora o push chega também a esses contatos. Além disso, o botão "Ver" do aviso dentro do app passa a abrir o chamado antes de qualquer outra ação.',
  },
  {
    id: 'communication-automation-label-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'fix',
    platform: 'web',
    title: 'Comunicações automáticas aparecem como "Mensagem de automação"',
    description:
      'Na lista de comunicações enviadas ao cliente, as mensagens disparadas por automação (Estágio ou troca de Mesa) mostravam "null" no lugar de quem enviou. Agora aparece "Mensagem de automação".',
  },
  {
    id: 'api-stage-automation-2026-11-18',
    date: '18 de novembro de 2026',
    isoDate: '2026-11-18',
    type: 'fix',
    platform: 'web',
    title: 'API: mudar o Estágio do ticket agora roda a automação do Estágio',
    description:
      'Ao alterar o Estágio de um ticket pela API (por exemplo, para Finalizado na Mesa Desenvolvimento), a automação configurada nesse Estágio, como mudar o status do ticket, não era executada. Agora ela roda, o mesmo valendo para as mensagens automáticas ao cliente e para a transferência feita pela tela de fechamento.',
  },
  {
    id: 'dua-portal-triage-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'feature',
    platform: 'web',
    title: 'Dua faz a triagem no chat do Portal do Cliente',
    description:
      'No chat do Portal do Cliente, a Dua agora pode abrir o chamado direto no Kanban, já com Mesa, Estágio, Categoria e Prioridade definidos pela conversa, como se um atendente tivesse criado o ticket, sem passar pela fila de Triagem. A Dua também pode consultar o DueRules (somente leitura) para entender termos e telas do sistema, sem tentar resolver o problema.',
  },
  {
    id: 'company-niche-import-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'feature',
    platform: 'web',
    title: 'Importar Nicho, Subnicho, Nível e Especialista por planilha',
    description:
      'Em Configurações > Dados > Planilhas há uma nova importação de Empresa com as colunas CNPJ, Nicho, Subnicho, Nível (1 a 5) e Especialista. A empresa é encontrada somente pelo CNPJ e só é atualizada, nunca criada. Nicho e Subnicho que ainda não existem são criados na hora, e um Especialista não encontrado não impede o resto da linha de ser salvo (aparece nos registros ignorados).',
  },
  {
    id: 'ticket-customer-notices-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'feature',
    platform: 'web',
    title: 'Mensagens automáticas ao cliente por Estágio e por Mesa',
    description:
      'Em Configurações > Tickets > Mensagens ao cliente, crie mensagens que o DSConnect envia sozinho ao solicitante quando o ticket entra em um Estágio (ex.: melhoria aprovada para desenvolvimento, finalizado) ou passa de uma Mesa para outra. O texto aceita variáveis como o número do ticket, o cliente e o Estágio atual, e cada mensagem pode ser ativada, desativada ou só registrada no chamado, sem e-mail.',
  },
  {
    id: 'catalog-select-wide-menu-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'improvement',
    platform: 'web',
    title: 'Catálogo de Serviços: nomes completos na lista',
    description:
      'Ao classificar o ticket (Área e Item do Catálogo), a lista de opções agora é mais larga e os nomes longos aparecem inteiros, em mais de uma linha se precisar, em vez de cortados com "...".',
  },
  {
    id: 'close-ticket-communication-already-sent-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'fix',
    platform: 'web',
    title: 'Fechar ticket não pede comunicação se o cliente já foi avisado',
    description:
      'Se já foi enviada (ou registrada) uma comunicação ao cliente diretamente no ticket, o fechamento não exige mais a comunicação de encerramento. Antes, só valia a mensagem enviada pela própria etapa de fechamento. Respostas do cliente não contam.',
  },
  {
    id: 'ticket-search-contact-by-company-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'improvement',
    platform: 'web',
    title: 'Busca detalhada: solicitante conforme a empresa',
    description:
      'Na busca detalhada de tickets, o filtro de Solicitante/Contato agora é liberado ao escolher uma ou mais empresas e mostra apenas os solicitantes dessas empresas. Ao tirar uma empresa do filtro, os solicitantes dela saem junto.',
  },
  {
    id: 'project-schedule-description-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'fix',
    platform: 'web',
    title: 'Cronograma do projeto: descrição do novo ticket',
    description:
      'Ao criar um cronograma com "Novo ticket", agora há um campo de descrição. Antes o ticket era criado sem descrição e o agendamento falhava com a mensagem "Description can be blank" (descrição em branco).',
  },
  {
    id: 'agenda-color-profile-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'feature',
    platform: 'web',
    title: 'Escolha a sua cor na Agenda',
    description:
      'Em Configurações do perfil, na nova seção "Cor na agenda", cada pessoa escolhe a cor que a identifica: os eventos criados por você e o ponto ao lado do seu nome na Agenda passam a aparecer nessa cor para todos. Quem não escolher continua com a cor automática.',
  },
  {
    id: 'ticket-search-remove-chips-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'improvement',
    platform: 'web',
    title: 'Busca detalhada: remover empresas e solicitantes um a um',
    description:
      'Ao filtrar por várias empresas (ou solicitantes) na busca detalhada de tickets, cada uma aparece agora como uma etiqueta com um "x". Clique no "x" para tirar só aquela do filtro, sem precisar limpar todas.',
  },
  {
    id: 'ticket-long-description-fix-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'fix',
    platform: 'web',
    title: 'Corrigido erro ao editar descrições grandes do ticket',
    description:
      'Editar a descrição de um ticket com mais de 255 caracteres falhava com a mensagem "Previous value is too long (maximum is 255 characters)". O histórico do ticket guardava o antes e o depois com um limite curto demais; agora aceita os textos longos e a edição salva normalmente. O mesmo vale para motivos de impedimento e notas de automação grandes.',
  },
  {
    id: 'ticket-description-modal-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'improvement',
    platform: 'web',
    title: 'Editar a descrição do ticket agora abre um modal grande',
    description:
      'Ao clicar em Editar na descrição do ticket, a edição abre num modal com muito mais área visível (antes eram só umas três linhas) e com a fonte menor, para caber mais texto de uma vez. Cancelar, Salvar e Resumir conversa continuam no mesmo lugar, agora no rodapé do modal.',
  },
  {
    id: 'reply-box-auto-grow-2026-11-17',
    date: '17 de novembro de 2026',
    isoDate: '2026-11-17',
    type: 'fix',
    platform: 'web',
    title:
      'Caixa de resposta da conversa agora começa pequena e cresce com o texto',
    description:
      'A caixa de escrever a mensagem ficava sempre alta (cerca de 120 px) mesmo vazia, tomando espaço da conversa. Agora ela começa com duas linhas e vai aumentando sozinha conforme você escreve, até um limite; passando dele, rola por dentro. A alça de arrastar continua funcionando e o tamanho que você puxar é respeitado.',
  },
  {
    id: 'client-tutorials-collapsed-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'improvement',
    platform: 'web',
    title:
      'Tutoriais da Área do Cliente: vídeos recolhidos que expandem ao clicar',
    description:
      'Dentro de cada módulo, os vídeos agora aparecem recolhidos, só com o título, e expandem ao clicar (dá para abrir mais de um). Cabem muito mais itens na tela, e o vídeo só é carregado quando a pessoa abre.',
  },
  {
    id: 'stage-reorder-fast-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'fix',
    platform: 'web',
    title: 'Reordenar os Estágios de uma Mesa deixou de travar',
    description:
      'Arrastar os Estágios para mudar a ordem podia levar cerca de 14 segundos e até falhar com erro. A tela refazia o quadro inteiro consultando o servidor ticket por ticket; agora usa a mesma carga otimizada da tela do Kanban e responde quase de imediato.',
  },
  {
    id: 'less-polling-faster-server-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'improvement',
    platform: 'web',
    title: 'DSConnect mais rápido: menos buscas repetidas ao servidor',
    description:
      'O sistema refazia a busca das conversas atribuídas a você, dos contadores de não lidas e dos totais das abas a cada evento, o que sobrecarregava o servidor e deixava as telas lentas. Agora essas buscas são agrupadas (no máximo uma a cada 10 a 15 segundos por navegador). Os avisos continuam acendendo na hora ao chegar uma mensagem ou ao abrir uma conversa; só a confirmação do servidor é que passou a vir um pouco depois.',
  },
  {
    id: 'backlog-total-hours-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'feature',
    platform: 'web',
    title: 'Total de horas estimadas no Backlog e nos Sprints',
    description:
      'No cabeçalho do Backlog e de cada Sprint agora aparece "Total: Xh", a soma das horas estimadas dos tickets exibidos. A soma acompanha os filtros (agente, Categoria, Prioridade, Estágio e busca): ao filtrar, o total muda na hora. Ticket sem estimativa conta como zero.',
  },
  {
    id: 'mood-checkin-permission-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'feature',
    platform: 'web',
    title:
      'Permissão para ver o Humor da equipe, e o relatório abre no dia de hoje',
    description:
      'Agora existe a permissão "Ver o relatório Humor da equipe" nas funções personalizadas, para liberar o relatório aos gestores; administradores continuam vendo sempre. Quem tem só essa permissão enxerga, em Relatórios, apenas o card do Humor da equipe. Ao abrir o relatório, ele já vem filtrado no dia de hoje (de hoje até hoje).',
  },
  {
    id: 'backlog-category-filter-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'feature',
    platform: 'web',
    title: 'Filtro por Categoria no Backlog e no Sprint ativo',
    description:
      'Na tela de Backlog agora há o filtro "Todas Categorias", ao lado dos filtros de Prioridade e Estágio. Ele vale para a lista do Backlog, para os Sprints e para o quadro do Sprint ativo, e mostra as categorias da Mesa escolhida.',
  },
  {
    id: 'push-brave-message-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'fix',
    platform: 'web',
    title: 'Aviso de notificações em português, com a dica para o Brave',
    description:
      'Quando não dá para ativar as notificações neste navegador, o aviso agora vem em português e explica o caminho no Brave (brave://settings/privacy, "Usar o Google Services para mensagens push"). Ao abrir o sistema, o re-registro automático das notificações não mostra mais aviso nenhum.',
  },
  {
    id: 'kanban-ctrl-click-new-tab-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'feature',
    platform: 'web',
    title: 'Ctrl + clique no card abre o ticket numa aba interna',
    description:
      'Nos quadros Kanban (Tickets e Backlog), segurar Ctrl (ou Cmd no Mac) e clicar num card adiciona o ticket à barra de abas do DSConnect sem sair do quadro, para ler depois. O clique normal continua abrindo o ticket na tela.',
  },
  {
    id: 'manifestation-delete-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'feature',
    platform: 'web',
    title: 'Excluir SAC pelo detalhe da manifestação',
    description:
      'Administradores agora têm o botão "Excluir SAC" na tela de detalhe da manifestação. Ele pergunta antes de apagar e leva junto as mensagens, o histórico e os anexos; se o SAC virou ticket ou sugestão, esse registro continua existindo. Quem não é administrador não vê o botão.',
  },
  {
    id: 'internal-chat-loads-complete-2026-11-16',
    date: '16 de novembro de 2026',
    isoDate: '2026-11-16',
    type: 'improvement',
    platform: 'web',
    title: 'Chat interno abre já completo e mais rápido',
    description:
      'Ao abrir o Chat interno, uma tela de carregamento fica por cima até as conversas, as mensagens da primeira conversa e as fotos estarem prontas — antes a tela abria vazia, sem fotos e sem mensagens, e ia se preenchendo. Também ficou mais rápido: os agentes e as conversas agora são buscados ao mesmo tempo, e as mensagens fixadas junto com o histórico.',
  },
  {
    id: 'reply-box-auto-grow-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'design',
    platform: 'web',
    title: 'Caixa de mensagem da conversa começa menor e cresce com o texto',
    description:
      'A caixa de escrever a resposta numa conversa agora começa com uma linha só, sobrando mais espaço para ler a conversa, e vai aumentando conforme você digita, até um limite. Passando dele, a caixa rola por dentro.',
  },
  {
    id: 'internal-chat-keeps-clicked-room-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'fix',
    platform: 'web',
    title: 'Chat interno não volta mais para a primeira conversa',
    description:
      'Ao entrar no Chat interno e clicar numa conversa antes da tela terminar de carregar, o sistema voltava para a primeira conversa da lista e a mensagem seguinte podia ser enviada para a pessoa errada. Agora a conversa que você clicou é mantida.',
  },
  {
    id: 'client-tutorial-modules-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'feature',
    platform: 'web',
    title: 'Tutoriais do Portal agrupados em módulos',
    description:
      'Na aba Tutoriais da Área do Cliente, os vídeos agora ficam em módulos (ex.: DS Connect, DS Comercial): cada módulo é um card (com o logo que você enviar) e, ao clicar, abre os vídeos dele. Os módulos são criados e ordenados em Configurações > Tutoriais do Portal (agora um item próprio do menu, logo abaixo de Caixas de entrada), e cada tutorial escolhe o seu módulo. Vídeo sem módulo aparece no card "Geral".',
  },
  {
    id: 'client-tutorials-admin-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'feature',
    platform: 'web',
    title: 'Tutoriais do Portal editáveis em Configurações',
    description:
      'Nova tela em Configurações > Tutoriais do Portal: o administrador cadastra título, descrição e vídeo (link do YouTube/Vimeo ou arquivo MP4 enviado direto pela tela) dos tutoriais que o cliente vê na aba Tutoriais. Tudo é editável: trocar o vídeo, reordenar, ocultar sem apagar e excluir.',
  },
  {
    id: 'client-push-hardening-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'fix',
    platform: 'web',
    title: 'Notificações do cliente mais confiáveis',
    description:
      'Revisamos as notificações da Área do Cliente: a segunda mensagem da mesma conversa agora também aparece no sistema (antes substituía a anterior sem avisar), uma inscrição antiga de outra chave é refeita sozinha, o app instalado confere a inscrição ao voltar para a janela e as falhas de envio passam a ficar registradas.',
  },
  {
    id: 'client-push-toggle-and-tutorials-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'feature',
    platform: 'web',
    title: 'Área do Cliente: botão de notificações e aba Tutoriais',
    description:
      'No cabeçalho da Área do Cliente (web) agora há um botão para ativar ou desativar as notificações do navegador: ao ativar, o navegador mostra o aviso de permissão; ao desativar, este navegador deixa de receber. Se estiver bloqueado, o aviso leva ao tutorial. Também foi criada a aba Tutoriais, com o passo a passo de ativação e espaço para o vídeo (definido em tutorialsData.js).',
  },
  {
    id: 'paused-counter-and-no-duplicate-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'fix',
    platform: 'web',
    title:
      'Pausadas: contador "Minhas" correto e aviso ao iniciar conversa com cliente pausado',
    description:
      'Na aba Pausadas, o contador "Minhas" mostrava 0 mesmo com conversas suas listadas; agora conta as mesmas conversas da lista. Além disso, ao iniciar uma conversa com um cliente que está pausado por inatividade, o DSConnect agora avisa (com o link da conversa pausada) em vez de abrir uma segunda, que também acabava pausada e deixava o mesmo cliente duas vezes em Pausadas. Para retomar, abra a conversa pausada e use Reabrir.',
  },
  {
    id: 'internal-chat-drag-drop-files-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'feature',
    platform: 'web',
    title: 'Chat interno: arraste e solte arquivos na conversa',
    description:
      'Agora dá para arrastar um ou mais arquivos do computador e soltar em qualquer ponto da conversa do chat interno, como no Discord, sem precisar copiar e colar. Eles entram como anexos da mensagem, com os mesmos limites de tamanho (25 MB) e quantidade (10) de sempre. Em canais somente leitura o arraste não faz nada.',
  },
  {
    id: 'whatsapp-expxwhats-provider-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'feature',
    platform: 'web',
    title: 'Novo provedor de WhatsApp: ExpxWhats (servidor próprio)',
    description:
      'Ao criar uma caixa de entrada de WhatsApp, agora é possível conectar via ExpxWhats - um servidor próprio da empresa, sem depender de um serviço de terceiros. Veja a documentação completa de instalação, pareamento do número e cuidados para reduzir o risco de bloqueio.',
  },
  {
    id: 'distribute-conversations-isolated-failures-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'fix',
    platform: 'web',
    title: 'Distribuir conversas: uma falha não trava mais as outras',
    description:
      'No botão "Distribuir conversas" (administradores), uma conversa com algum problema travava a distribuição de todas as outras e só aparecia um erro genérico, sem motivo. Agora cada conversa é processada separadamente: se uma falhar, ela aparece na lista de "não distribuídas" com o motivo, e as demais são distribuídas normalmente.',
  },
  {
    id: 'agent-filter-facepile-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'design',
    platform: 'web',
    title: 'Filtro de agentes: avatares mais juntos',
    description:
      'Os avatares do filtro de agentes (Kanban, Backlog e Sprint ativo) agora ficam sobrepostos, como uma pilha de rostos, em vez de bem espaçados. Cabem mais agentes na linha, o agente filtrado sobe por cima com o anel azul e passar o mouse mostra o nome.',
  },
  {
    id: 'sprint-board-toolbar-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'design',
    platform: 'web',
    title: 'Sprint ativo: barra de filtros em uma linha só',
    description:
      'No Sprint ativo, o seletor de Sprint, os agentes, a busca, os filtros de prioridade e estágio e os botões "Concluir sprint" e tamanho dos cards agora ficam agrupados na mesma linha, em vez de um embaixo do outro. Só quebra de linha se a tela for realmente estreita.',
  },
  {
    id: 'backlog-drag-no-reload-2026-11-13',
    date: '13 de novembro de 2026',
    isoDate: '2026-11-13',
    type: 'improvement',
    platform: 'web',
    title: 'Backlog: arrastar ticket para o Sprint sem recarregar a tela',
    description:
      'Ao arrastar um ticket do Backlog para um Sprint (ou entre Sprints), ele agora vai direto para o destino sem recarregar a lista: os Sprints que você deixou abertos ou fechados continuam como estavam e a tela não pisca. Se o servidor recusar a mudança, o ticket volta ao lugar de antes e aparece o aviso. O mesmo vale para trocar o estágio pelo seletor da linha.',
  },
  {
    id: 'kanban-compact-density-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'improvement',
    platform: 'web',
    title: 'Kanban de tickets: modo compacto para telas pequenas',
    description:
      'Em monitores menores (como 1280x800) o Kanban agora usa colunas mais estreitas (224 px) e cards bem enxutos, para caberem vários tickets na tela: título menor, prioridade, prazo, conversas e responsável numa linha só, e o cabeçalho da página mais baixo. O mesmo vale para o quadro do Sprint ativo (Backlog), com o mesmo botão e a mesma escolha. A fila de agentes do topo também não quebra mais em várias linhas: mostra só os avatares que cabem e manda o resto para o "+N". O modo compacto entra sozinho conforme a tela e, no botão ao lado da ordenação, você escolhe entre "Cards compactos" e "Cards confortáveis" (a escolha fica salva).',
  },
  {
    id: 'resolve-conversation-summarize-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'feature',
    platform: 'web',
    title: 'Resolver conversa: botão "Resumir conversa com IA"',
    description:
      'Ao clicar em Resolver numa conversa com ticket aberto, a tela de fechar o ticket ganhou o botão "Resumir conversa com IA" logo abaixo da descrição. Ele faz o mesmo resumo da tela do ticket e já preenche a descrição e o título; você pode editar os dois antes de fechar.',
  },
  {
    id: 'help-center-import-markdown-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'feature',
    platform: 'web',
    title: 'Central de Ajuda: importar manuais em Markdown (.md)',
    description:
      'Na lista de artigos da Central de Ajuda há o botão "Importar .md". Escolha um ou vários arquivos, e cada um vira um artigo em rascunho no idioma que você está vendo, com a categoria que escolher. O título vem do cabeçalho "title:" ou do primeiro "# Título" do arquivo, ou do nome do arquivo. Imagens do manual também entram: escolha as imagens junto com os .md e elas são enviadas e ligadas ao texto pelo nome do arquivo. Revise e publique depois.',
  },
  {
    id: 'kanban-agent-filter-persist-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'fix',
    platform: 'web',
    title: 'Kanban: o filtro de agente não se perde mais ao trocar de aba',
    description:
      'O agente selecionado no filtro do Kanban agora é lembrado por Mesa. Ao ir para outra aba, como o Chat interno, e voltar, o filtro continua aplicado. Para ver todos de novo, basta limpar o filtro.',
  },
  {
    id: 'stage-delete-only-open-block-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'fix',
    platform: 'web',
    title: 'Estágios: só tickets abertos contam e travam a exclusão',
    description:
      'Na tela de Estágios, a coluna Tickets agora conta só os tickets abertos, o mesmo que o Kanban mostra. Tickets resolvidos, encerrados e cancelados não contam mais e, ao excluir o estágio, são movidos para o estágio Finalizado da Mesa.',
  },
  {
    id: 'project-create-schedule-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'feature',
    platform: 'web',
    title: 'Projetos: botão "Criar cronograma"',
    description:
      'No detalhe de um Projeto, o botão "Criar cronograma" abre uma tela para vincular tickets (já existentes no projeto ou novos) a uma data/horário e a um responsável. Ao salvar, a data é gravada no ticket e um compromisso é criado na Agenda do responsável, já vinculado ao ticket.',
  },
  {
    id: 'conversations-agent-filter-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'feature',
    platform: 'web',
    title: 'Novo filtro por agente nas conversas',
    description:
      'O menu de filtros rápidos da lista de conversas (ao lado do filtro de período) agora tem um filtro por agente responsável, para ver rapidamente as conversas de uma pessoa específica sem precisar abrir os filtros avançados.',
  },
  {
    id: 'distribute-conversations-button-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'feature',
    platform: 'web',
    title: 'Botão "Distribuir conversas" para administradores',
    description:
      'Na aba "Todas" das conversas, administradores agora têm o botão "Distribuir conversas", que força a distribuição automática das conversas em fila que ainda estão sem atendente. Quando alguma não pode ser distribuída, mostra o motivo de cada agente (offline, na exceção de distribuição, etc).',
  },
  {
    id: 'date-filter-alignment-fix-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'fix',
    platform: 'web',
    title: 'Filtros de data: alinhamento corrigido',
    description:
      'Os campos "De" e "Até" em telas como o Quadro de Sugestões e o SAC e Sugestões apareciam mais para cima que os demais filtros ao lado. Agora ficam alinhados corretamente com os outros campos da mesma linha.',
  },
  {
    id: 'stage-delete-closed-tickets-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'fix',
    platform: 'web',
    title: 'Estágios: tickets encerrados também não travam a exclusão',
    description:
      'Ao excluir um estágio, os tickets encerrados que estavam nele, além dos cancelados, são movidos para o estágio Finalizado da Mesa e não impedem mais a exclusão. Continuam impedindo apenas os abertos, resolvidos ou em triagem, e a contagem da tela de Estágios mostra exatamente esses.',
  },
  {
    id: 'ticket-close-moves-to-finalized-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'improvement',
    platform: 'web',
    title: 'Encerrar ou cancelar leva o ticket para o estágio Finalizado',
    description:
      'Ao encerrar ou cancelar um ticket, ele agora vai para o estágio Finalizado da Mesa, e o estágio de onde saiu fica registrado no Histórico. Ao reabrir, o ticket volta para esse estágio. Tickets antigos, sem estágio anterior no Histórico, continuam onde estão ao serem reabertos. Resolver não muda o estágio.',
  },
  {
    id: 'triage-cancelled-stuck-2026-11-12',
    date: '12 de novembro de 2026',
    isoDate: '2026-11-12',
    type: 'fix',
    platform: 'web',
    title: 'Triagem: ticket cancelado não fica mais preso na fila',
    description:
      'Um ticket cancelado, encerrado ou resolvido que ainda estava na Triagem continuava na fila e no contador do menu, sem como aprovar ou cancelar de novo. Agora qualquer ticket que deixa de estar aberto sai da fila sozinho, e os que já estavam presos foram liberados.',
  },
  {
    id: 'child-ticket-copy-files-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'fix',
    platform: 'web',
    title: 'Ticket filho: copiar os arquivos não dá mais erro',
    description:
      'Ao criar um ticket filho com a opção de copiar os arquivos do ticket pai, o ticket era criado, mas a tela mostrava "Não foi possível salvar o ticket" e ele só aparecia depois de recarregar a página. Os arquivos agora são copiados corretamente e o ticket abre normalmente.',
  },
  {
    id: 'stage-ticket-count-all-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'fix',
    platform: 'web',
    title: 'Estágios: tickets cancelados não travam mais a exclusão',
    description:
      'Ao excluir um estágio, os tickets cancelados que estavam nele não impedem mais a exclusão: eles são movidos para o estágio Finalizado da Mesa. Continuam impedindo apenas os tickets abertos, resolvidos, encerrados ou em triagem. A coluna Tickets em Configurações > Tickets > Estágios agora conta exatamente esses, e o botão de excluir já aparece bloqueado com a explicação quando houver algum.',
  },
  {
    id: 'ticket-title-module-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'Novo ticket: escolher o módulo ao lado do título',
    description:
      'Ao criar um ticket, um seletor ao lado do título lista os módulos do Catálogo de Serviços (DS Comercial, etc.) e coloca o escolhido no começo do título, no formato [DS Comercial] ERRO AO GERAR NOTAS EM LOTE. O seletor é pesquisável e também aparece ao editar o título de um ticket já criado. Trocar o módulo substitui o anterior, e "Sem módulo" o retira.',
  },
  {
    id: 'unread-alert-confirm-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'fix',
    platform: 'web',
    title: 'Aviso "!": só para as suas conversas',
    description:
      'O aviso "!" estava olhando as conversas abertas de todo mundo, e não só as suas: o filtro "Minhas" não chegava ao servidor, então uma mensagem de cliente na fila acendia o aviso. Agora ele considera apenas as conversas atribuídas a você e é conferido com o servidor logo depois de aparecer em tempo real.',
  },
  {
    id: 'internal-chat-image-viewer-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'Chat interno: imagens com zoom, arrastar e girar',
    description:
      'As imagens do chat interno agora abrem no mesmo visualizador das imagens do ticket: dá para ampliar com a roda do mouse, duplo clique ou botões, arrastar a imagem ampliada e girá-la para os lados. A imagem abre grande, ocupando quase toda a tela. Ao anexar uma imagem, clicar na miniatura também a abre ampliada antes de enviar.',
  },
  {
    id: 'time-entry-team-category-precision-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'Apontamento: categoria pela Mesa do ticket e tempos exatos',
    description:
      'No apontamento (cronômetro e lançamento manual), a categoria já vem preenchida pela Mesa em que o ticket está: Implantação ou Desenvolvimento. Também corrigimos os tempos: as horas passam a ser guardadas com mais precisão, então 1 minuto + 2 minutos dá 3 minutos no total, a lista mostra os segundos e a dica ao passar o mouse mostra o relógio exato (ex.: 00:02:00) em vez de horas decimais. Apontamentos antigos continuam como foram gravados.',
  },
  {
    id: 'pause-resume-any-message-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'fix',
    platform: 'web',
    title:
      'Pausa por inatividade: qualquer mensagem do cliente retoma a conversa',
    description:
      'Quando o cliente responde a uma conversa pausada por inatividade, ela agora volta para o atendente anterior (se estiver disponível) ou para a fila, seja qual for o texto enviado. Antes, com a opção "Qualquer mensagem retoma" desligada, um texto diferente de "sim" deixava a conversa escondida em Pausadas. Só responder "não" continua encerrando. A opção foi removida das configurações.',
  },
  {
    id: 'unread-alert-exclamation-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'feature',
    platform: 'web',
    title: 'Aviso (!) de mensagem não lida: abas, menu e navegador',
    description:
      'Quando chegar mensagem não lida numa conversa atribuída a você, ou no chat interno, aparece um "!" na aba do topo e no item do menu lateral, e a aba do navegador ganha "(!)" no título e o selo no ícone. O aviso some quando você lê a mensagem.',
  },
  {
    id: 'ticket-time-entry-timer-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'feature',
    platform: 'web',
    title: 'Ticket: cronômetro de apontamento de horas',
    description:
      'Na aba Apontamento do ticket, clique em Iniciar para começar a contar o tempo (horas, minutos e segundos). Dá para pausar, continuar e, ao finalizar, o tempo vira um apontamento na lista. O cronômetro não se perde se você fechar a página, e os apontamentos agora podem ser editados (horas e minutos) além de removidos.',
  },
  {
    id: 'chat-list-date-filter-inside-funnel-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'Conversas: filtro de data dentro do ícone de filtro',
    description:
      'Os campos de data saíram da tela da lista de conversas. Agora, ao clicar no ícone de filtro, o menu mostra o período (De e Até) e a opção "Filtrar conversas". Quando há um período ativo, aparece um pontinho no ícone.',
  },
  {
    id: 'duebot-answer-feedback-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'feature',
    platform: 'web',
    title: 'DueBot: avalie as respostas com 👍 ou 👎',
    description:
      'Abaixo de cada resposta do DueBot há agora os botões de polegar. Marque se a resposta ajudou ou, se não ajudou, diga o motivo e escreva um comentário. As avaliações ficam guardadas para a equipe analisar e melhorar o DueBot.',
  },
  {
    id: 'integration-api-jira-key-filter-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'API de Integração: buscar ticket pela key do Jira',
    description:
      'A lista de tickets da API de Integração ganhou o filtro jira_key (a key do card ligada na aba Desenvolvimento, como DM-3634). Ele devolve o ticket com os mesmos campos do filtro por número do chamado, sem diferenciar maiúscula de minúscula.',
  },
  {
    id: 'sidebar-favorite-menus-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'feature',
    platform: 'web',
    title: 'Menu lateral: favorite os menus que você mais usa',
    description:
      'Passe o mouse sobre um item do menu lateral e clique na estrela para fixá-lo no topo. Os favoritos ficam salvos no seu usuário e aparecem na mesma ordem em qualquer computador.',
  },
  {
    id: 'conversation-list-date-filter-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'feature',
    platform: 'web',
    title: 'Filtrar conversas e e-mails por data',
    description:
      'A listagem de conversas (e a de E-mails) ganhou dois campos de data - "De" e "Até" - fixos do lado do botão "Filtrar conversas", para filtrar só o que aconteceu num dia específico ou num período.',
  },
  {
    id: 'delete-email-fix-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'fix',
    platform: 'web',
    title: 'Excluir e-mail: botão corrigido',
    description:
      'A opção "Excluir e-mail" do menu de contexto não funcionava: além de exigir administrador, a caixa de confirmação do navegador simplesmente não abria em alguns ambientes. Trocamos pelo modal de confirmação próprio do DSConnect e liberamos a exclusão para qualquer atendente com acesso à caixa de E-mail.',
  },
  {
    id: 'chat-list-pending-to-paused-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'Listagem de conversas: "Pausadas" no lugar de "Pendentes"',
    description:
      'O filtro rápido "Pendentes" virou "Pausadas" na listagem de conversas, e a opção "Deixar pendente" saiu do menu de contexto - o dia a dia é abrir, pausar ou resolver.',
  },
  {
    id: 'chat-list-remove-sort-layout-buttons-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'improvement',
    platform: 'web',
    title: 'Listagem de conversas com menos botões',
    description:
      'Removemos os botões "Ordenar conversas" e "Alternar layout" do topo da listagem - podiam confundir mais do que ajudar.',
  },
  {
    id: 'suggestions-filters-alignment-fix-2026-11-11',
    date: '11 de novembro de 2026',
    isoDate: '2026-11-11',
    type: 'fix',
    platform: 'web',
    title: 'Sugestões e Melhorias: filtros com a mesma largura',
    description:
      'Os filtros de Prioridade, Categoria e Responsável estavam mais estreitos que os campos de data ao lado. Agora todos os filtros da tela ficam com a mesma largura.',
  },
  {
    id: 'company-tickets-order-display-id-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title: 'Empresa: tickets ordenados do mais novo para o mais antigo',
    description:
      'Na aba Tickets do cadastro da empresa, a lista agora vem ordenada pelo número do chamado, do maior para o menor, então o ticket mais recente aparece primeiro.',
  },
  {
    id: 'link-preview-description-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title: 'Link do DSConnect: nova descrição na pré-visualização',
    description:
      'Ao enviar o link do DSConnect em um chat, a pré-visualização agora mostra uma descrição em português (plataforma de organização de chamados e atendimento), em vez do texto genérico em inglês.',
  },
  {
    id: 'internal-chat-mark-unread-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'feature',
    platform: 'web',
    title: 'Chat interno: marcar como não lida para responder depois',
    description:
      'No Chat interno, clique com o botão direito na conversa (ou use o botão de envelope em uma mensagem) e escolha "Marcar como não lida". A conversa volta a aparecer no contador do menu lateral e nas notificações até você abri-la de novo.',
  },
  {
    id: 'ticket-copy-number-title-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title: 'Ticket: botão para copiar o número e o título',
    description:
      'Ao lado do título do ticket há um botão que copia o número e o título no formato "#35497 - Empresa | Solicitante | Título", pronto para colar onde precisar.',
  },
  {
    id: 'ticket-requester-opens-contact-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title: 'Ticket: o nome do solicitante abre o contato',
    description:
      'Dentro do ticket, clicar no nome do solicitante agora abre o cadastro do contato, do mesmo jeito que clicar no nome da empresa abre a empresa.',
  },
  {
    id: 'company-tickets-display-id-link-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title: 'Empresa: tickets mostram o número e abrem direto',
    description:
      'Na aba Tickets do cadastro da empresa, cada ticket agora mostra o número do chamado (como #35369) e, ao clicar, abre o próprio ticket em vez de levar para a lista.',
  },
  {
    id: 'conversation-list-search-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'feature',
    platform: 'web',
    title: 'Buscar conversa por nome do cliente ou da empresa',
    description:
      'A listagem de conversas ganhou um campo de busca: digite o nome do cliente ou da empresa para filtrar a lista na hora, sem precisar abrir cada conversa para achar.',
  },
  {
    id: 'queue-reopen-after-pause-no-autoassign-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'fix',
    platform: 'web',
    title:
      'Conversa pausada que estava numa Fila volta pra Fila, não pra um atendente',
    description:
      'Quando o cliente volta de uma pausa numa conversa que estava esperando numa Fila, ela volta pra Fila sem agente nenhum, em vez de ser atribuída sozinha pela distribuição automática.',
  },
  {
    id: 'autoassignment-exceptions-colocated-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title:
      'Exceção da distribuição automática agora fica junto do botão que liga/desliga',
    description:
      'As listas de agentes excluídos e o limite de conversas simultâneas por atendente saíram de uma tela separada e passaram a aparecer junto da própria habilitação da distribuição automática - em Colaboradores da caixa (WhatsApp) e em Automação (Portal do Cliente).',
  },
  {
    id: 'triage-summary-modal-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title: 'Triagem: resumo do chamado antes de abrir o ticket completo',
    description:
      'O botão "Abrir" na Triagem agora mostra um resumo do chamado (prioridade, solicitante, empresa, categoria sugerida e descrição) numa janela rápida, com as opções "Ver ticket completo" ou já "Abrir e encaminhar" direto dali.',
  },
  {
    id: 'auto-updater-menu-top-level-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'improvement',
    platform: 'web',
    title:
      '"Atualizador automático" agora é item próprio no menu, pra todo mundo',
    description:
      'O item "Atualizador automático" saiu de dentro de Configurações e passou a ser um item próprio no menu lateral, visível pra qualquer usuário.',
  },
  {
    id: 'delete-email-context-menu-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'feature',
    platform: 'web',
    title: 'Excluir e-mail direto pelo menu de contexto',
    description:
      'Nas conversas de E-mail, clicar com o botão direito num item da lista agora mostra a opção "Excluir e-mail", útil pra limpar spam sem precisar abrir a conversa.',
  },
  {
    id: 'filters-alignment-suggestions-sac-2026-11-10',
    date: '10 de novembro de 2026',
    isoDate: '2026-11-10',
    type: 'fix',
    platform: 'web',
    title:
      'Filtros de data alinhados em Sugestões e Melhorias e em SAC e Sugestões',
    description:
      'Os campos de data "De" e "Até" ficaram alinhados com os demais filtros (Prioridade, Categoria, Responsável) nas telas de Sugestões e Melhorias e de SAC e Sugestões.',
  },
  {
    id: 'integration-api-display-id-filter-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'improvement',
    platform: 'web',
    title: 'API de Integração: buscar ticket pelo número do chamado',
    description:
      'A lista de tickets da API de Integração ganhou o filtro display_id (o número do chamado que aparece na tela, como #35369), que acha o ticket sem depender da Mesa. Além disso, filtrar por um sprint que não existe agora responde 404 em vez de uma lista vazia.',
  },
  {
    id: 'portal-chat-send-failure-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'web',
    title:
      'Portal do Cliente: mensagens da equipe não ficam mais com "Falha ao enviar"',
    description:
      'Com uma URL de webhook inválida salva na caixa do Portal, toda resposta da equipe aparecia como "Falha ao enviar". O Portal agora entrega pelo próprio app e ignora essa URL.',
  },
  {
    id: 'portal-inbox-auto-assignment-toggle-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'web',
    title: 'Caixa do Portal: a atribuição automática não liga mais sozinha',
    description:
      'Quem desligava "Ativar atribuição automática de conversas" na caixa Portal do Cliente via o botão voltar a ficar ligado sozinho. Agora a escolha é respeitada; a distribuição do Portal continua controlada em Configurações > Tickets > Automação.',
  },
  {
    id: 'internal-chat-day-dividers-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'improvement',
    platform: 'web',
    title: 'Chat interno: linha com a data quando o dia muda',
    description:
      'Nas conversas do Chat interno, uma linha com a data por extenso (ex.: 9 de novembro de 2026) separa as mensagens de cada dia, como no Discord.',
  },
  {
    id: 'translation-missing-fix-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'web',
    title:
      'Notificações e atividades da conversa voltam a aparecer em português',
    description:
      'Notificações como "abriu a conversa" e os avisos de atribuição dentro da conversa apareciam como "Translation missing". Os textos foram restaurados.',
  },
  {
    id: 'image-viewer-pan-fix-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'web',
    title: 'Visualizador de imagens: arrastar a imagem ampliada funciona',
    description:
      'O arrasto da imagem ampliada era interrompido pelo próprio navegador (que tentava "puxar" a imagem como arquivo). Agora, com zoom, é só clicar e arrastar para ver a parte desejada.',
  },
  {
    id: 'open-conversation-portal-inbox-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'web',
    title: 'Ticket: "Abrir conversa" volta a achar as caixas do cliente',
    description:
      'No ticket, o botão "Abrir conversa" mostrava "Não há caixas de entrada disponíveis" mesmo para clientes do Portal. Agora a lista de caixas é buscada ao abrir o formulário, e o Portal do Cliente também fica disponível para atendentes que não são administradores.',
  },
  {
    id: 'image-viewer-pan-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'improvement',
    platform: 'web',
    title: 'Visualizador de imagens: arraste para ver um pedaço',
    description:
      'Com a imagem ampliada, clique e arraste para movê-la e ver exatamente a parte que você quer. Funciona no chat e nos anexos do ticket, inclusive com a imagem girada. Ao voltar ao tamanho normal, ela volta ao centro.',
  },
  {
    id: 'ticket-linked-conversation-agent-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'improvement',
    platform: 'web',
    title: 'Ticket: conversas vinculadas mostram quem atende',
    description:
      'Na aba Comunicação, cada conversa vinculada agora mostra o agente que a atende ("Atendente: Maria") ou, se já foi resolvida, quem a atendeu ("Atendida por Maria"). O status também aparece em português (Aberta, Resolvida...).',
  },
  {
    id: 'ticket-open-conversation-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'feature',
    platform: 'web',
    title: 'Ticket: botão "Abrir conversa" na aba Comunicação',
    description:
      'Na aba Comunicação do ticket, o botão "Abrir conversa" cria uma nova conversa com o solicitante do ticket, já vinculada a ele. Basta escolher a caixa de entrada e escrever a primeira mensagem; a conversa aparece em "Conversas vinculadas". Se o cliente já tiver um chat em andamento com outro agente, a aba avisa com o nome do agente e leva até essa conversa, em vez de deixar abrir outra.',
  },
  {
    id: 'company-classification-niche-specialist-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'feature',
    platform: 'web',
    title: 'Empresas: Classificação, Nicho e Especialista com filtros',
    description:
      'A Empresa ganhou três campos independentes: Classificação (1 a 5, definida manualmente), Nicho (lista com criação livre, separada da Categoria) e Especialista (o agente responsável). Os três podem ser usados como filtro na lista de Empresas, e a Classificação também pode ser importada por planilha em Dados > Planilhas.',
  },
  {
    id: 'tickets-advanced-management-button-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'improvement',
    platform: 'web',
    title: 'Tickets: Gestão avançada com botão ao lado do título',
    description:
      'A Gestão avançada de tickets (Busca detalhada e ações em lote) agora abre por um botão ao lado do título "Tickets". Não há mais entrada nova no menu lateral. Também é possível criar, em cada Estágio, a ação "Enviar mensagem padrão ao cliente" (por e-mail ou só registrada no chamado).',
  },
  {
    id: 'client-first-password-rules-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'improvement',
    platform: 'web',
    title:
      'Primeiro acesso do cliente: a tela mostra o que a senha precisa ter',
    description:
      'Na tela "Crie a sua senha", uma lista mostra as regras (pelo menos 8 caracteres, diferente da senha padrão, igual nos dois campos) e se marca enquanto o cliente digita. Cada erro aparece embaixo do campo certo, e dá para ver a senha enquanto digita.',
  },
  {
    id: 'push-delivery-errors-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'mobile',
    title:
      'Notificações do app: falhas de entrega agora aparecem e o iPhone registra melhor',
    description:
      'O servidor tratava qualquer falha de envio de notificação como sucesso, e aparelhos desinstalados nunca eram removidos. Agora a falha é registrada, o aparelho inválido é limpo e, se a chave do iPhone no Firebase estiver errada, o erro fica visível. O app também espera o iPhone liberar o token antes de registrar o aparelho.',
  },
  {
    id: 'attachments-require-login-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'fix',
    platform: 'web',
    title: 'Anexos protegidos: só abrem com login',
    description:
      'Os links dos anexos (imagens, áudios e arquivos de tickets, conversas e chamados) deixaram de abrir para quem não está logado. Antes, qualquer pessoa com o endereço baixava o arquivo. No portal e no aplicativo do cliente nada muda para quem está logado; o app precisa ser atualizado.',
  },
  {
    id: 'integration-api-dev-fields-2026-11-09',
    date: '9 de novembro de 2026',
    isoDate: '2026-11-09',
    type: 'feature',
    platform: 'web',
    title: 'API de integração: usuários, sprints e tipo História',
    description:
      'A API de integração agora lista usuários e sprints da conta, aceita sprint e tipo de desenvolvimento (Bug, Tarefa e o novo História) ao criar e atualizar tickets, e passa a mover o ticket quando só o Estágio é informado. O tipo História também aparece no ticket e no formulário.',
  },
  {
    id: 'internal-chat-recent-first-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'improvement',
    platform: 'web',
    title: 'Chat Interno: quem acabou de falar sobe para o topo na hora',
    description:
      'Ao receber uma mensagem, a conversa (ou canal) vai imediatamente para o primeiro lugar da lista e a prévia mostra a mensagem nova, igual às conversas com clientes. Antes a conversa só subia depois de abrir ou recarregar.',
  },
  {
    id: 'movable-workspace-tabs-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'improvement',
    platform: 'web',
    title: 'Abas abertas agora podem ser arrastadas',
    description:
      'As abas que ficam na barra no topo (Tickets, E-mail, Chat Interno, tickets abertos...) agora podem ser arrastadas para trocar de posição entre si. A ordem escolhida fica guardada neste navegador.',
  },
  {
    id: 'translations-pt-br-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'fix',
    platform: 'web',
    title:
      'Pausa por inatividade agora vale tambÃ©m para as conversas das Filas',
    description:
      'A pesquisa de satisfação (CSAT) e outras mensagens automáticas do sistema agora saem em português. Também traduzimos as telas de análises de campanhas do WhatsApp, os seletores de variáveis, emojis, macros e menções da conversa, os atalhos de formatação, a sincronização de modelos do WhatsApp e outros textos que ainda apareciam em inglês.',
  },
  {
    id: 'inactivity-pause-queue-fallback-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'fix',
    platform: 'web',
    title:
      'Pausa por inatividade agora vale também para as conversas das Filas',
    description:
      'Corrigimos o caso em que a pausa estava ligada nas configurações da caixa de entrada, mas a conversa do Portal estava numa Fila com aviso e encerramento próprios: a Fila ignorava a pausa e encerrava a conversa. Agora, se a Fila não tiver a pausa ligada, vale a pausa da caixa; se a Fila tiver, vale a da Fila.',
  },
  {
    id: 'conversation-contact-history-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'improvement',
    platform: 'web',
    title: 'Histórico completo do cliente dentro da conversa',
    description:
      'Quando um cliente que já falou com a gente abre uma conversa nova, o atendente agora vê, rolando a conversa para cima, tudo o que já foi dito nas conversas anteriores, de qualquer canal (WhatsApp, Portal e os demais), separado por uma divisória com o número, o canal e a data de cada conversa. As mensagens antigas são só para leitura. Cliente realmente novo continua vendo a conversa limpa, e cada atendente só vê o histórico das caixas de entrada a que já tem acesso.',
  },
  {
    id: 'projects-fixes-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'fix',
    platform: 'web',
    title:
      'Projetos: aba de cancelados, contadores certos e criação mais segura',
    description:
      'Em Projetos, agora há a aba "Cancelados", onde dá para consultar e reativar projetos cancelados. Os contadores de Ativos, Concluídos e Cancelados passaram a mostrar o total real. O cadastro cria o projeto e as tarefas de uma vez só, sem deixar projeto vazio nem duplicar ao tentar de novo. A "Data de início de uso do sistema" agora salva, o progresso não conta mais tickets cancelados, o status dos tickets aparece em português e uma tarefa resolvida fora de ordem não puxa mais o projeto para uma etapa anterior. A lista também ficou mais leve.',
  },
  {
    id: 'loading-screens-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'fix',
    platform: 'web',
    title: 'Telas de carregamento com texto e ícone no tamanho certo',
    description:
      'Corrigimos o ícone de carregamento gigante que tomava a tela e era cortado pelo navegador ao abrir Projetos e Sugestões. Em várias telas (Área do Cliente, Contatos, Campanhas, Chamadas, Manifestações, Relatórios, Central de Ajuda e outras), enquanto nada carrega agora aparece um ícone menor com o texto "Carregando...".',
  },
  {
    id: 'inactivity-notice-repeat-fix-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'fix',
    platform: 'web',
    title: 'Aviso de inatividade não se repete mais',
    description:
      'Corrigimos o aviso de inatividade que era reenviado a cada 5 minutos e nunca chegava à pausa ou ao encerramento. Agora o aviso é enviado uma única vez, a pausa (quando ligada) entra no prazo configurado e, depois de uma pausa já usada, a conversa encerra no prazo definido. Também corrigimos o aviso de fora do horário, que podia repetir a cada mensagem do cliente, e a pesquisa de satisfação por WhatsApp, que não reconhecia a pesquisa já encerrada.',
  },
  {
    id: 'api-dev-fields-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'improvement',
    platform: 'web',
    title: 'API de tickets: campos do desenvolvimento na busca e na edição',
    description:
      'Observações do Desenvolvedor, Observações Sobre o Teste Realizado, Documentação, Instruções e Análise agora aparecem como campos próprios (observacoes_dev, observacoes_teste, documentacao, instrucoes, analise) na lista e no detalhe dos tickets da API, e podem ser enviados ao criar e ao editar (PATCH /tickets/:id), sem precisar usar custom_attributes.',
  },
  {
    id: 'mobile-chat-files-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'feature',
    platform: 'mobile',
    title: 'App: chat agora envia e recebe arquivos (zip, pdf, planilhas...)',
    description:
      'No chat do app, arquivos que não são foto nem áudio apareciam em branco para o cliente. Agora aparecem como um cartão com o nome e o tamanho, e ao tocar o arquivo abre/baixa. O cliente também pode enviar arquivos pela opção "Escolher arquivo"; acima de 100 MB o app avisa e não envia. Também voltaram a ser aceitos rar, 7z e tar na caixa de mensagem do painel.',
  },
  {
    id: 'dev-fields-open-when-filled-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'improvement',
    platform: 'web',
    title: 'Campos do Jira já aparecem abertos quando preenchidos',
    description:
      'Nos tickets de Desenvolvimento, Observações do Desenvolvedor, Observações Sobre o Teste, Documentação, Instruções e Análise agora abrem sozinhos quando têm conteúdo, então dá para ver o que foi registrado sem clicar em cada um. Os vazios continuam fechados.',
  },
  {
    id: 'dev-full-ticket-title-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'improvement',
    platform: 'web',
    title: 'Backlog e Sprint ativo mostram o título completo do ticket',
    description:
      'Na lista do Backlog e nos cards do Sprint ativo, o ticket agora aparece com o título completo, no formato [EMPRESA] | [SOLICITANTE] | [TÍTULO], igual ao cabeçalho do ticket, e não só o problema.',
  },
  {
    id: 'ticket-dev-jira-fields-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'feature',
    platform: 'web',
    title: 'Campos do Jira nos tickets de Desenvolvimento',
    description:
      'Nos tickets da Mesa com o módulo Desenvolvimento, abaixo dos arquivos, agora há Observações do Desenvolvedor, Observações Sobre o Teste Realizado, Documentação, Instruções e Análise, editáveis como a descrição. Esses campos também podem ser lidos e gravados pela API de Tickets.',
  },
  {
    id: 'ticket-cancel-admin-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'feature',
    platform: 'web',
    title: 'Administradores podem cancelar tickets',
    description:
      'Administradores agora têm "Cancelar ticket" no menu de três pontinhos do card do Kanban e em "Ações do ticket", dentro do ticket. Ao clicar, basta informar o motivo do cancelamento, que fica registrado no histórico. Para os demais usuários, a opção não aparece.',
  },
  {
    id: 'ticket-integration-api-expanded-2026-11-06',
    date: '6 de novembro de 2026',
    isoDate: '2026-11-06',
    type: 'feature',
    platform: 'web',
    title: 'API de Tickets para sistemas externos ganhou várias rotas novas',
    description:
      'A API de Integração de Tickets (chave em Configurações → Integrações → API de Tickets) agora permite criar ticket, enviar anexo, ler notas internas, definir responsável e prioridade, gravar campos livres (custom_attributes) e listar Complexidades e Catálogo de Serviço. Documentação completa em /swagger.',
  },
  {
    id: 'client-default-password-first-access-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'Senha padrão e troca no primeiro acesso da Área do Cliente',
    description:
      'Todo solicitante com e-mail e vinculado a uma Empresa agora já tem acesso à Área do Cliente com uma senha padrão, entregue pela equipe (nada é enviado por e-mail). No primeiro acesso, a Área do Cliente abre uma tela para a pessoa criar a própria senha, e nada mais fica liberado até a troca. Contatos novos já nascem com a senha padrão, e o prazo de validade dela é configurável (por padrão, nunca expira). O app do celular entra normalmente com a senha padrão, sem troca de senha.',
  },
  {
    id: 'ticket-description-save-stuck-fix-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Salvar descrição do ticket não ficava mais preso em "editando"',
    description:
      'Ao salvar a descrição do ticket (inclusive após "Resumir conversa"), a alteração era salva, mas os botões "Cancelar"/"Salvar" continuavam na tela em vez de voltar para a visualização normal. Corrigido.',
  },
  {
    id: 'internal-chat-send-button-fix-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Chat Interno: botão "Enviar" volta a funcionar',
    description:
      'O botão "Enviar" do Chat Interno não enviava a mensagem (só o Enter funcionava). Agora o botão e o Enter enviam do mesmo jeito.',
  },
  {
    id: 'internal-chat-ticket-link-fix-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Chat Interno: número do ticket abre o ticket certo',
    description:
      'Ao colar um título com o número do ticket (ex.: #35506) no Chat Interno, o link verde abria outro ticket. Agora ele abre exatamente o ticket com aquele número; se não existir, avisa em vez de abrir outro.',
  },
  {
    id: 'inactivity-nudge-not-repeated-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Aviso de inatividade não se repete mais',
    description:
      'Quando o aviso de inatividade já tinha sido enviado mas o registro dele não era gravado, o sistema reenviava o aviso a cada ciclo e nunca encerrava a conversa. Agora ele reconhece o aviso já enviado e segue para o encerramento (ou a pausa).',
  },
  {
    id: 'ticket-summarize-title-and-error-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: '"Resumir conversa" também sugere o título do ticket',
    description:
      'Ao usar "Resumir conversa" na descrição do ticket, a IA agora também sugere um título curto, revisável antes de salvar. Além disso, se salvar falhar, a mensagem de erro agora mostra o motivo real, em vez de um aviso genérico.',
  },
  {
    id: 'sidebar-ticket-modal-fullscreen-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Modal de "Novo ticket" na barra lateral não fica mais espremido',
    description:
      'Abrir "Novo ticket" pelo botão de "+" da barra lateral abria uma janela comprimida na largura da barra. Agora ela ocupa a tela inteira, como as demais.',
  },
  {
    id: 'resolve-leave-ticket-open-fix-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: '"Deixar ticket em aberto" agora resolve a conversa',
    description:
      'Ao resolver uma conversa com ticket aberto e escolher "Deixar ticket em aberto", a conversa não era resolvida porque a tela entendia a escolha como cancelamento. Agora a conversa é resolvida e o ticket continua aberto. O mesmo ajuste vale para "Fechar ticket" feito pela conversa.',
  },
  {
    id: 'whatsapp-multiple-attachments-fix-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'WhatsApp: enviar vários arquivos de uma vez agora chega tudo',
    description:
      'Ao anexar vários arquivos numa mensagem só (ex.: vários .zip), apenas o primeiro chegava no WhatsApp do cliente - os demais eram descartados em silêncio. Agora todos são enviados, um por vez, para o número do cliente.',
  },
  {
    id: 'conversation-view-only-role-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'Nova função personalizada: visualizar conversas',
    description:
      'Em Configurações → Funções personalizadas, agora existe a permissão "Apenas visualizar conversas": quem só tem essa permissão consegue abrir e ler as conversas, mas não responde nem aparecem as ações do cabeçalho.',
  },
  {
    id: 'sidebar-compose-menu-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'Botão de "+" da barra lateral também abre Novo ticket',
    description:
      'O botão de criar, ao lado da busca por número de ticket, agora abre um menu com "Nova conversa" e "Novo ticket", em vez de ir direto para conversa.',
  },
  {
    id: 'dev-ticket-parent-attachments-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Ticket de Desenvolvimento: anexos do ticket pai já vêm no filho',
    description:
      'Ao criar um Ticket de Desenvolvimento a partir de outro ticket, os anexos que já existiam no ticket de origem aparecem automaticamente na tela de criação e são copiados para o novo ticket.',
  },
  {
    id: 'inactivity-pause-resume-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'Pausa e retomada do atendimento por inatividade',
    description:
      'Em vez de encerrar direto, o atendimento sem resposta do cliente agora pode ser PAUSADO: o aviso sai, a conversa fica Pausada (o atendente é liberado) e o cliente pode retomar enviando qualquer mensagem (ou "sim"; "não" encerra) dentro de um prazo. Se o atendente anterior estiver online e fora do almoço, a conversa volta para ele; senão vai para a fila, e o cliente é avisado nos dois casos. Passado o prazo, encerra como a inatividade de sempre. A conversa só pode ser pausada uma vez, e os prazos podem contar só no horário de atendimento. O analista pode estender a pausa (horas e minutos, com motivo obrigatório registrado). Tudo é configurável e vem desligado: em Configurações > Caixas de entrada > Inatividade e no cadastro de cada Fila.',
  },
  {
    id: 'paused-conversations-button-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'Botão "Pausadas" e "Adiar" agora se chama "Pausar"',
    description:
      'Nas abas Todos e Minhas das Conversas, o novo botão "Pausadas" mostra só as conversas pausadas. Reabrir uma conversa pausada por inatividade antes do prazo retoma o atendimento: quem clicou assume e o cliente é avisado. A opção "Adiar" passou a se chamar "Pausar". Conversa pausada também deixou de contar como "na fila".',
  },
  {
    id: 'queue-arrival-order-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Fila por ordem de chegada',
    description:
      'A aba "Na fila" e o botão "Pegar próximo da fila" agora seguem só a ordem de chegada: o próximo é sempre quem está esperando há mais tempo desde a primeira mensagem. Prioridade e "devolvida pelo atendente" deixaram de furar a fila.',
  },
  {
    id: 'ticket-opens-after-create-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Ticket novo abre sozinho também pelo Kanban e Backlog',
    description:
      'Ao criar um ticket pelo Kanban ou pelo Backlog, a tela do ticket criado abre automaticamente, como já acontecia ao criar pela conversa. "Criar e abrir outro" continua mantendo o formulário aberto.',
  },
  {
    id: 'resolve-edit-ticket-details-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Editar assunto e descrição do ticket ao resolver pela conversa',
    description:
      'Ao resolver a conversa e fechar o ticket vinculado, agora dá para ajustar o assunto e a descrição do ticket na própria tela de fechamento, sem entrar no ticket. A alteração é salva junto com o fechamento, e a mensagem ao cliente já sai com o assunto atualizado.',
  },
  {
    id: 'connection-banner-removed-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Sumiram os avisos "Desconectado" e "Conectado"',
    description:
      'O aviso de conexão que aparecia no canto da tela a cada oscilação da internet foi removido, porque confundia a equipe.',
  },
  {
    id: 'kanban-new-ticket-visible-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Ticket criado pelo "+" da coluna já aparece no Kanban',
    description:
      'Um ticket criado direto pelo botão "+" de uma coluna do Kanban ficava invisível até a página ser recarregada. Agora ele aparece na coluna assim que é criado.',
  },
  {
    id: 'dev-ticket-title-and-attachments-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Ticket de Desenvolvimento: título automático e anexo também no pai',
    description:
      'Ao criar um Ticket de Desenvolvimento a partir de outro ticket, o título já vem preenchido igual ao do ticket de origem (empresa e solicitante), e qualquer anexo enviado no ticket filho é enviado automaticamente para o ticket pai também.',
  },
  {
    id: 'internal-chat-paste-ctrl-enter-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'Chat Interno: colar imagem/arquivo e quebrar linha com Ctrl+Enter',
    description:
      'No Chat Interno, agora é possível colar (Ctrl+V) imagens e arquivos para enviar, igual já funcionava nas Conversas. Além disso, Ctrl+Enter quebra a linha no texto e já envia a mensagem com essa quebra.',
  },
  {
    id: 'session-limit-auto-evict-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Limite de sessões ativas não trava mais o login',
    description:
      'Ao atingir o limite de sessões simultâneas, o login não pergunta mais qual sessão encerrar: a sessão mais antiga é descartada automaticamente e o acesso segue normalmente.',
  },
  {
    id: 'sidebar-conversations-queue-count-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Contador de "Conversas" na barra lateral mostra a fila de abertas',
    description:
      'O número ao lado de "Conversas" na barra lateral passou a mostrar a quantidade de conversas abertas na fila, em vez de outra métrica, para refletir melhor o volume de trabalho pendente.',
  },
  {
    id: 'ticket-title-truncate-fix-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'fix',
    platform: 'web',
    title: 'Título do ticket não quebra mais o cabeçalho',
    description:
      'No cabeçalho do ticket, títulos longos agora são cortados com "..." corretamente, sem empurrar o número do ticket ou quebrar o layout.',
  },
  {
    id: 'whatsapp-auto-ticket-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'feature',
    platform: 'web',
    title: 'WhatsApp: toda conversa já abre com um Ticket',
    description:
      'Toda conversa nova em uma caixa de entrada de WhatsApp agora cria um Ticket automaticamente, mesmo sem nenhuma Automação configurada para isso.',
  },
  {
    id: 'resolve-gates-open-ticket-2026-11-05',
    date: '5 de novembro de 2026',
    isoDate: '2026-11-05',
    type: 'improvement',
    platform: 'web',
    title: 'Resolver conversa com Ticket aberto pede o encerramento dele',
    description:
      'Ao clicar em "Resolver" numa conversa que tem um Ticket ainda aberto, agora aparece a tela de encerramento do Ticket. Cancelando essa tela, nada muda: o Ticket e a conversa continuam abertos.',
  },
  {
    id: 'portal-chat-no-auto-assign-2026-10-30',
    date: '30 de outubro de 2026',
    isoDate: '2026-10-30',
    type: 'fix',
    platform: 'web',
    title:
      'Chat do Portal: conversa não é mais atribuída ao primeiro agente online',
    description:
      'As conversas do chat do Portal do Cliente (web e app) deixaram de ser atribuídas automaticamente a agentes online. Quem direciona a conversa agora é a triagem do bot, que define Mesa e Fila.',
  },
  {
    id: 'mobile-logout-stops-push-2026-10-30',
    date: '30 de outubro de 2026',
    isoDate: '2026-10-30',
    type: 'fix',
    platform: 'mobile',
    title:
      'App: ao sair da conta, o aparelho para de receber notificações dela',
    description:
      'Antes, quem saía da conta no app continuava recebendo as notificações no celular. Agora, ao sair, o aparelho deixa de receber os avisos daquela conta e só volta a recebê-los quando entrar de novo.',
  },
  {
    id: 'ticket-resolution-required-2026-10-29',
    date: '29 de outubro de 2026',
    isoDate: '2026-10-29',
    type: 'improvement',
    platform: 'web',
    title: 'Fechar ticket agora pede a Resolução',
    description:
      'Ao fechar um ticket, além da classificação e da comunicação com o cliente, é preciso descrever o que foi feito para resolver. Esse texto fica no ticket e no Histórico, e vai alimentar o DueRules e a documentação.',
  },
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
