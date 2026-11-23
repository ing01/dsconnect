import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import PanelHandledToday from '../components/PanelHandledToday.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'pt_BR',
  missingWarn: false,
  messages: { pt_BR: {} },
});

const mountList = rows =>
  mount(PanelHandledToday, { props: { rows }, global: { plugins: [i18n] } });

describe('PanelHandledToday', () => {
  it('lista cada agente com seu total do dia', () => {
    const wrapper = mountList([
      { id: 1, name: 'Ana', resolved: 3, in_progress: 2, total: 5 },
      { id: 2, name: 'Bia', resolved: 1, in_progress: 0, total: 1 },
    ]);
    expect(wrapper.get('[data-testid="panel-handled-row-1"]').text()).toContain(
      'Ana'
    );
    expect(wrapper.findAll('li')).toHaveLength(2);
  });

  it('mostra aviso quando ninguém atendeu', () => {
    const wrapper = mountList([]);
    expect(wrapper.findAll('li')).toHaveLength(0);
    expect(wrapper.text()).toContain('HANDLED.EMPTY');
  });
});
