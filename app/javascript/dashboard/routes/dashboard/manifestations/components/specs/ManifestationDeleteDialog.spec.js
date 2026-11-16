import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import ManifestationDeleteDialog from '../ManifestationDeleteDialog.vue';

const { alert } = vi.hoisted(() => ({ alert: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: alert }));

const montar = destroy => {
  const store = createStore({
    modules: {
      manifestations: {
        namespaced: true,
        getters: { getUIFlags: () => ({ isDeleting: false }) },
        actions: { destroy },
      },
    },
  });

  return mount(ManifestationDeleteDialog, {
    props: { manifestation: { id: 5, reference: 'SAC-5' } },
    global: {
      plugins: [store],
      stubs: {
        // Expõe o que o diálogo real faz: abrir, fechar e emitir `confirm`.
        Dialog: {
          emits: ['confirm'],
          template:
            '<button data-testid="confirm" @click="$emit(\'confirm\')" />',
          methods: { open() {}, close() {} },
        },
      },
    },
  });
};

describe('ManifestationDeleteDialog', () => {
  beforeEach(() => vi.clearAllMocks());

  it('deletes the manifestation and tells the page it is gone', async () => {
    const destroy = vi.fn().mockResolvedValue();
    const wrapper = montar(destroy);

    await wrapper.find('[data-testid="confirm"]').trigger('click');
    await flushPromises();

    expect(destroy).toHaveBeenCalledWith(expect.anything(), 5);
    expect(wrapper.emitted('deleted')).toHaveLength(1);
  });

  it('warns and stays on the page when the server refuses', async () => {
    const destroy = vi.fn().mockRejectedValue({
      response: { data: { error: 'Sem permissão' } },
    });
    const wrapper = montar(destroy);

    await wrapper.find('[data-testid="confirm"]').trigger('click');
    await flushPromises();

    expect(alert).toHaveBeenCalledWith('Sem permissão');
    expect(wrapper.emitted('deleted')).toBeUndefined();
  });
});
