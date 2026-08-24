/* global axios */
import ApiClient from './ApiClient';

const buildParams = params => {
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    searchParams.append(key, value);
  });
  return searchParams.toString();
};

class CalendarEventsAPI extends ApiClient {
  constructor() {
    super('calendar_events', { accountScoped: true });
  }

  get({ teamId, since, until }) {
    const requestURL = `${this.url}?${buildParams({ team_id: teamId, since, until })}`;
    return axios.get(requestURL);
  }

  create(payload) {
    return axios.post(this.url, { calendar_event: payload });
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, { calendar_event: payload });
  }
}

export default new CalendarEventsAPI();
