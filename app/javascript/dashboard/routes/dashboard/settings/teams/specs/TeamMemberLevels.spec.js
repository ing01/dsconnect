import { mount, flushPromises } from '@vue/test-utils';
import TeamMemberLevels from '../TeamMemberLevels.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const dispatch = vi.fn(() => Promise.resolve());

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const members = [
  { id: 9, name: 'Ana', levels: [1] },
  { id: 10, name: 'Bruno', levels: [2, 3] },
];

const mountMatrix = (levelsCount = 2, overrides = {}) =>
  mount(TeamMemberLevels, {
    props: { teamId: 7, members, levelsCount, ...overrides },
    global: {
      stubs: { Button: { template: '<button @click="$emit(\'click\')" />' } },
    },
  });

const boxes = wrapper => wrapper.findAll('input[type="checkbox"]');

beforeEach(() => dispatch.mockClear());

// Esta e a tela onde se informa quem atende em cada nivel. Uma coluna por nivel
// da Mesa: subir a Mesa para tres niveis faz a coluna do Nivel 3 aparecer aqui
// sozinha, sem codigo novo.
describe('TeamMemberLevels', () => {
  it('draws one column per level of the desk', () => {
    // duas pessoas x dois niveis
    expect(boxes(mountMatrix(2)).length).toBe(4);
    expect(boxes(mountMatrix(3)).length).toBe(6);
  });

  it('marks the levels each member already answers for', () => {
    const marcados = boxes(mountMatrix(3)).map(box => box.element.checked);

    // Ana no 1; Bruno no 2 e no 3.
    expect(marcados).toEqual([true, false, false, false, true, true]);
  });

  it('saves what was marked, per member', async () => {
    const wrapper = mountMatrix(3);

    // Ana passa a atender tambem no Nivel 3.
    await boxes(wrapper)[2].trigger('change');
    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('teamMembers/updateLevels', {
      teamId: 7,
      levels: { 9: [1, 3], 10: [2, 3] },
    });
  });

  // Se a Mesa baixar de tres para dois niveis, a habilitacao de Nivel 3 que
  // ficou no banco nao pode ser reenviada: o servidor a descarta, e a tela
  // mostraria uma marcacao que nao existe mais.
  it('drops levels the desk no longer uses', async () => {
    const wrapper = mountMatrix(2);

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('teamMembers/updateLevels', {
      teamId: 7,
      levels: { 9: [1], 10: [2] },
    });
  });

  it('asks for members before levels when the desk has none', () => {
    expect(boxes(mountMatrix(2, { members: [] })).length).toBe(0);
  });
});
