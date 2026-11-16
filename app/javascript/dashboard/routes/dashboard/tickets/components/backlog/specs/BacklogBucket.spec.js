import { mount } from '@vue/test-utils';
import BacklogBucket from '../BacklogBucket.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      params.hours !== undefined ? `${key}:${params.hours}` : key,
  }),
}));

const ticket = (id, hours, overrides = {}) => ({
  id,
  priority: 'medium',
  assignee_id: 1,
  ticket_category_id: 10,
  custom_attributes: { estimativa_original_horas: hours },
  ...overrides,
});

const montar = (tickets, filters = {}) =>
  mount(BacklogBucket, {
    props: { title: 'NOV26 S3', tickets, filters },
    global: {
      stubs: {
        Draggable: { template: '<div />' },
        Checkbox: true,
        Icon: true,
      },
    },
  });

const total = wrapper =>
  wrapper.find('[data-testid="bucket-total-hours"]').text();

describe('BacklogBucket - total de horas estimadas', () => {
  const tickets = [
    ticket(1, 4),
    ticket(2, '2,5', { ticket_category_id: 11, assignee_id: 2 }),
    ticket(3, null, { priority: 'urgent' }),
  ];

  it('sums the estimate of every ticket when nothing is filtered', () => {
    expect(total(montar(tickets))).toBe('TICKET.BACKLOG.TOTAL_HOURS:6,5');
  });

  it('follows the category filter', () => {
    expect(total(montar(tickets, { categoryId: 11 }))).toBe(
      'TICKET.BACKLOG.TOTAL_HOURS:2,5'
    );
  });

  it('follows the agent filter', () => {
    expect(total(montar(tickets, { assigneeIds: [1] }))).toBe(
      'TICKET.BACKLOG.TOTAL_HOURS:4'
    );
  });

  it('shows zero when the filter leaves nothing (or only tickets without estimate)', () => {
    expect(total(montar(tickets, { priority: 'urgent' }))).toBe(
      'TICKET.BACKLOG.TOTAL_HOURS:0'
    );
    expect(total(montar(tickets, { categoryId: 99 }))).toBe(
      'TICKET.BACKLOG.TOTAL_HOURS:0'
    );
  });
});
