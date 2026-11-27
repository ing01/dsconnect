import { mount } from '@vue/test-utils';
import MenuItem from '../menuItem.vue';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import icons from 'shared/components/FluentIcon/dashboard-icons.json';
import ContextMenu from '../Index.vue';

// O fluent-icon procura "<icone>-outline". Um nome que ja' termina em
// "-outline" nao existe no mapa e derruba o desenho do menu inteiro - foi o
// que impedia o "Excluir e-mail" de funcionar.
describe('context menu icons', () => {
  const options = ContextMenu.data.call({ $t: key => key });

  it.each(Object.entries(options).filter(([, o]) => o && o.icon))(
    '%s points at an icon that exists',
    (_, option) => {
      expect(icons[`${option.icon}-outline`]).toBeDefined();
    }
  );

  it('draws the "Excluir e-mail" option without breaking', () => {
    const wrapper = mount(MenuItem, {
      props: { option: options.deleteEmailOption, variant: 'icon' },
      global: { components: { 'fluent-icon': FluentIcon } },
    });

    expect(wrapper.find('svg path').exists()).toBe(true);
  });
});
