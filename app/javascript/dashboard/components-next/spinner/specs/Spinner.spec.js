import { mount } from '@vue/test-utils';
import Spinner from '../Spinner.vue';

const sizeOf = props => {
  const svg = mount(Spinner, { props }).find('svg');
  return [svg.attributes('width'), svg.attributes('height')];
};

// Um width/height que o <svg> nao entende (ex.: size="lg") fazia o icone ocupar
// o container inteiro: era o "icone gigantesco" que estourava a tela.
describe('Spinner', () => {
  it('usa 24px por padrao', () => {
    expect(sizeOf({})).toEqual(['24', '24']);
  });

  it('aceita numero e texto numerico em pixels', () => {
    expect(sizeOf({ size: 20 })).toEqual(['20', '20']);
    expect(sizeOf({ size: '32' })).toEqual(['32', '32']);
  });

  it('aceita o nome do tamanho (xs, sm, md, lg, xl)', () => {
    expect(sizeOf({ size: 'xs' })).toEqual(['12', '12']);
    expect(sizeOf({ size: 'sm' })).toEqual(['16', '16']);
    expect(sizeOf({ size: 'md' })).toEqual(['24', '24']);
    expect(sizeOf({ size: 'lg' })).toEqual(['32', '32']);
    expect(sizeOf({ size: 'XL' })).toEqual(['40', '40']);
  });

  it('nunca deixa o tamanho invalido, zero ou enorme: cai no padrao ou no limite', () => {
    expect(sizeOf({ size: 'banana' })).toEqual(['24', '24']);
    expect(sizeOf({ size: '' })).toEqual(['24', '24']);
    expect(sizeOf({ size: 0 })).toEqual(['24', '24']);
    expect(sizeOf({ size: -5 })).toEqual(['24', '24']);
    expect(sizeOf({ size: 500 })).toEqual(['64', '64']);
    expect(sizeOf({ size: 2 })).toEqual(['8', '8']);
  });
});
