/* global axios */

import ApiClient from './ApiClient';

class DataImportsAPI extends ApiClient {
  constructor() {
    super('data_imports', { accountScoped: true });
  }

  start(id) {
    return axios.post(`${this.url}/${id}/start`);
  }

  retry(id) {
    return axios.post(`${this.url}/${id}/retry`);
  }

  abandon(id) {
    return axios.post(`${this.url}/${id}/abandon`);
  }

  show(id, params = {}) {
    return axios.get(`${this.url}/${id}`, { params });
  }

  validateSource(payload) {
    return axios.post(`${this.url}/validate_source`, payload);
  }

  upload(dataType, file) {
    const formData = new FormData();
    formData.append('data_type', dataType);
    formData.append('import_file', file);
    return axios.post(`${this.url}/upload`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  downloadSkipLogs(id) {
    return axios.get(`${this.url}/${id}/skip_logs.csv`, {
      responseType: 'blob',
    });
  }

  downloadErrorLogs(id) {
    return axios.get(`${this.url}/${id}/error_logs.csv`, {
      responseType: 'blob',
    });
  }

  downloadUnmatchedCompanies(id) {
    return axios.get(`${this.url}/${id}/unmatched_companies.csv`, {
      responseType: 'blob',
    });
  }

  deleteUnmatchedCompanies(id) {
    return axios.delete(`${this.url}/${id}/unmatched_companies`, {
      params: { confirm: true },
    });
  }
}

export default new DataImportsAPI();
