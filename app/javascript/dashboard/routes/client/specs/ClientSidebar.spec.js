import { mount } from '@vue/test-utils';
import ClientSidebar from '../ClientSidebar.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const route = { name: 'client_tickets' };
vi.mock('vue-router', () => ({
  useRoute: () => route,
}));

vi.mock('dashboard/components-next/sidebar/provider', () => ({
  provideSidebarContext: vi.fn(),
}));

const montar = (props = {}) =>
  mount(ClientSidebar, {
    props,
    global: {
      stubs: {
        Icon: true,
        SidebarGroupLeaf: {
          props: {
            label: { type: String, default: '' },
            active: { type: Boolean, default: false },
            collapsed: { type: Boolean, default: false },
          },
          template:
            '<li class="item" :data-active="String(active)" :data-collapsed="String(collapsed)">{{ label }}</li>',
        },
      },
    },
  });

const barra = wrapper => wrapper.find('aside');
const itens = wrapper => wrapper.findAll('.item');

describe('ClientSidebar', () => {
  it('shows only Tickets and Notificações, in that order', () => {
    const rotulos = itens(montar()).map(item => item.text());

    expect(rotulos).toEqual([
      'CLIENT_AREA.MENU.TICKETS',
      'CLIENT_AREA.MENU.NOTIFICATIONS',
    ]);
  });

  // Abrir um chamado não pode apagar o item ativo: o menu perderia a referência
  // de onde se está.
  it('keeps Tickets active on the ticket detail', () => {
    route.name = 'client_ticket_detail';
    const wrapper = montar();

    expect(itens(wrapper)[0].attributes('data-active')).toBe('true');
    route.name = 'client_tickets';
  });

  // Esta é a regressão que deixou a barra invisível no desktop: a classe que
  // tira a gaveta da tela é `ltr:-translate-x-full`, e quem a desfaz a partir de
  // `md` precisa ser `md:ltr:translate-x-0` - com as duas variantes empilhadas.
  // Com `md:translate-x-0` sozinho, a regra do `ltr:` vence em toda largura e a
  // barra fica fora da tela mesmo no computador.
  describe('gaveta no celular', () => {
    it('stays off-screen while closed, but never on the desktop', () => {
      const classes = barra(montar({ isMobileOpen: false })).classes();

      expect(classes).toContain('ltr:-translate-x-full');
      expect(classes).toContain('md:ltr:translate-x-0');
      expect(classes).toContain('md:rtl:translate-x-0');
    });

    it('slides in when opened', () => {
      const classes = barra(montar({ isMobileOpen: true })).classes();

      expect(classes).not.toContain('ltr:-translate-x-full');
    });
  });

  describe('recolhida no desktop', () => {
    it('is a rail when collapsed and full width otherwise', () => {
      expect(barra(montar({ isCollapsed: true })).classes()).toContain(
        'md:w-14'
      );
      expect(barra(montar()).classes()).toContain('md:w-56');
    });

    it('passes the mode down to the menu items', () => {
      const wrapper = montar({ isCollapsed: true });

      expect(itens(wrapper)[0].attributes('data-collapsed')).toBe('true');
    });
  });
});
