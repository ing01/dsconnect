import { mount } from '@vue/test-utils';
import TicketDevFieldsCard from '../TicketDevFieldsCard.vue';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: { isUpdating: false } }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountCard = (props = {}) =>
  mount(TicketDevFieldsCard, {
    props: { ticket: { id: 1, custom_attributes: {} }, ...props },
    global: {
      directives: { dompurifyHtml: () => {} },
      stubs: {
        Accordion: {
          props: ['title'],
          template: '<section :data-title="title"><slot /></section>',
        },
        Button: {
          props: ['label'],
          template:
            '<button :data-label="label" v-bind="$attrs">{{ label }}</button>',
        },
        FullEditor: { template: '<div class="editor" />' },
      },
    },
  });

const section = (wrapper, key) =>
  wrapper.find(`[data-title="TICKET.DETAIL.DEV_FIELDS.${key}"]`);

describe('TicketDevFieldsCard', () => {
  it('shows the five Jira card fields, in order', () => {
    const titles = mountCard()
      .findAll('section')
      .map(node => node.attributes('data-title'));

    expect(titles).toEqual([
      'TICKET.DETAIL.DEV_FIELDS.OBSERVACOES_DEV',
      'TICKET.DETAIL.DEV_FIELDS.OBSERVACOES_TESTE',
      'TICKET.DETAIL.DEV_FIELDS.DOCUMENTACAO',
      'TICKET.DETAIL.DEV_FIELDS.INSTRUCOES',
      'TICKET.DETAIL.DEV_FIELDS.ANALISE',
    ]);
  });

  it('saves one field through its custom_attributes key', async () => {
    const wrapper = mountCard();
    const analise = section(wrapper, 'ANALISE');

    await analise
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]')
      .trigger('click');
    wrapper.vm.draft = 'Causa raiz identificada';
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.SAVE"]')
      .trigger('click');

    expect(wrapper.emitted('save')).toEqual([
      ['analise', 'Causa raiz identificada'],
    ]);
  });

  it('closes the editor once the saved text comes back on the ticket', async () => {
    const wrapper = mountCard();
    await section(wrapper, 'DOCUMENTACAO')
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]')
      .trigger('click');
    wrapper.vm.draft = 'Ver manual';
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.SAVE"]')
      .trigger('click');

    await wrapper.setProps({
      ticket: { id: 1, custom_attributes: { documentacao: 'Ver manual' } },
    });

    expect(wrapper.find('.editor').exists()).toBe(false);
  });

  it('hides the edit buttons without permission', () => {
    const wrapper = mountCard({ canUpdate: false });
    expect(
      wrapper.find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]').exists()
    ).toBe(false);
  });
});
