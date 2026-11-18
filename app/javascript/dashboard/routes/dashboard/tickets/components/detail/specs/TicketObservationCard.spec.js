import { mount } from '@vue/test-utils';
import TicketObservationCard from '../TicketObservationCard.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const openDialog = vi.fn();

const mountCard = (props = {}) =>
  mount(TicketObservationCard, {
    props: { ticket: { id: 1, observation: null }, ...props },
    global: {
      directives: { dompurifyHtml: () => {} },
      stubs: {
        Button: {
          props: ['label'],
          template:
            '<button :data-label="label" v-bind="$attrs">{{ label }}</button>',
        },
        Icon: true,
        FullEditor: { template: '<div class="editor" />' },
        Dialog: {
          emits: ['close', 'confirm'],
          template: '<div class="dialog"><slot /><slot name="footer" /></div>',
          methods: {
            open() {
              openDialog();
            },
            close() {
              this.$emit('close');
            },
          },
        },
      },
    },
  });

const editButton = wrapper => wrapper.find('[data-testid="observation-edit"]');

describe('TicketObservationCard', () => {
  beforeEach(() => openDialog.mockClear());

  const toggle = wrapper => wrapper.find('[data-testid="observation-toggle"]');
  const body = wrapper => wrapper.find('.prose-sm');

  describe('minimizado sem texto, aberto com texto', () => {
    it('comeca minimizado quando nao ha observacao', () => {
      const wrapper = mountCard();

      expect(toggle(wrapper).attributes('aria-expanded')).toBe('false');
      expect(wrapper.text()).not.toContain('TICKET.DETAIL.OBSERVATION.EMPTY');
      // O titulo e o botao de adicionar continuam a mao.
      expect(editButton(wrapper).exists()).toBe(true);
    });

    it('comeca aberto quando ha observacao', () => {
      const wrapper = mountCard({ ticket: { id: 1, observation: 'Texto' } });

      expect(toggle(wrapper).attributes('aria-expanded')).toBe('true');
      expect(body(wrapper).exists()).toBe(true);
    });

    it('abre sozinho quando a primeira observacao chega', async () => {
      const wrapper = mountCard();

      await wrapper.setProps({ ticket: { id: 1, observation: 'Nova' } });

      expect(toggle(wrapper).attributes('aria-expanded')).toBe('true');
      expect(body(wrapper).exists()).toBe(true);
    });

    it('minimiza quando a observacao e removida', async () => {
      const wrapper = mountCard({ ticket: { id: 1, observation: 'Texto' } });

      await wrapper.setProps({ ticket: { id: 1, observation: null } });

      expect(toggle(wrapper).attributes('aria-expanded')).toBe('false');
    });

    it('o clique no titulo abre e fecha, sem mexer no texto', async () => {
      const wrapper = mountCard({ ticket: { id: 1, observation: 'Texto' } });

      await toggle(wrapper).trigger('click');
      expect(toggle(wrapper).attributes('aria-expanded')).toBe('false');
      expect(body(wrapper).exists()).toBe(false);

      await toggle(wrapper).trigger('click');
      expect(body(wrapper).exists()).toBe(true);
    });
  });

  it('offers to add one when there is none', () => {
    const wrapper = mountCard();

    expect(editButton(wrapper).attributes('data-label')).toBe(
      'TICKET.DETAIL.OBSERVATION.ADD'
    );
    expect(wrapper.find('[data-testid="observation-remove"]').exists()).toBe(
      false
    );
  });

  it('offers to edit and remove when there is one', () => {
    const wrapper = mountCard({
      ticket: { id: 1, observation: 'Texto atual' },
    });

    expect(editButton(wrapper).attributes('data-label')).toBe(
      'TICKET.DETAIL.OBSERVATION.EDIT'
    );
    expect(wrapper.find('[data-testid="observation-remove"]').exists()).toBe(
      true
    );
  });

  it('opens the editor seeded with the current text', async () => {
    const wrapper = mountCard({
      ticket: { id: 1, observation: 'Texto atual' },
    });
    await editButton(wrapper).trigger('click');
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.draft).toBe('Texto atual');
    expect(openDialog).toHaveBeenCalledTimes(1);
  });

  it('emits the draft on save', async () => {
    const wrapper = mountCard();
    await editButton(wrapper).trigger('click');
    wrapper.vm.draft = 'Nova observação';
    await wrapper.find('[data-testid="observation-save"]').trigger('click');

    expect(wrapper.emitted('save')).toEqual([
      [{ observation: 'Nova observação' }],
    ]);
  });

  it('removes by saving an empty observation', async () => {
    const wrapper = mountCard({
      ticket: { id: 1, observation: 'Texto atual' },
    });
    await editButton(wrapper).trigger('click');
    await wrapper.find('[data-testid="observation-remove"]').trigger('click');

    expect(wrapper.emitted('save')).toEqual([[{ observation: '' }]]);
  });

  it('closes the editor once the saved text comes back', async () => {
    const wrapper = mountCard({ ticket: { id: 1, observation: 'Antes' } });
    await editButton(wrapper).trigger('click');
    await wrapper.vm.$nextTick();
    wrapper.vm.draft = 'Depois';
    await wrapper.find('[data-testid="observation-save"]').trigger('click');

    await wrapper.setProps({ ticket: { id: 1, observation: 'Depois' } });

    expect(wrapper.find('.editor').exists()).toBe(false);
  });

  it('closes the editor when it was removed (the server returns null)', async () => {
    const wrapper = mountCard({ ticket: { id: 1, observation: 'Antes' } });
    await editButton(wrapper).trigger('click');
    await wrapper.vm.$nextTick();
    await wrapper.find('[data-testid="observation-remove"]').trigger('click');

    await wrapper.setProps({ ticket: { id: 1, observation: null } });

    expect(wrapper.find('.editor').exists()).toBe(false);
  });

  it('stays open when the save fails (the text never changes)', async () => {
    const wrapper = mountCard({ ticket: { id: 1, observation: 'Antes' } });
    await editButton(wrapper).trigger('click');
    await wrapper.vm.$nextTick();
    wrapper.vm.draft = 'Depois';
    await wrapper.find('[data-testid="observation-save"]').trigger('click');

    await wrapper.setProps({ ticket: { id: 1, observation: 'Antes' } });

    expect(wrapper.find('.editor').exists()).toBe(true);
  });

  it('hides the controls without permission', () => {
    const wrapper = mountCard({ canUpdate: false });

    expect(editButton(wrapper).exists()).toBe(false);
  });
});
