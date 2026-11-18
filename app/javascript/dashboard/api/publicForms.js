/**
 * O formulario ABERTO (sem login), preenchido por quem recebeu o link na Central de Ajuda.
 *
 * Instancia PROPRIA do axios, sem o `window.axios` do painel: esta requisicao e' de um visitante e
 * nao pode carregar cabecalho de sessao de ninguem. O codigo do link (`token`) e' o que identifica
 * o formulario - nunca o id do banco.
 */
import axios from 'axios';
import { buildSubmissionBody } from 'dashboard/components-next/forms/formFields';

const { apiHost = '' } = window.chatwootConfig || {};
const publico = axios.create({ baseURL: `${apiHost}/` });

const BASE = '/public/api/v1/forms';

export default {
  show(token) {
    return publico.get(`${BASE}/${encodeURIComponent(token)}`);
  },

  // `trap` e' o campo isca (website): pessoa nao ve, robo preenche - o servidor descarta.
  submit(token, { answers, files, respondentName, respondentEmail, trap }) {
    return publico.post(
      `${BASE}/${encodeURIComponent(token)}/responses`,
      buildSubmissionBody({
        answers,
        files,
        extra: {
          respondent_name: respondentName || undefined,
          respondent_email: respondentEmail || undefined,
          website: trap || undefined,
        },
      })
    );
  },
};
