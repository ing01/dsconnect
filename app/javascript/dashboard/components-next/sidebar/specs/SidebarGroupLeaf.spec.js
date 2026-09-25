import { mount } from '@vue/test-utils';
import { h } from 'vue';
import SidebarGroupLeaf from '../SidebarGroupLeaf.vue';

vi.mock('../provider', () => ({
  useSidebarContext: () => ({
    resolvePermissions: () => [],
    resolveFeatureFlag: () => '',
  }),
}));

const PolicyStub = {
  props: ['as', 'permissions', 'featureFlag'],
  template: '<li><slot /></li>',
};

const RouterLinkStub = {
  props: ['to'],
  template: '<a><slot /></a>',
};

const mountLeaf = props =>
  mount(SidebarGroupLeaf, {
    props: {
      label: 'Support',
      to: '/support',
      ...props,
    },
    global: {
      stubs: {
        Icon: true,
        Policy: PolicyStub,
        RouterLink: RouterLinkStub,
      },
    },
  });

describe('SidebarGroupLeaf', () => {
  // Menu recolhido: so o icone, com o nome no `title`. A Area do Cliente monta
  // ESTE componente, e nao uma copia - por isso o modo mora aqui.
  describe('collapsed', () => {
    it('shows the label by default', () => {
      expect(mountLeaf().text()).toContain('Support');
    });

    it('hides the label and the badge when collapsed', () => {
      const wrapper = mountLeaf({ collapsed: true, badgeCount: 7 });

      expect(wrapper.text()).not.toContain('Support');
      expect(
        wrapper.find('[data-test-id="sidebar-unread-badge"]').exists()
      ).toBe(false);
    });

    it('centres the icon when collapsed', () => {
      expect(mountLeaf({ collapsed: true }).find('a').classes()).toContain(
        'justify-center'
      );
      expect(mountLeaf().find('a').classes()).not.toContain('justify-center');
    });
  });

  it('renders unread badge when count is present', () => {
    const wrapper = mountLeaf({ badgeCount: 7 });
    const badge = wrapper.find('[data-test-id="sidebar-unread-badge"]');

    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe('7');
  });

  it('does not render unread badge when count is zero', () => {
    const wrapper = mountLeaf({ badgeCount: 0 });

    expect(wrapper.find('[data-test-id="sidebar-unread-badge"]').exists()).toBe(
      false
    );
  });

  it('caps large unread counts', () => {
    const wrapper = mountLeaf({ badgeCount: 120 });

    expect(wrapper.find('[data-test-id="sidebar-unread-badge"]').text()).toBe(
      '99+'
    );
  });

  it('passes unread count to custom leaf components', () => {
    const wrapper = mountLeaf({
      badgeCount: 4,
      component: leafProps =>
        h(
          'span',
          { 'data-test-id': 'custom-leaf-count' },
          leafProps.badgeCount
        ),
    });

    expect(wrapper.find('[data-test-id="custom-leaf-count"]').text()).toBe('4');
  });
});
