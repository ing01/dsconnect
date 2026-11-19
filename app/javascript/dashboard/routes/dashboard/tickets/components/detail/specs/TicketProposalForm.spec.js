import { mount, flushPromises } from '@vue/test-utils';
import TicketProposalForm from '../TicketProposalForm.vue';
import TicketProposalsAPI from 'dashboard/api/ticketProposals';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/ticketProposals', () => ({
  default: { getDefaults: vi.fn(), createProposal: vi.fn() },
}));

const DEFAULTS = {
  company_id: 5,
  company_name: 'Alfa',
  summary: 'Resumo',
  location: 'Presidente Prudente',
  payment_terms: '50/50',
  proposal_date: '2026-11-19',
  valid_until: '2026-12-19',
  deadline_days: 20,
  items: [{ title: '1 - Ticket', description: '', amount: '100' }],
  requester_email: 'renan@alfa.com.br',
};

const mountForm = async (defaults = DEFAULTS) => {
  TicketProposalsAPI.getDefaults.mockResolvedValue({ data: defaults });
  const wrapper = mount(TicketProposalForm, {
    props: { ticketId: 1 },
    global: { stubs: { TicketPicker: true } },
  });
  await flushPromises();
  return wrapper;
};

const box = wrapper => wrapper.find('[data-testid="proposal-send-email"]');

describe('TicketProposalForm, enviar por e-mail', () => {
  beforeEach(() => vi.clearAllMocks());

  it('comes ticked and says where it will go', async () => {
    const wrapper = await mountForm();

    expect(box(wrapper).element.checked).toBe(true);
    expect(
      wrapper.find('[data-testid="proposal-email-hint"]').text()
    ).toContain('renan@alfa.com.br');
  });

  it('is off, with the reason, when the requester has no e-mail', async () => {
    const wrapper = await mountForm({ ...DEFAULTS, requester_email: null });

    expect(box(wrapper).attributes('disabled')).toBeDefined();
    expect(
      wrapper.find('[data-testid="proposal-email-missing"]').exists()
    ).toBe(true);
  });

  it('sends send_email true when ticked and the proposal is created', async () => {
    TicketProposalsAPI.createProposal.mockResolvedValue({
      data: { email: { sent: true, to: 'renan@alfa.com.br' } },
    });
    const wrapper = await mountForm();

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(TicketProposalsAPI.createProposal.mock.calls[0][1].send_email).toBe(
      true
    );
    expect(wrapper.emitted('saved')).toBeTruthy();
    expect(useAlert.mock.calls[0][0]).toContain('EMAIL.SENT');
  });

  it('sends send_email false when the box is unticked, and says nothing about e-mail', async () => {
    TicketProposalsAPI.createProposal.mockResolvedValue({ data: {} });
    const wrapper = await mountForm();

    await box(wrapper).setValue(false);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(TicketProposalsAPI.createProposal.mock.calls[0][1].send_email).toBe(
      false
    );
    expect(useAlert).not.toHaveBeenCalled();
  });

  it('warns that the proposal was saved but the e-mail did not go', async () => {
    TicketProposalsAPI.createProposal.mockResolvedValue({
      data: { email: { sent: false, reason: 'not_delivered' } },
    });
    const wrapper = await mountForm();

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(wrapper.emitted('saved')).toBeTruthy();
    expect(useAlert.mock.calls[0][0]).toContain('EMAIL.NOT_SENT');
  });
});
