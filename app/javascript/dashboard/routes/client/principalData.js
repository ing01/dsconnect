// Novidades do Portal do Cliente - SOMENTE o que muda a experiência de quem
// usa o Portal (nunca novidades internas da equipe, que já têm a própria
// lista em dashboard/routes/dashboard/principal/changelogData.js).
//
// Mesmo esquema daquela lista: um array fixo, mantido por código (sem tela de
// administração) - peça para adicionar uma novidade quando quiser publicar
// algo novo. `isoDate` dirige o "some depois de 5 dias" de
// `getVisibleChangelogEntries`; `date` é só o rótulo em pt-BR mostrado no
// card, então os dois precisam ficar em sincronia.
export const PRINCIPAL_ENTRIES = [
  {
    id: 'client-mobile-biometric-login',
    date: '27 de outubro de 2026',
    isoDate: '2026-10-27',
    type: 'feature',
    title: 'App: entre com Face ID ou digital',
    description:
      'No app, o botão "Entrar e ativar biometria" na tela de login guarda seu acesso com segurança no aparelho. Depois, é só tocar em "Entrar com biometria" - sem digitar e-mail e senha, mesmo se você sair da conta. Para desligar, use o menu (três pontinhos) > "Desativar biometria".',
  },
  {
    id: 'client-brand-logo-update',
    date: '27 de outubro de 2026',
    isoDate: '2026-10-27',
    type: 'design',
    title: 'Nova logo do DSConnect',
    description:
      'Atualizamos a logo no Portal e no app (ícone, tela de abertura e login). Se o ícone antigo ainda aparecer no seu celular, atualize o app.',
  },
  {
    id: 'client-mobile-chat-history',
    date: '19 de outubro de 2026',
    isoDate: '2026-10-19',
    type: 'feature',
    title: 'App Android: histórico de conversas do Chat',
    description:
      'No app Android, a aba Chat agora tem o botão "Histórico" que lista todas as conversas encerradas com a equipe — cada uma com data, resumo e o histórico completo de mensagens. Se o chat travar, um botão de recarregar aparece direto na tela de erro.',
  },
  {
    id: 'client-delete-account',
    date: '19 de outubro de 2026',
    isoDate: '2026-10-19',
    type: 'feature',
    title: 'Agora você pode excluir sua conta',
    description:
      'Adicionamos o botão "Excluir minha conta" no menu do Portal (canto superior direito). Basta confirmar com sua senha — seus dados pessoais são removidos imediatamente. O histórico de chamados fica guardado sem nenhum dado seu vinculado.',
  },
  {
    id: 'client-tutorial-first-access',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Tutorial rápido na primeira vez que você entra',
    description:
      'Um guia mostra onde ficam Chamados, SAC e Sugestões, Chat, Notificações e o botão de instalar o app. Pode pular a qualquer momento - e quer rever depois? É só clicar em "Tutorial" no topo da tela.',
  },
  {
    id: 'client-ticket-reply-push',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'improvement',
    title: 'Aviso quando a equipe responde seu chamado',
    description:
      'Quando a equipe responde um chamado seu, você recebe um aviso no celular ou navegador (se tiver as notificações ativadas), que abre direto na conversa daquele chamado.',
  },
  {
    id: 'client-monthly-satisfaction',
    date: '6 de outubro de 2026',
    isoDate: '2026-10-06',
    type: 'feature',
    title: 'Avaliação mensal de satisfação',
    description:
      'Uma vez por mês, você pode avaliar o atendimento recebido direto no Portal - leva poucos segundos e ajuda a equipe a melhorar.',
  },
  {
    id: 'client-chat-floating-button',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'Botão flutuante para abrir o Chat mais rápido',
    description:
      'Agora tem um botão fixo no canto da tela, em qualquer página do Portal, que já leva direto pro Chat com a equipe - sem precisar abrir o menu toda vez.',
  },
  {
    id: 'client-sac',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Novo canal de SAC e Sugestões',
    description:
      'Registre sugestões, reclamações, elogios e pedidos de melhoria sobre o ERP, o atendimento, os atendentes, a implantação ou o comercial. Escolha o tipo e o assunto, descreva o caso, anexe arquivos se quiser, e acompanhe o andamento pelo número (SAC-1, SAC-2...) com o histórico e as respostas da equipe.',
  },
  {
    id: 'client-install-app',
    date: '1 de outubro de 2026',
    isoDate: '2026-10-01',
    type: 'feature',
    title: 'Instale o Portal como app no seu celular ou computador',
    description:
      'Agora dá pra instalar o Portal como um aplicativo de verdade, com ícone próprio - procure o botão "Instalar app" no topo da tela. No iPhone/iPad, use Compartilhar > Adicionar à Tela de Início.',
  },
  {
    id: 'client-chat-transcription',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'feature',
    title: 'Áudio do Chat vira texto automaticamente',
    description:
      'Mensagens de áudio no Chat agora mostram o texto transcrito logo abaixo do player, tanto as que você grava quanto as da equipe.',
  },
  {
    id: 'client-chat-push-every-message',
    date: '2 de outubro de 2026',
    isoDate: '2026-10-02',
    type: 'improvement',
    title: 'Aviso do Chat chega em toda mensagem',
    description:
      'Quem ativou as notificações do Chat agora é avisado a cada mensagem nova da equipe, não só na primeira do atendimento.',
  },
  {
    id: 'client-chat-history',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Histórico de conversas do Chat',
    description:
      'Quando a equipe encerra uma conversa do Chat, ela some da tela e uma nova começa na próxima mensagem - sem ficar tudo misturado num fio só. As conversas encerradas ficam guardadas em "Ver conversas anteriores", dentro do Chat.',
  },
  {
    id: 'client-chat-csat',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Avalie o atendimento pelo Chat',
    description:
      'Ao encerrar uma conversa do Chat, chega um pedido para avaliar o atendimento direto ali, sem precisar de outro canal.',
  },
  {
    id: 'client-chat-notifications',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Avisos do Chat mesmo fora do Portal',
    description:
      'Ative as notificações do navegador (botão no topo do Chat) para ser avisado quando a equipe iniciar uma conversa nova, mesmo com o Portal fechado.',
  },
  {
    id: 'client-chat',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Chat com a equipe',
    description:
      'Novo item "Chat" no menu: uma conversa direta com a equipe, com texto, áudio gravado e anexos - sem precisar abrir um ticket para isso.',
  },
  {
    id: 'client-ticket-ai',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'feature',
    title: 'Abrir chamado com IA',
    description:
      'Ao abrir um novo chamado, a opção "Abrir com IA" deixa você gravar um áudio ou escrever livremente - a IA preenche categoria, assunto e descrição para você revisar antes de confirmar.',
  },
  {
    id: 'client-ticket-due-date',
    date: '30 de setembro de 2026',
    isoDate: '2026-09-30',
    type: 'design',
    title: 'Coluna "Prazo" na lista de chamados',
    description:
      'A lista de chamados passou a mostrar o prazo de cada um, no lugar da complexidade - informação que só interessa à equipe internamente.',
  },
];

const VISIBLE_DAYS = 5;

export const getVisiblePrincipalEntries = (
  entries = PRINCIPAL_ENTRIES,
  referenceDate = new Date()
) =>
  entries.filter(entry => {
    const cutoff = new Date(`${entry.isoDate}T00:00:00`);
    cutoff.setDate(cutoff.getDate() + VISIBLE_DAYS);
    return referenceDate < cutoff;
  });
