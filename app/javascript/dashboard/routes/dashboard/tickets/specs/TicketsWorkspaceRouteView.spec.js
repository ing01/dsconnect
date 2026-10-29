import { mount } from '@vue/test-utils';
import { createRouter, createMemoryHistory } from 'vue-router';
import { defineComponent, h } from 'vue';
import TicketsWorkspaceRouteView from '../pages/TicketsWorkspaceRouteView.vue';

// O defeito real: filtro do Kanban e rolagem de uma coluna se perdiam ao abrir
// um ticket e voltar, porque a pagina era destruida e recriada do zero a cada
// troca de rota. O conserto e o `KeepAlive` em TicketsWorkspaceRouteView.vue -
// este teste prova o mecanismo (o `include="TicketsPage"` precisa bater com o
// NOME do componente) com dublês leves, sem montar o Kanban de verdade (que
// arrasta Vuex, TicketBoard etc. - o que se testa aqui e o roteamento, nao o
// quadro).
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const montagens = { TicketsPage: 0 };

// Tem estado proprio (como `selectedAgentIds`/`quickSearch` da pagina real) -
// se o KeepAlive nao reconhecer o componente pelo nome, ele e recriado e o
// campo volta ao valor inicial.
const FakeTicketsPage = defineComponent({
  name: 'TicketsPage',
  data() {
    return { filtro: '' };
  },
  mounted() {
    montagens.TicketsPage += 1;
  },
  render() {
    return h('input', {
      'data-testid': 'filtro',
      value: this.filtro,
      onInput: e => {
        this.filtro = e.target.value;
      },
    });
  },
});

const FakeTicketDetailPage = defineComponent({
  name: 'TicketDetailPage',
  render() {
    return h('div', 'detalhe do ticket');
  },
});

const montar = async () => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/tickets',
        component: TicketsWorkspaceRouteView,
        children: [
          { path: '', name: 'tickets_index', component: FakeTicketsPage },
          {
            path: ':ticketId',
            name: 'ticket_detail',
            component: FakeTicketDetailPage,
          },
        ],
      },
    ],
  });
  router.push('/tickets');
  await router.isReady();

  const wrapper = mount(TicketsWorkspaceRouteView, {
    global: {
      plugins: [router],
    },
  });
  return { wrapper, router };
};

describe('TicketsWorkspaceRouteView', () => {
  beforeEach(() => {
    montagens.TicketsPage = 0;
  });

  it('keeps the Kanban filter after opening a ticket and coming back', async () => {
    const { wrapper, router } = await montar();

    await wrapper.find('[data-testid="filtro"]').setValue('Maria');
    expect(montagens.TicketsPage).toBe(1);

    await router.push('/tickets/42');
    await router.push('/tickets');

    expect(wrapper.find('[data-testid="filtro"]').element.value).toBe('Maria');
    // Recriada do zero chamaria `mounted` de novo - o ponto do KeepAlive e'
    // exatamente nao deixar isso acontecer.
    expect(montagens.TicketsPage).toBe(1);
  });

  it('still unmounts the ticket detail screen normally (not cached)', async () => {
    const { wrapper, router } = await montar();

    await router.push('/tickets/42');
    expect(wrapper.text()).toContain('detalhe do ticket');

    await router.push('/tickets');
    expect(wrapper.text()).not.toContain('detalhe do ticket');
  });
});
