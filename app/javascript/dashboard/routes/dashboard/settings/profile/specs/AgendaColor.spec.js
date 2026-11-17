import { mount } from '@vue/test-utils';
import AgendaColor from '../AgendaColor.vue';
import { EVENT_COLOR_OPTIONS } from 'dashboard/components-next/Agenda/constants';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountIt = props =>
  mount(AgendaColor, {
    props,
    global: {
      stubs: { NextButton: { template: '<button v-bind="$attrs" />' } },
    },
  });

describe('AgendaColor', () => {
  it('emits the swatch color when clicked', async () => {
    const wrapper = mountIt({
      value: '',
      automaticColor: EVENT_COLOR_OPTIONS[0],
    });
    const target = EVENT_COLOR_OPTIONS[2];

    await wrapper
      .find(`[data-testid="agenda-color-${target.slice(1)}"]`)
      .trigger('click');

    expect(wrapper.emitted('change')[0]).toEqual([target]);
  });

  it('marks the automatic color as selected while nothing was chosen', () => {
    const wrapper = mountIt({
      value: '',
      automaticColor: EVENT_COLOR_OPTIONS[1],
    });
    const checked = wrapper
      .findAll('[role="radio"]')
      .filter(el => el.attributes('aria-checked') === 'true');

    expect(checked).toHaveLength(1);
    expect(checked[0].attributes('aria-label')).toBe(EVENT_COLOR_OPTIONS[1]);
    expect(wrapper.find('[data-testid="agenda-color-reset"]').exists()).toBe(
      false
    );
  });

  it('emits a custom color from the color input', async () => {
    const wrapper = mountIt({
      value: '',
      automaticColor: EVENT_COLOR_OPTIONS[0],
    });
    const input = wrapper.find('[data-testid="agenda-color-custom"]');
    input.element.value = '#abcdef';
    await input.trigger('change');

    expect(wrapper.emitted('change')[0]).toEqual(['#abcdef']);
  });

  it('offers going back to the automatic color once one was chosen', async () => {
    const wrapper = mountIt({
      value: '#abcdef',
      automaticColor: EVENT_COLOR_OPTIONS[0],
    });

    await wrapper.find('[data-testid="agenda-color-reset"]').trigger('click');

    expect(wrapper.emitted('change')[0]).toEqual(['']);
  });
});
