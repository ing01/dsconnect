import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import PanelStatCard from '../components/PanelStatCard.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'pt_BR',
  missingWarn: false,
  messages: { pt_BR: {} },
});

const mountCard = (props = {}) =>
  mount(PanelStatCard, {
    props: { band: 'red', count: 3, total: 10, info: 'Explicação', ...props },
    global: {
      plugins: [i18n],
      stubs: { Icon: true },
    },
  });

describe('PanelStatCard', () => {
  it('mostra o número do card', () => {
    const wrapper = mountCard();
    expect(wrapper.get('[data-testid="panel-count-red"]').text()).toBe('3');
  });

  it('esconde a explicação até clicar no (!) e a mostra com o texto', async () => {
    const wrapper = mountCard();
    expect(wrapper.find('[data-testid="panel-info-text-red"]').exists()).toBe(
      false
    );

    await wrapper.get('[data-testid="panel-info-red"]').trigger('click');
    expect(wrapper.get('[data-testid="panel-info-text-red"]').text()).toContain(
      'Explicação'
    );

    await wrapper.get('[data-testid="panel-info-red"]').trigger('click');
    expect(wrapper.find('[data-testid="panel-info-text-red"]').exists()).toBe(
      false
    );
  });

  it('não mostra o (!) quando não há explicação', () => {
    const wrapper = mountCard({ info: '' });
    expect(wrapper.find('[data-testid="panel-info-red"]').exists()).toBe(false);
  });

  it('emite select ao clicar na área principal, não no (!)', async () => {
    const wrapper = mountCard();
    await wrapper.get('[data-testid="panel-info-red"]').trigger('click');
    expect(wrapper.emitted('select')).toBeUndefined();

    await wrapper.get('[data-testid="panel-card-red"]').trigger('click');
    expect(wrapper.emitted('select')[0]).toEqual(['red']);
  });
});
