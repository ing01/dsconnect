import { mount, flushPromises } from '@vue/test-utils';
import ClientTutorialsAPI from 'dashboard/api/clientTutorials';
import ClientTutorialsPage from '../ClientTutorialsPage.vue';

vi.mock('dashboard/api/clientTutorials', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    directUploadUrl: () => '/uploads',
  },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('activestorage', () => ({ DirectUpload: vi.fn() }));
vi.mock('dashboard/helper/directUploadsHelper', () => ({
  setDirectUploadAuthHeaders: vi.fn(),
}));

const tutorials = [
  {
    id: 1,
    title: 'Notificações',
    description: 'Passos',
    video_url: 'https://youtu.be/dQw4w9WgXcQ',
    video_file_url: null,
    video_file_name: null,
    position: 0,
    active: true,
  },
  {
    id: 2,
    title: 'Arquivo',
    description: null,
    video_url: null,
    video_file_url: '/blob/a.mp4',
    video_file_name: 'a.mp4',
    position: 1,
    active: false,
  },
];

const montar = async () => {
  ClientTutorialsAPI.get.mockResolvedValue({ data: tutorials });
  const wrapper = mount(ClientTutorialsPage, {
    global: {
      stubs: {
        SettingsLayout: {
          template: '<div><slot name="header" /><slot name="body" /></div>',
        },
        BaseSettingsHeader: {
          template: '<div><slot name="actions" /></div>',
        },
        Button: {
          template:
            '<button type="button" @click="$emit(\'click\')"><slot /></button>',
        },
        ConfirmButton: {
          template: '<button class="confirm" @click="$emit(\'click\')" />',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('Configurações > Tutoriais do Portal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    ClientTutorialsAPI.create.mockResolvedValue({});
    ClientTutorialsAPI.update.mockResolvedValue({});
    ClientTutorialsAPI.delete.mockResolvedValue({});
  });

  it('lists the tutorials with their source', async () => {
    const wrapper = await montar();

    expect(wrapper.find('[data-testid="tutorial-row-1"]').text()).toContain(
      'https://youtu.be/dQw4w9WgXcQ'
    );
    expect(wrapper.find('[data-testid="tutorial-row-2"]').text()).toContain(
      'TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.FILE'
    );
  });

  it('creates a tutorial with title, description and a video link', async () => {
    const wrapper = await montar();

    await wrapper.findAll('button')[0].trigger('click'); // Novo tutorial
    const form = wrapper.find('[data-testid="tutorial-form"]');
    await form.find('input[type="text"]').setValue('  Novo vídeo ');
    await form.find('textarea').setValue('Passo a passo');
    await form
      .find('[data-testid="tutorial-link"]')
      .setValue('https://youtu.be/dQw4w9WgXcQ');
    await form.trigger('submit');
    await flushPromises();

    expect(ClientTutorialsAPI.create).toHaveBeenCalledWith({
      client_tutorial: {
        title: 'Novo vídeo',
        description: 'Passo a passo',
        active: true,
        video_url: 'https://youtu.be/dQw4w9WgXcQ',
      },
    });
  });

  it('does not save without a title', async () => {
    const wrapper = await montar();

    await wrapper.findAll('button')[0].trigger('click');
    await wrapper.find('[data-testid="tutorial-form"]').trigger('submit');

    expect(ClientTutorialsAPI.create).not.toHaveBeenCalled();
  });

  it('edits an existing tutorial, keeping its uploaded file', async () => {
    const wrapper = await montar();

    await wrapper
      .find('[data-testid="tutorial-row-2"]')
      .findAll('button')[2] // subir, descer, editar
      .trigger('click');

    const form = wrapper.find('[data-testid="tutorial-form"]');
    await form.find('input[type="text"]').setValue('Arquivo renomeado');
    await form.trigger('submit');
    await flushPromises();

    expect(ClientTutorialsAPI.update).toHaveBeenCalledWith(2, {
      client_tutorial: {
        title: 'Arquivo renomeado',
        description: '',
        active: false,
      },
    });
  });

  it('hides and shows a tutorial without deleting it', async () => {
    const wrapper = await montar();

    await wrapper
      .find('[data-testid="tutorial-row-1"] input[type="checkbox"]')
      .trigger('change');
    await flushPromises();

    expect(ClientTutorialsAPI.update).toHaveBeenCalledWith(1, {
      client_tutorial: { active: false },
    });
  });

  it('rewrites every position when moving a tutorial down', async () => {
    const wrapper = await montar();

    await wrapper
      .find('[data-testid="tutorial-row-1"]')
      .findAll('button')[1]
      .trigger('click'); // seta para baixo
    await flushPromises();

    expect(ClientTutorialsAPI.update).toHaveBeenCalledWith(2, {
      client_tutorial: { position: 0 },
    });
    expect(ClientTutorialsAPI.update).toHaveBeenCalledWith(1, {
      client_tutorial: { position: 1 },
    });
  });

  it('deletes a tutorial', async () => {
    const wrapper = await montar();

    await wrapper
      .find('[data-testid="tutorial-row-1"] .confirm')
      .trigger('click');
    await flushPromises();

    expect(ClientTutorialsAPI.delete).toHaveBeenCalledWith(1);
  });
});
