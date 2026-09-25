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
import { getClientSession } from 'dashboard/helper/clientSession';

const { apiHost = '' } = window.chatwootConfig || {};
const cliente = axios.create({ baseURL: `${apiHost}/` });

const BASE = '/api/v1/client';

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

  // O Kanban: Mesas, Estágios e os tickets que este contato pode ver.
  board(teamId) {
    return cliente.get(`${BASE}/tickets`, {
      headers: headers(),
      params: teamId ? { team_id: teamId } : {},
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
};
