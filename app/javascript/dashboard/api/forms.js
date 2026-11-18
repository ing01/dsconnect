/* global axios */
import ApiClient from './ApiClient';
import { buildSubmissionBody } from 'dashboard/components-next/forms/formFields';

class FormsAPI extends ApiClient {
  constructor() {
    super('forms', { accountScoped: true });
  }

  getResponses(formId) {
    return axios.get(`${this.url}/${formId}/form_responses`);
  }

  getResponse(formId, responseId) {
    return axios.get(`${this.url}/${formId}/form_responses/${responseId}`);
  }

  // Preenchimento avulso, a partir do Artigo (POP). O chamado e' opcional: com o numero
  // (`ticketDisplayId`) a resposta fica no historico dele; sem, fica so' guardada no formulario.
  fillResponse(formId, { ticketDisplayId, answers = {}, files = {} }) {
    return axios.post(
      `${this.url}/${formId}/form_responses`,
      buildSubmissionBody({
        answers,
        files,
        extra: { ticket_display_id: ticketDisplayId || undefined },
      })
    );
  }
}

export default new FormsAPI();
