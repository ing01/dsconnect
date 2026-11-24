import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import TicketOriginCard from '../TicketOriginCard.vue';

const { holder } = vi.hoisted(() => ({ holder: { push: null } }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => `${key}${params ? JSON.stringify(params) : ''}`,
  }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: holder.push }),
  useRoute: () => ({ params: { accountId: 4 } }),
}));

const mountCard = (ticket, currentUserId = 11) => {
  holder.push = vi.fn();
  const store = createStore({
    getters: { getCurrentUserID: () => currentUserId },
  });

  return mount(TicketOriginCard, {
    props: { ticket },
    global: {
      plugins: [store],
      stubs: {
        Button: { template: '<button />' },
        TicketPropertyRow: { template: '<div><slot /></div>' },
      },
    },
  });
};

describe('TicketOriginCard - criado por', () => {
  it('o nome de quem criou abre o chat interno com a pessoa', async () => {
    const wrapper = mountCard({
      created_at: 1,
      created_by: { id: 12, name: 'Pedro Ruano' },
    });

    const botao = wrapper.find('button[type="button"]');
    expect(botao.text()).toBe('Pedro Ruano');

    await botao.trigger('click');

    expect(holder.push).toHaveBeenCalledWith({
      path: '/app/accounts/4/internal-chat',
      query: { user: 12 },
    });
  });

  it('quem criou o proprio ticket nao tem com quem falar: fica texto', () => {
    const wrapper = mountCard({
      created_at: 1,
      created_by: { id: 11, name: 'João Vitor' },
    });

    expect(wrapper.find('button[type="button"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('João Vitor');
  });

  it('sem autor registrado, a linha nem aparece', () => {
    const wrapper = mountCard({ created_at: 1, created_by: null });

    expect(wrapper.text()).not.toContain('ORIGIN.CREATED_BY');
  });
});
