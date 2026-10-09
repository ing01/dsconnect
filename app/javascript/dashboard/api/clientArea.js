/**
 * A API da Área do Cliente.
 *
 * Usa uma instância PRÓPRIA do axios, e não o `window.axios` do painel, por dois
 * motivos. O primeiro é que este arquivo roda nos dois bundles - a tela de login
 * vive no `v3app`, que não define `window.axios`, e a chamada morria com
 * ReferenceError. O segundo é que o axios global carrega os cabeçalhos de sessão
 * do usuário interno, que não têm nada que fazer numa requisição de cliente.
 *
 * Também não estende o ApiClient do painel: aquele monta a URL com
 * `accounts/:id` lido da barra de endereços, e aqui a conta NUNCA vem da URL -
 * ela é a do contato autenticado, resolvida no servidor. Sem id de conta na
 * requisição não há id de conta para trocar.
 */
import axios from 'axios';
import {
  getClientSession,
  clearClientSession,
} from 'dashboard/helper/clientSession';

const { apiHost = '' } = window.chatwootConfig || {};
const cliente = axios.create({ baseURL: `${apiHost}/` });

const BASE = '/api/v1/client';

// Sessão morta não pode virar tela quebrada.
//
// O token do cookie deixa de valer em situações normais: a equipe desliga o
// acesso, ou a própria pessoa redefine a senha - que derruba as sessões de
// propósito. Sem isto, o cookie velho continuava sendo enviado, toda tela
// respondia 401 e o app nunca mandava ninguém de volta ao login: a pessoa
// ficava presa numa tela que não carregava.
//
// O login e a redefinição ficam de fora: ali o 401 é resposta esperada (senha
// errada, link vencido) e tem mensagem própria na tela. Redirecionar comeria
// esse aviso.
const SEM_REDIRECIONAR = [`${BASE}/session`, `${BASE}/password`];

cliente.interceptors.response.use(
  resposta => resposta,
  erro => {
    const url = erro?.config?.url || '';
    const ehSessaoExpirada =
      erro?.response?.status === 401 &&
      !SEM_REDIRECIONAR.some(rota => url.includes(rota));

    if (ehSessaoExpirada) {
      clearClientSession();
      // Carga completa: a tela de login é servida pelo Rails, não é rota deste
      // SPA - e sair tem de largar o estado que ficou em memória.
      window.location.assign('/app/login');
    }
    return Promise.reject(erro);
  }
);

const headers = () => {
  const token = getClientSession()?.token;
  return token ? { api_access_token: token } : {};
};

export default {
  login(credentials) {
    return cliente.post(`${BASE}/session`, credentials);
  },

  logout() {
    return cliente.delete(`${BASE}/session`, { headers: headers() });
  },

  // A troca de senha pelo link do e-mail. SEM cabeçalho de sessão de propósito:
  // quem esqueceu a senha não tem nenhuma, e quem autoriza é o token do e-mail.
  resetPassword({ token, password, passwordConfirmation }) {
    return cliente.put(`${BASE}/password`, {
      token,
      password,
      password_confirmation: passwordConfirmation,
    });
  },

  // A lista: Empresas e os tickets que este contato pode ver, de todas as
  // Mesas juntas. `companyId` só estreita quando o contato tem mais de uma
  // Empresa.
  board(companyId) {
    return cliente.get(`${BASE}/tickets`, {
      headers: headers(),
      params: {
        ...(companyId ? { company_id: companyId } : {}),
      },
    });
  },

  // O chamado aberto: o cabeçalho mais o que as abas mostram.
  ticket(id) {
    return cliente.get(`${BASE}/tickets/${id}`, { headers: headers() });
  },

  // A resposta do cliente dentro do ticket. Multipart quando leva arquivo -
  // mensagem e anexos entram na mesma requisição, e por isso na mesma transação
  // do lado do servidor.
  sendCommunication(ticketId, body, files = []) {
    const form = new FormData();
    form.append('body', body);
    files.forEach(file => form.append('attachments[]', file));

    return cliente.post(`${BASE}/tickets/${ticketId}/communications`, form, {
      headers: headers(),
    });
  },

  // O que a equipe escreveu nos chamados dele, do mais recente ao mais antigo.
  notifications() {
    return cliente.get(`${BASE}/notifications`, { headers: headers() });
  },

  // As Categorias do formulário de abertura - lista plana, de todas as Mesas.
  // O cliente descreve o problema; Mesa e Estágio são decisão da triagem.
  categories() {
    return cliente.get(`${BASE}/categories`, { headers: headers() });
  },

  // Multipart quando há arquivo: o anexo vai na MESMA requisição que abre o
  // chamado. É isso que permite ao servidor recusar de uma vez a categoria que
  // exige anexo - em duas etapas, o ticket já existiria quando a recusa viesse.
  createTicket(ticket, files = []) {
    if (!files.length) {
      return cliente.post(`${BASE}/tickets`, ticket, { headers: headers() });
    }

    const form = new FormData();
    Object.entries(ticket).forEach(([chave, valor]) => {
      if (valor !== null && valor !== undefined) form.append(chave, valor);
    });
    files.forEach(file => form.append('attachments[]', file));

    return cliente.post(`${BASE}/tickets`, form, { headers: headers() });
  },

  // Se ha credencial de IA configurada na conta - so entao a opcao "Abrir com
  // IA" aparece no formulario.
  aiDraftEnabled() {
    return cliente.get(`${BASE}/ticket_drafts/enabled`, { headers: headers() });
  },

  // Texto livre OU audio gravado vira um rascunho (categoria/titulo/descricao)
  // para o cliente revisar - nunca cria o ticket sozinho.
  generateTicketDraft({ text, audio }) {
    const form = new FormData();
    if (audio) {
      form.append('audio', audio);
    } else {
      form.append('text', text);
    }

    return cliente.post(`${BASE}/ticket_drafts`, form, { headers: headers() });
  },

  // O chat com a equipe: cria a conversa na primeira vez (ou devolve a que ja
  // existe) junto do historico e do token de tempo real. Sem relacao com
  // ticket - e uma conversa so por cliente, como um canal de atendimento.
  chat() {
    return cliente.get(`${BASE}/chat`, { headers: headers() });
  },

  // Texto, audio gravado e/ou anexos - tudo na MESMA mensagem, por isso
  // sempre multipart aqui (nunca sabe de antemao se so vem texto).
  sendChatMessage({ content = '', attachments = [], audio = null } = {}) {
    const form = new FormData();
    if (content) form.append('content', content);
    attachments.forEach(file => form.append('attachments[]', file));
    if (audio) {
      form.append('attachments[]', audio);
      form.append('is_voice_message', 'true');
    }

    return cliente.post(`${BASE}/chat/messages`, form, {
      headers: headers(),
    });
  },

  // A inscricao de push (VAPID) do navegador do cliente - mesmo formato que o
  // painel interno ja manda, so que autenticado como Contato.
  registerPushSubscription(subscriptionAttributes) {
    return cliente.post(
      `${BASE}/push_subscription`,
      { subscription_attributes: subscriptionAttributes },
      { headers: headers() }
    );
  },

  // A resposta da pesquisa de satisfacao mandada ao encerrar o chat.
  submitChatCsat(messageId, { rating, feedbackMessage }) {
    return cliente.patch(
      `${BASE}/chat/messages/${messageId}`,
      { rating, feedback_message: feedbackMessage },
      { headers: headers() }
    );
  },

  // O SAC: as manifestacoes deste cliente, ja recortadas por empresa e pela
  // permissao do contato no servidor.
  manifestations() {
    return cliente.get(`${BASE}/manifestations`, { headers: headers() });
  },

  manifestation(id) {
    return cliente.get(`${BASE}/manifestations/${id}`, { headers: headers() });
  },

  // Multipart quando ha arquivo, pela mesma razao da abertura de ticket: o
  // anexo vai na MESMA requisicao, e por isso na mesma transacao do servidor.
  createManifestation(manifestation, files = []) {
    if (!files.length) {
      return cliente.post(`${BASE}/manifestations`, manifestation, {
        headers: headers(),
      });
    }

    const form = new FormData();
    Object.entries(manifestation).forEach(([chave, valor]) => {
      if (valor !== null && valor !== undefined) form.append(chave, valor);
    });
    files.forEach(file => form.append('attachments[]', file));

    return cliente.post(`${BASE}/manifestations`, form, { headers: headers() });
  },

  // A resposta do cliente dentro da manifestacao. Sempre publica - quem fixa
  // isso e o servidor, nao este parametro.
  replyToManifestation(id, body, files = []) {
    const form = new FormData();
    form.append('body', body);
    files.forEach(file => form.append('attachments[]', file));

    return cliente.post(`${BASE}/manifestations/${id}/messages`, form, {
      headers: headers(),
    });
  },

  // As sessoes de chat ja encerradas - a de agora fica em `chat()`.
  chatHistory() {
    return cliente.get(`${BASE}/chat_history`, { headers: headers() });
  },

  chatHistoryConversation(id) {
    return cliente.get(`${BASE}/chat_history/${id}`, { headers: headers() });
  },

  // A Avaliacao Mensal: se este contato ja respondeu o mes de referencia
  // atual, e as dez chaves de pergunta (o texto de cada uma mora so no i18n
  // do frontend - o servidor nunca devolve texto traduzido).
  monthlySurveyStatus() {
    return cliente.get(`${BASE}/monthly_satisfaction_survey`, {
      headers: headers(),
    });
  },

  // Uma nota (1 a 5) por pergunta, mais o comentario livre opcional.
  submitMonthlySurvey({ answers, comment }) {
    return cliente.post(
      `${BASE}/monthly_satisfaction_survey`,
      { answers, comment },
      { headers: headers() }
    );
  },
};
