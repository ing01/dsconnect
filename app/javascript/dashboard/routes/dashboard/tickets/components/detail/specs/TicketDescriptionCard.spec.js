import { mount } from '@vue/test-utils';
import TicketDescriptionCard from '../TicketDescriptionCard.vue';
import { TICKET_DESCRIPTION_TEMPLATE } from '../../../helpers/descriptionTemplate';

const mountCard = (props = {}) =>
  mount(TicketDescriptionCard, {
    props: { ticket: { id: 1, description: '' }, ...props },
    global: {
      mocks: { $t: key => key },
      directives: { dompurifyHtml: () => {} },
      stubs: {
        Button: {
          props: ['label'],
          template:
            '<button :data-label="label" v-bind="$attrs">{{ label }}</button>',
        },
        FullEditor: { template: '<div class="editor" />' },
      },
    },
  });

const templateButton = wrapper =>
  wrapper.find('[data-label="TICKET.DETAIL.DESCRIPTION.USE_TEMPLATE"]');

describe('TicketDescriptionCard', () => {
  it('starts in view mode', () => {
    expect(mountCard().find('.editor').exists()).toBe(false);
  });

  it('offers the template only while the description is empty', () => {
    expect(templateButton(mountCard()).exists()).toBe(true);
    expect(
      templateButton(
        mountCard({ ticket: { id: 1, description: 'Ja escrito' } })
      ).exists()
    ).toBe(false);
  });

  it('seeds the editor with the template skeleton', async () => {
    const wrapper = mountCard();
    await templateButton(wrapper).trigger('click');

    expect(wrapper.find('.editor').exists()).toBe(true);
    expect(wrapper.vm.draft).toBe(TICKET_DESCRIPTION_TEMPLATE);
  });

  it('opens the editor with the current text when editing', async () => {
    const wrapper = mountCard({
      ticket: { id: 1, description: 'Texto atual' },
    });
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]')
      .trigger('click');

    expect(wrapper.vm.draft).toBe('Texto atual');
  });

  it('hides the edit affordances without permission', () => {
    const wrapper = mountCard({ canUpdate: false });

    expect(
      wrapper.find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]').exists()
    ).toBe(false);
  });

  it('emits the draft on save', async () => {
    const wrapper = mountCard();
    await templateButton(wrapper).trigger('click');
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.SAVE"]')
      .trigger('click');

    expect(wrapper.emitted('save')).toEqual([
      [{ description: TICKET_DESCRIPTION_TEMPLATE, title: null }],
    ]);
  });

  // Regressao: o pai so desliga `isSaving` alguns microtasks DEPOIS do commit
  // que atualiza `ticket.description` - um watcher baseado em `!isSaving`
  // corre cedo demais e nunca fecha a edicao, mesmo com o salvamento certo.
  // Por isso o fechamento compara o texto salvo, nao a flag.
  it('leaves edit mode once the saved text comes back, even if isSaving is still true', async () => {
    const wrapper = mountCard({
      ticket: { id: 1, description: 'Texto atual' },
      isSaving: true,
    });
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]')
      .trigger('click');
    await wrapper.vm.$nextTick();
    wrapper.vm.draft = 'Texto novo';
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.SAVE"]')
      .trigger('click');

    await wrapper.setProps({
      ticket: { id: 1, description: 'Texto novo' },
      isSaving: true,
    });

    expect(wrapper.find('.editor').exists()).toBe(false);
  });

  it('stays in edit mode when the save fails (description never changes)', async () => {
    const wrapper = mountCard({
      ticket: { id: 1, description: 'Texto atual' },
    });
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]')
      .trigger('click');
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.SAVE"]')
      .trigger('click');
    await wrapper.setProps({ isSaving: false });

    expect(wrapper.find('.editor').exists()).toBe(true);
  });

  it('does not leave edit mode when another agent changes the description meanwhile', async () => {
    const wrapper = mountCard({
      ticket: { id: 1, description: 'Texto atual' },
    });
    await wrapper
      .find('[data-label="TICKET.DETAIL.DESCRIPTION.EDIT"]')
      .trigger('click');
    wrapper.vm.draft = 'Rascunho em andamento';

    await wrapper.setProps({
      ticket: { id: 1, description: 'Mudanca de outro agente' },
    });

    expect(wrapper.find('.editor').exists()).toBe(true);
    expect(wrapper.vm.draft).toBe('Rascunho em andamento');
  });
});
