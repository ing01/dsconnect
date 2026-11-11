import { mount } from '@vue/test-utils';
import SidebarGroupHeader from '../SidebarGroupHeader.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store.js', async () => {
  const { ref } = await import('vue');
  return { useMapGetter: () => ref(0) };
});

const montar = props =>
  mount(SidebarGroupHeader, {
    props: { label: 'Tickets', ...props },
    global: { stubs: { Icon: true, RouterLink: true } },
  });

describe('SidebarGroupHeader, favoritar', () => {
  it('nao mostra a estrela quando o menu nao oferece favoritar', () => {
    expect(montar().find('button').exists()).toBe(false);
  });

  it('mostra a estrela e avisa ao clicar, sem abrir o grupo', async () => {
    const wrapper = montar({ favoritable: true });

    await wrapper.find('button').trigger('click');

    expect(wrapper.emitted('toggleFavorite')).toHaveLength(1);
    expect(wrapper.emitted('toggle')).toBeUndefined();
  });

  it('marca o estado do botao conforme o item e favorito', () => {
    const favorito = montar({ favoritable: true, isFavorite: true });
    const comum = montar({ favoritable: true, isFavorite: false });

    expect(favorito.find('button').attributes('aria-pressed')).toBe('true');
    expect(favorito.find('button').attributes('aria-label')).toBe(
      'SIDEBAR.UNFAVORITE'
    );
    expect(comum.find('button').attributes('aria-pressed')).toBe('false');
    expect(comum.find('button').attributes('aria-label')).toBe(
      'SIDEBAR.FAVORITE'
    );
  });
});

describe('SidebarGroupHeader, aviso de nao lida', () => {
  it('sem aviso, nao mostra o !', () => {
    expect(montar().find('[data-testid="unread-alert"]').exists()).toBe(false);
  });

  it('com aviso, mostra o ! ao lado do nome, com o texto que o explica', () => {
    const wrapper = montar({ alert: true, alertLabel: 'Mensagem nao lida' });

    const mark = wrapper.find('[data-testid="unread-alert"]');
    expect(mark.exists()).toBe(true);
    expect(mark.attributes('aria-label')).toBe('Mensagem nao lida');
  });
});
