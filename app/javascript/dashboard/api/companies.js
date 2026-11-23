/* global axios */
import ApiClient from './ApiClient';

const buildParams = params =>
  new URLSearchParams(
    Object.entries(params).filter(
      ([key, value]) => value !== undefined && (value !== '' || key === 'q')
    )
  ).toString();

class CompanyAPI extends ApiClient {
  constructor() {
    super('companies', { accountScoped: true });
  }

  get(params = {}) {
    const {
      page = 1,
      sort = 'name',
      classificationLevel = '',
      companyNicheId = '',
      specialistId = '',
      companySubNicheId = '',
      status = '',
    } = params;
    const requestURL = `${this.url}?${buildParams({
      page,
      sort,
      classification_level: classificationLevel,
      company_niche_id: companyNicheId,
      company_sub_niche_id: companySubNicheId,
      specialist_id: specialistId,
      status,
    })}`;
    return axios.get(requestURL);
  }

  search(
    query = '',
    page = 1,
    sort = 'name',
    classificationLevel = '',
    companyNicheId = '',
    specialistId = '',
    companySubNicheId = '',
    status = ''
  ) {
    const requestURL = `${this.url}/search?${buildParams({
      q: query,
      page,
      sort,
      classification_level: classificationLevel,
      company_niche_id: companyNicheId,
      company_sub_niche_id: companySubNicheId,
      specialist_id: specialistId,
      status,
    })}`;
    return axios.get(requestURL);
  }

  // `q` narrows to contacts of this company; the sibling /contacts/search does
  // the opposite (contacts NOT in the company, for assigning one).
  listContacts(id, page = 1, q = '') {
    return axios.get(`${this.url}/${id}/contacts?${buildParams({ page, q })}`);
  }

  listNotes(id) {
    return axios.get(`${this.url}/${id}/notes`);
  }

  listConversations(id) {
    return axios.get(`${this.url}/${id}/conversations`);
  }

  listTickets(id) {
    return axios.get(`${this.url}/${id}/tickets`);
  }

  lookupCnpj(cnpj) {
    return axios.get(`${this.url}/cnpj_lookup?${buildParams({ cnpj })}`);
  }

  // Gestao de clientes: `ids` (ou `select_all` + os filtros da lista) diz QUEM
  // muda; `changes` diz o QUE muda. So os campos presentes em `changes` sao
  // alterados, e um valor vazio limpa o campo.
  bulkUpdate(payload) {
    return axios.post(`${this.url}/bulk_update`, payload);
  }

  // Log das ultimas alteracoes em massa (andamento e clientes com erro).
  bulkUpdates() {
    return axios.get(`${this.url}/bulk_updates`);
  }

  listCredentials(id) {
    return axios.get(`${this.url}/${id}/credentials`);
  }

  createCredential(id, payload) {
    return axios.post(`${this.url}/${id}/credentials`, {
      company_credential: payload,
    });
  }

  updateCredential(id, credentialId, payload) {
    return axios.patch(`${this.url}/${id}/credentials/${credentialId}`, {
      company_credential: payload,
    });
  }

  removeCredential(id, credentialId) {
    return axios.delete(`${this.url}/${id}/credentials/${credentialId}`);
  }

  searchContacts(id, query = '', page = 1) {
    const requestURL = `${this.url}/${id}/contacts/search?${buildParams({ q: query, page })}`;
    return axios.get(requestURL);
  }

  createContact(id, payload) {
    return axios.post(`${this.url}/${id}/contacts`, payload);
  }

  removeContact(id, contactId) {
    return axios.delete(`${this.url}/${id}/contacts/${contactId}`);
  }

  destroyCustomAttributes(id, customAttributes) {
    return axios.post(`${this.url}/${id}/destroy_custom_attributes`, {
      custom_attributes: customAttributes,
    });
  }

  destroyAvatar(id) {
    return axios.delete(`${this.url}/${id}/avatar`);
  }
}

export default new CompanyAPI();
