import { mount } from '@vue/test-utils';
import TicketFollowersSelect from '../TicketFollowersSelect.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const members = [
  { id: 1, name: 'Ingrid' },
  { id: 2, name: 'João Vitor' },
  { id: 3, name: 'Guilherme' },
];

const mountSelect = (modelValue = []) =>
  mount(TicketFollowersSelect, {
    props: { modelValue, members },
    global: { stubs: { DropdownMenu: true } },
  });

describe('TicketFollowersSelect', () => {
  it('shows each follower as a chip with its own remove button', () => {
    const wrapper = mountSelect([1, 2, 3]);

    expect(wrapper.findAll('[data-testid^="follower-chip-"]')).toHaveLength(3);
    expect(wrapper.find('[data-testid="follower-chip-2"]').text()).toContain(
      'João Vitor'
    );
  });

  it('removes only the follower whose x was clicked', async () => {
    const wrapper = mountSelect([1, 2, 3]);

    await wrapper.find('[data-testid="follower-remove-2"]').trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([1, 3]);
  });

  it('clears everybody at once when there is more than one', async () => {
    const wrapper = mountSelect([1, 2]);

    await wrapper.find('[data-testid="followers-clear"]').trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([]);
  });

  it('does not offer "clear" for a single follower, and asks to select when empty', () => {
    expect(
      mountSelect([1]).find('[data-testid="followers-clear"]').exists()
    ).toBe(false);
    expect(
      mountSelect([]).find('[data-testid="followers-toggle"]').text()
    ).toBe('TICKET.CREATE.FOLLOWERS.PLACEHOLDER');
  });

  it('does not allow removing while disabled', () => {
    const wrapper = mount(TicketFollowersSelect, {
      props: { modelValue: [1], members, disabled: true },
      global: { stubs: { DropdownMenu: true } },
    });

    expect(
      wrapper.find('[data-testid="follower-remove-1"]').attributes('disabled')
    ).toBeDefined();
  });
});
