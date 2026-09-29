import { mount } from '@vue/test-utils';
import SuggestionBoardColumn from '../SuggestionBoardColumn.vue';

// A regressao que isto fixa: a raiz da coluna carregava as classes do CABECALHO
// (`flex items-center`), e o cabecalho vinha duplicado DENTRO dela, ao lado da
// lista de cards. O resultado na tela era o nome da coluna de um lado e os cards
// do outro, na horizontal - "o titulo no meio e a coluna do lado".
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const sugestao = (id, extra = {}) => ({
  id,
  title: `Sugestao ${id}`,
  suggestion_column_id: 1,
  position: id,
  created_at: '2026-09-28T12:00:00Z',
  ...extra,
});

const montar = (props = {}) =>
  mount(SuggestionBoardColumn, {
    props: {
      column: { id: 1, name: 'Em analise', completed: false },
      suggestions: [sugestao(1), sugestao(2)],
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        // Mesmo formato do vuedraggable: uma lista que desenha o slot `item`
        // por elemento, e que sabe dizer se o arrasto esta desligado.
        Draggable: {
          name: 'Draggable',
          emits: ['change'],
          props: {
            list: { type: Array, default: () => [] },
            disabled: { type: Boolean, default: false },
          },
          template:
            '<div class="lista" :data-disabled="String(disabled)"><template v-for="el in list" :key="el.id"><slot name="item" :element="el" /></template></div>',
        },
      },
    },
  });

const raiz = wrapper => wrapper.element;
const classesDaRaiz = wrapper => raiz(wrapper).className;

// O evento vem do vuedraggable, entao o teste o dispara pelo mesmo caminho em
// vez de chamar o metodo por dentro do componente.
const arrastar = (wrapper, evento) =>
  wrapper.findComponent({ name: 'Draggable' }).vm.$emit('change', evento);

describe('SuggestionBoardColumn', () => {
  // O eixo e o que estava errado: coluna empilha, nao enfileira.
  it('stacks its content vertically', () => {
    const classes = classesDaRaiz(montar());

    expect(classes).toContain('flex-col');
    expect(classes).not.toContain('items-center');
  });

  // Sem largura fixa e sem `flex-shrink-0` as colunas se comprimem umas contra
  // as outras em vez de o quadro rolar na horizontal.
  it('keeps a fixed width so the board scrolls sideways', () => {
    const classes = classesDaRaiz(montar());

    expect(classes).toContain('w-72');
    expect(classes).toContain('flex-shrink-0');
  });

  // O ponto exato do defeito: cabecalho e lista sao IRMAOS. Com a lista dentro
  // do cabecalho, os dois ficavam lado a lado.
  it('puts the header beside nothing - header and list are siblings', () => {
    const wrapper = montar();
    const lista = wrapper.find('.lista');

    expect(lista.exists()).toBe(true);
    // O pai da lista e a RAIZ, nao o cabecalho: era exatamente essa a inversao.
    expect(lista.element.parentElement).toBe(raiz(wrapper));
    // E a raiz tem de ser um elemento de verdade, nao um fragmento - comentario
    // antes do elemento raiz faz o componente perder o `class` que recebe.
    expect(raiz(wrapper).tagName).toBe('DIV');
  });

  it('shows the column name once, not twice', () => {
    const wrapper = montar();

    const ocorrencias = wrapper
      .findAll('span')
      .filter(span => span.text() === 'Em analise');
    expect(ocorrencias).toHaveLength(1);
  });

  it('counts the cards it holds', () => {
    const wrapper = montar();

    expect(wrapper.text()).toContain('2');
    expect(wrapper.findAll('.lista > *')).toHaveLength(2);
  });

  it('does not let a read-only viewer drag', () => {
    const wrapper = montar({ readOnly: true });

    expect(wrapper.find('.lista').attributes('data-disabled')).toBe('true');
  });

  // Vindo de outra coluna ou trocando de lugar na mesma, o pedido e o mesmo.
  it('reports a card arriving from another column', () => {
    const wrapper = montar();

    arrastar(wrapper, { added: { element: sugestao(9), newIndex: 0 } });

    expect(wrapper.emitted('moveSuggestion')[0][0]).toEqual({
      suggestionId: 9,
      suggestionColumnId: 1,
      position: 0,
    });
  });

  it('reports a card reordered inside the column', () => {
    const wrapper = montar();

    arrastar(wrapper, { moved: { element: sugestao(2), newIndex: 1 } });

    expect(wrapper.emitted('moveSuggestion')[0][0]).toMatchObject({
      suggestionId: 2,
      position: 1,
    });
  });

  // `removed` chega na coluna de ORIGEM quando o card sai dela: quem grava a
  // mudanca e a coluna de destino, e reagir aqui gravaria a mesma mudanca duas
  // vezes, com a posicao errada.
  it('stays quiet when a card only leaves', () => {
    const wrapper = montar();

    arrastar(wrapper, { removed: { element: sugestao(1), oldIndex: 0 } });

    expect(wrapper.emitted('moveSuggestion')).toBeUndefined();
  });
});
