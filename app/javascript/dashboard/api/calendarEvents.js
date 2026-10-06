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

  // Scoped by Mesa (the calendar page) or by Ticket (the Compromissos tab);
  // the server requires one of the two. `buildParams` drops the empty one.
  get({ teamId, ticketId, since, until }) {
    const requestURL = `${this.url}?${buildParams({
      team_id: teamId,
      ticket_id: ticketId,
      since,
      until,
    })}`;
    return axios.get(requestURL);
  }

  create(payload) {
    return axios.post(this.url, { calendar_event: payload });
  }

  // `scope`/`occurrenceDate` so existem quando o evento e' uma ocorrencia de
  // serie recorrente (ver RecurrenceScopeDialog) - para um evento simples
  // vem undefined, e `buildParams` os descarta, preservando o comportamento
  // de sempre.
  update(id, { scope, occurrenceDate, ...payload } = {}) {
    const params = buildParams({ scope, occurrence_date: occurrenceDate });
    const suffix = params ? `?${params}` : '';
    return axios.patch(`${this.url}/${id}${suffix}`, {
      calendar_event: payload,
    });
  }

  delete(id, { scope, occurrenceDate } = {}) {
    const params = buildParams({ scope, occurrence_date: occurrenceDate });
    const suffix = params ? `?${params}` : '';
    return axios.delete(`${this.url}/${id}${suffix}`);
  }
}

export default new CalendarEventsAPI();
