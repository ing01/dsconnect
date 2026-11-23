import { defineComponent, ref } from 'vue';
import { mount } from '@vue/test-utils';
import ClearableDateInput from '../ClearableDateInput.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const montar = ({
  inicial = '',
  disabled = false,
  onChange = vi.fn(),
} = {}) => {
  const Host = defineComponent({
    components: { ClearableDateInput },
    setup() {
      const data = ref(inicial);
      return { data, disabled, onChange };
    },
    template: `
      <ClearableDateInput
        v-model="data"
        type="date"
        :disabled="disabled"
        min="2026-01-01"
        data-testid="campo"
        @change="onChange"
      />
    `,
  });
  return mount(Host, { global: { stubs: { Icon: true } } });
};

const botao = wrapper => wrapper.find('[data-testid="clear-date"]');

describe('ClearableDateInput', () => {
  it('hides the (x) while the field is empty', () => {
    expect(botao(montar()).exists()).toBe(false);
  });

  it('shows the (x) when there is a date', () => {
    expect(botao(montar({ inicial: '2026-11-18' })).exists()).toBe(true);
  });

  it('hides the (x) when the field is disabled', () => {
    const wrapper = montar({ inicial: '2026-11-18', disabled: true });

    expect(botao(wrapper).exists()).toBe(false);
  });

  it('clears the value and tells the screen to refresh', async () => {
    const onChange = vi.fn();
    const wrapper = montar({ inicial: '2026-11-18', onChange });

    await botao(wrapper).trigger('click');

    expect(wrapper.find('input').element.value).toBe('');
    expect(botao(wrapper).exists()).toBe(false);
    expect(onChange).toHaveBeenCalledTimes(1);
  });

  it('passes the other attributes to the input', () => {
    const input = montar().find('input');

    expect(input.attributes('min')).toBe('2026-01-01');
    expect(input.attributes('data-testid')).toBe('campo');
    expect(input.attributes('type')).toBe('date');
  });
});
