import { mount } from '@vue/test-utils';

import ChatListHeader from '../ChatListHeader.vue';

// O filtro de data nao fica solto na tela: mora dentro do menu do icone de funil, que
// continua dando acesso aos filtros avancados.
const NextButtonStub = {
  inheritAttrs: false,
  props: ['label'],
  emits: ['click'],
  template:
    '<button type="button" v-bind="$attrs" @click="$emit(\'click\', $event)">{{ label }}</button>',
};

const montar = (props = {}) =>
  mount(ChatListHeader, {
    props: {
      pageTitle: 'Conversas',
      hasAppliedFilters: false,
      hasActiveFolders: false,
      activeStatus: 'open',
      isOnExpandedLayout: false,
      conversationStats: {},
      isListLoading: false,
      ...props,
    },
    attachTo: document.body,
    global: {
      mocks: { $t: key => key },
      directives: { tooltip: () => {} },
      stubs: {
        NextButton: NextButtonStub,
        NextInput: true,
        Icon: true,
        ComposeConversation: true,
      },
    },
  });

describe('ChatListHeader, filtro de data dentro do funil', () => {
  it('nao deixa os campos de data soltos na tela', () => {
    const wrapper = montar();

    expect(wrapper.find('[data-testid="date-from"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="date-to"]').exists()).toBe(false);
    wrapper.unmount();
  });

  it('o funil abre o menu com o periodo e nao abre mais direto o modal', async () => {
    const wrapper = montar();

    await wrapper.find('[data-testid="filter-menu-trigger"]').trigger('click');

    expect(wrapper.find('[data-testid="filter-menu"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="date-from"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="date-to"]').exists()).toBe(true);
    expect(wrapper.emitted('filtersModal')).toBeUndefined();
    wrapper.unmount();
  });

  it('"Filtros avancados" no menu abre o modal de antes e fecha o menu', async () => {
    const wrapper = montar();
    await wrapper.find('[data-testid="filter-menu-trigger"]').trigger('click');

    await wrapper.find('[data-testid="advanced-filters"]').trigger('click');

    expect(wrapper.emitted('filtersModal')).toHaveLength(1);
    expect(wrapper.find('[data-testid="filter-menu"]').exists()).toBe(false);
    wrapper.unmount();
  });

  it('digitar a data avisa quem usa o filtro', async () => {
    const wrapper = montar();
    await wrapper.find('[data-testid="filter-menu-trigger"]').trigger('click');

    await wrapper.find('[data-testid="date-from"]').setValue('2026-11-01');
    await wrapper.find('[data-testid="date-to"]').setValue('2026-11-10');

    expect(wrapper.emitted('update:dateFrom')[0]).toEqual(['2026-11-01']);
    expect(wrapper.emitted('update:dateTo')[0]).toEqual(['2026-11-10']);
    wrapper.unmount();
  });

  it('com periodo ativo, o funil mostra um ponto e o menu oferece limpar', async () => {
    const wrapper = montar({ dateFrom: '2026-11-01' });

    expect(wrapper.find('[data-testid="date-filter-dot"]').exists()).toBe(true);

    await wrapper.find('[data-testid="filter-menu-trigger"]').trigger('click');
    await wrapper.find('[data-testid="date-clear"]').trigger('click');

    expect(wrapper.emitted('update:dateFrom')[0]).toEqual(['']);
    expect(wrapper.emitted('update:dateTo')[0]).toEqual(['']);
    wrapper.unmount();
  });

  it('sem periodo, nao mostra o ponto nem o botao de limpar', async () => {
    const wrapper = montar();

    expect(wrapper.find('[data-testid="date-filter-dot"]').exists()).toBe(
      false
    );
    await wrapper.find('[data-testid="filter-menu-trigger"]').trigger('click');
    expect(wrapper.find('[data-testid="date-clear"]').exists()).toBe(false);
    wrapper.unmount();
  });

  it('numa pasta ativa nao ha funil: um botao de calendario abre so o periodo', async () => {
    const wrapper = montar({ hasActiveFolders: true });

    expect(wrapper.find('[data-testid="filter-menu-trigger"]').exists()).toBe(
      false
    );
    await wrapper.find('[data-testid="date-menu-trigger"]').trigger('click');

    expect(wrapper.find('[data-testid="date-from"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="advanced-filters"]').exists()).toBe(
      false
    );
    wrapper.unmount();
  });
});
