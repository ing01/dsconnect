import ApiClient from './ApiClient';

class ImplementationReportsAPI extends ApiClient {
  constructor() {
    super('implementation_reports', { accountScoped: true });
  }

  hoursSummary(params) {
    return axios.get(`${this.url}/hours_summary`, { params });
  }

  monthly(params) {
    return axios.get(`${this.url}/monthly`, { params });
  }

  byImplementer(params) {
    return axios.get(`${this.url}/by_implementer`, { params });
  }

  byModule(params) {
    return axios.get(`${this.url}/by_module`, { params });
  }

  incidence(params) {
    return axios.get(`${this.url}/incidence`, { params });
  }

  complexity(params) {
    return axios.get(`${this.url}/complexity`, { params });
  }
}

export default new ImplementationReportsAPI();
