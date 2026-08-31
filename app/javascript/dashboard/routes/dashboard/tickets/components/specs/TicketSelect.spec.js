import { mount } from '@vue/test-utils';
import TicketSelect from '../TicketSelect.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const OPTIONS = [
  { value: 1, label: 'João Vitor' },
  { value: 2, label: 'Maria Silva' },
  { value: 3, label: 'Carla Reis' },
  { value: 4, label: 'Diego Melo' },
];

const mountSelect = (props = {}) =>
  mount(TicketSelect, {
    props: { options: OPTIONS, placeholder: 'Selecione', ...props },
    global: {
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
        // Espelha o contrato real do DropdownMenu: cada item vira um botão que
        // devolve o item inteiro no evento.
        DropdownMenu: {
          props: {
            menuItems: { type: Array, default: () => [] },
            showSearch: { type: Boolean, default: false },
          },
          template: `<ul data-menu>
            <li v-if="showSearch" data-search />
            <li
              v-for="item in menuItems"
              :key="String(item.value)"
              :data-value="String(item.value)"
              :data-icon="item.icon"
              :data-selected="String(!!item.isSelected)"
              @click="$emit('action', item)"
            >{{ item.label }}</li>
          </ul>`,
        },
      },
    },
  });

const trigger = wrapper => wrapper.find('button');
const menu = wrapper => wrapper.find('[data-menu]');
const open = async wrapper => {
  await trigger(wrapper).trigger('click');
  return wrapper;
};
const optionAt = (wrapper, value) => wrapper.find(`[data-value="${value}"]`);

describe('TicketSelect', () => {
  it('keeps the standard trigger of the Empresa field', () => {
    const classes = trigger(mountSelect()).classes().join(' ');

    [
      'h-10',
      'px-3',
      'text-sm',
      'rounded-lg',
      'border-n-strong',
      'bg-n-alpha-black2',
      'w-full',
    ].forEach(token => expect(classes).toContain(token));
  });

  it('shows the placeholder until something is chosen', () => {
    expect(trigger(mountSelect()).text()).toBe('Selecione');
  });

  it('stays closed until the trigger is clicked', async () => {
    const wrapper = mountSelect();
    expect(menu(wrapper).exists()).toBe(false);

    await open(wrapper);
    expect(menu(wrapper).exists()).toBe(true);
    expect(trigger(wrapper).attributes('aria-expanded')).toBe('true');
  });

  it('hides the search box unless it was asked for', async () => {
    expect((await open(mountSelect())).find('[data-search]').exists()).toBe(
      false
    );
    const searchable = await open(mountSelect({ showSearch: true }));
    expect(searchable.find('[data-search]').exists()).toBe(true);
  });

  describe('single choice', () => {
    it('names what is chosen', () => {
      expect(trigger(mountSelect({ modelValue: 2 })).text()).toBe(
        'Maria Silva'
      );
    });

    it('emits the value and closes', async () => {
      const wrapper = await open(mountSelect());

      await optionAt(wrapper, 1).trigger('click');

      expect(wrapper.emitted('update:modelValue')[0]).toEqual([1]);
      expect(menu(wrapper).exists()).toBe(false);
    });

    it('offers a way to empty the field when asked', async () => {
      const wrapper = await open(
        mountSelect({ clearable: true, clearLabel: 'Nenhuma', modelValue: 2 })
      );

      await optionAt(wrapper, 'null').trigger('click');

      expect(wrapper.emitted('update:modelValue')[0]).toEqual([null]);
    });
  });

  describe('multiple choice', () => {
    it('lists the chosen ones and counts the rest', () => {
      const wrapper = mountSelect({ multiple: true, modelValue: [1, 2, 3, 4] });

      expect(trigger(wrapper).text()).toBe('João Vitor, Maria Silva +2');
    });

    it('does not add the counter for two or fewer', () => {
      const wrapper = mountSelect({ multiple: true, modelValue: [1, 2] });

      expect(trigger(wrapper).text()).toBe('João Vitor, Maria Silva');
    });

    it('marks each option with a checkbox', async () => {
      const wrapper = await open(
        mountSelect({ multiple: true, modelValue: [1] })
      );

      expect(optionAt(wrapper, 1).attributes('data-icon')).toBe(
        'i-lucide-square-check'
      );
      expect(optionAt(wrapper, 2).attributes('data-icon')).toBe(
        'i-lucide-square'
      );
    });

    // Escolher três pessoas não deveria custar três aberturas do menu.
    it('stays open while choosing', async () => {
      const wrapper = await open(
        mountSelect({ multiple: true, modelValue: [] })
      );

      await optionAt(wrapper, 1).trigger('click');

      expect(menu(wrapper).exists()).toBe(true);
    });

    it('adds to the selection', async () => {
      const wrapper = await open(
        mountSelect({ multiple: true, modelValue: [1] })
      );

      await optionAt(wrapper, 2).trigger('click');

      expect(wrapper.emitted('update:modelValue')[0]).toEqual([[1, 2]]);
    });

    it('removes one that was already chosen', async () => {
      const wrapper = await open(
        mountSelect({ multiple: true, modelValue: [1, 2] })
      );

      await optionAt(wrapper, 1).trigger('click');

      expect(wrapper.emitted('update:modelValue')[0]).toEqual([[2]]);
    });

    it('never offers the empty option, which the checkboxes already cover', async () => {
      const wrapper = await open(
        mountSelect({ multiple: true, clearable: true, clearLabel: 'Nenhuma' })
      );

      expect(optionAt(wrapper, 'null').exists()).toBe(false);
    });
  });

  it('does not open when disabled', async () => {
    const wrapper = await open(mountSelect({ disabled: true }));

    expect(menu(wrapper).exists()).toBe(false);
    expect(trigger(wrapper).attributes('disabled')).toBeDefined();
  });
});
