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
