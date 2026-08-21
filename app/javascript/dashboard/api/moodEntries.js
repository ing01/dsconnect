/* global axios */
import ApiClient from './ApiClient';

const buildParams = params => {
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    if (Array.isArray(value)) {
      value.forEach(item => searchParams.append(`${key}[]`, item));
    } else {
      searchParams.append(key, value);
    }
  });
  return searchParams.toString();
};

class MoodEntryAPI extends ApiClient {
  constructor() {
    super('mood_entries', { accountScoped: true });
  }

  today() {
    return axios.get(`${this.url}/today`);
  }

  get(params = {}) {
    const requestURL = `${this.url}?${buildParams(params)}`;
    return axios.get(requestURL);
  }

  create(payload) {
    return axios.post(this.url, { mood_entry: payload });
  }
}

export default new MoodEntryAPI();
