import { mount } from '@vue/test-utils';
import { defineComponent, h, KeepAlive, nextTick, ref } from 'vue';
import { KEEP_ALIVE_PAGES, KEEP_ALIVE_MAX } from '../keepAlivePages';

const makePage = name =>
  defineComponent({
    name,
    setup() {
      const typed = ref('');
      return () =>
        h('input', {
          value: typed.value,
          onInput: e => {
            typed.value = e.target.value;
          },
        });
    },
  });

describe('keepAlivePages', () => {
  it('keeps a listed page alive when switching away and back', async () => {
    const Projects = makePage('ProjectsPage');
    const Other = makePage('SettingsPage');
    const current = ref('ProjectsPage');
    const wrapper = mount({
      render: () =>
        h(KeepAlive, { include: KEEP_ALIVE_PAGES, max: KEEP_ALIVE_MAX }, () =>
          h(current.value === 'ProjectsPage' ? Projects : Other)
        ),
    });

    await wrapper.find('input').setValue('filtro');
    current.value = 'SettingsPage';
    await nextTick();
    current.value = 'ProjectsPage';
    await nextTick();

    expect(wrapper.find('input').element.value).toBe('filtro');
  });

  it('does not keep alive a page that is not listed', async () => {
    const Settings = makePage('SettingsPage');
    const Projects = makePage('ProjectsPage');
    const current = ref('SettingsPage');
    const wrapper = mount({
      render: () =>
        h(KeepAlive, { include: KEEP_ALIVE_PAGES, max: KEEP_ALIVE_MAX }, () =>
          h(current.value === 'SettingsPage' ? Settings : Projects)
        ),
    });

    await wrapper.find('input').setValue('perdido');
    current.value = 'ProjectsPage';
    await nextTick();
    current.value = 'SettingsPage';
    await nextTick();

    expect(wrapper.find('input').element.value).toBe('');
  });
});
