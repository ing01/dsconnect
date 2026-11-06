import { mount } from '@vue/test-utils';
import PageLoader from '../PageLoader.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

// Carregamento de tela nunca pode ser so o icone: sem texto parece que travou.
describe('PageLoader', () => {
  it('mostra o texto padrao de carregamento e o icone em tamanho controlado', () => {
    const wrapper = mount(PageLoader);

    expect(wrapper.text()).toContain('GENERAL.LOADING');
    const svg = wrapper.find('svg');
    expect(svg.attributes('width')).toBe('32');
    expect(svg.attributes('height')).toBe('32');
  });

  it('mostra a mensagem informada no lugar do texto padrao', () => {
    const wrapper = mount(PageLoader, { props: { message: 'Carregando projetos...' } });

    expect(wrapper.text()).toContain('Carregando projetos...');
    expect(wrapper.text()).not.toContain('GENERAL.LOADING');
  });

  it('avisa leitores de tela que e um carregamento', () => {
    const wrapper = mount(PageLoader);

    expect(wrapper.attributes('role')).toBe('status');
  });
});
