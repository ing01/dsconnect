import { mount, flushPromises } from '@vue/test-utils';
import ApiKeyPage from '../ApiKeyPage.vue';

const { holder } = vi.hoisted(() => ({ holder: {} }));

vi.mock('dashboard/api/ticketApiKey', () => {
  holder.get = vi.fn();
  holder.generate = vi.fn();
  holder.revoke = vi.fn();
  return {
    default: {
      get: holder.get,
      generate: holder.generate,
      revoke: holder.revoke,
    },
  };
});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('shared/helpers/clipboard', () => ({ copyTextToClipboard: vi.fn() }));

const mountPage = async () => {
  const wrapper = mount(ApiKeyPage, {
    global: {
      stubs: {
        SettingsLayout: {
          template: '<div><slot name="header" /><slot name="body" /></div>',
        },
        BaseSettingsHeader: true,
        'woot-input': {
          props: ['name', 'modelValue'],
          template: '<input :name="name" :value="modelValue" readonly />',
        },
        Button: {
          template: '<button class="plain-btn" @click="$emit(\'click\')" />',
        },
        ConfirmButton: {
          template: '<button class="confirm-btn" @click="$emit(\'click\')" />',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

// O que importa aqui e' o contrato de seguranca: o token completo so' chega
// na resposta de `generate`, nunca de `get` - a tela nao pode fingir que tem
// o valor completo fora desse instante.
describe('ApiKeyPage', () => {
  it('shows no key when none exists yet', async () => {
    holder.get.mockResolvedValue({ data: { exists: false } });
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('TICKET.SETTINGS.API_KEY.INACTIVE');
    expect(wrapper.find('input[name="ticket_api_key"]').exists()).toBe(false);
  });

  it('shows only the masked token on a normal load', async () => {
    holder.get.mockResolvedValue({
      data: { exists: true, masked_token: '****abcd', last_used_at: null },
    });
    const wrapper = await mountPage();

    const input = wrapper.find('input[name="ticket_api_key"]');
    expect(input.element.value).toBe('****abcd');
  });

  it('reveals the full token once, right after generating', async () => {
    holder.get.mockResolvedValue({ data: { exists: false } });
    holder.generate.mockResolvedValue({
      data: { masked_token: '****abcd', token: 'segredo-completo-abcd' },
    });
    const wrapper = await mountPage();

    await wrapper.find('.plain-btn').trigger('click');
    await flushPromises();

    const input = wrapper.find('input[name="ticket_api_key"]');
    expect(input.element.value).toBe('segredo-completo-abcd');
    expect(wrapper.text()).toContain('TICKET.SETTINGS.API_KEY.REVEAL_NOTICE');
  });

  it('revokes the key and goes back to the empty state', async () => {
    holder.get.mockResolvedValue({
      data: { exists: true, masked_token: '****abcd', last_used_at: null },
    });
    holder.revoke.mockResolvedValue({});
    const wrapper = await mountPage();

    await wrapper.find('.confirm-btn:last-of-type').trigger('click');
    await flushPromises();

    expect(holder.revoke).toHaveBeenCalled();
    expect(wrapper.find('input[name="ticket_api_key"]').exists()).toBe(false);
  });
});
