import { mount, flushPromises } from '@vue/test-utils';
import { DirectUpload } from 'activestorage';
import ClientTutorialsAPI from 'dashboard/api/clientTutorials';
import ClientTutorialModulesAPI from 'dashboard/api/clientTutorialModules';
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
vi.mock('dashboard/api/clientTutorialModules', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
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

const modules = [
  { id: 10, name: 'DS Connect', description: null, position: 0, active: true },
  {
    id: 20,
    name: 'DS Comercial',
    description: null,
    position: 1,
    active: true,
  },
];

const montar = async () => {
  ClientTutorialsAPI.get.mockResolvedValue({ data: tutorials });
  ClientTutorialModulesAPI.get.mockResolvedValue({ data: modules });
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
    ClientTutorialModulesAPI.create.mockResolvedValue({});
    ClientTutorialModulesAPI.update.mockResolvedValue({});
    ClientTutorialModulesAPI.delete.mockResolvedValue({});
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

    await wrapper.find('[data-testid="tutorial-add"]').trigger('click');
    const form = wrapper.find('[data-testid="tutorial-form"]');
    await form.find('[data-testid="tutorial-module"]').setValue('20');
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
        client_tutorial_module_id: 20,
        video_url: 'https://youtu.be/dQw4w9WgXcQ',
      },
    });
  });

  it('does not save without a title', async () => {
    const wrapper = await montar();

    await wrapper.find('[data-testid="tutorial-add"]').trigger('click');
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
        client_tutorial_module_id: null,
      },
    });
  });

  it('creates a module and sends the full name and description', async () => {
    const wrapper = await montar();

    await wrapper.find('[data-testid="module-add"]').trigger('click');
    const form = wrapper.find('[data-testid="module-form"]');
    await form.find('input[type="text"]').setValue('  DS Estoque ');
    await form.find('textarea').setValue('Entradas e saídas');
    await form.trigger('submit');
    await flushPromises();

    expect(ClientTutorialModulesAPI.create).toHaveBeenCalledWith({
      client_tutorial_module: {
        name: 'DS Estoque',
        description: 'Entradas e saídas',
        active: true,
      },
    });
  });

  it('uploads a logo for a new module and sends its signed id', async () => {
    DirectUpload.mockImplementation(() => ({
      create: callback => callback(null, { signed_id: 'logo-signed' }),
    }));
    URL.createObjectURL = vi.fn(() => 'blob:preview');
    const wrapper = await montar();

    await wrapper.find('[data-testid="module-add"]').trigger('click');
    const form = wrapper.find('[data-testid="module-form"]');
    await form.find('input[type="text"]').setValue('DS PDV');
    const input = form.find('[data-testid="module-logo-input"]');
    Object.defineProperty(input.element, 'files', {
      value: [new File(['x'], 'logo.png', { type: 'image/png' })],
    });
    await input.trigger('change');
    await flushPromises();

    expect(form.find('[data-testid="module-logo-preview"]').exists()).toBe(
      true
    );

    await form.trigger('submit');
    await flushPromises();

    expect(ClientTutorialModulesAPI.create).toHaveBeenCalledWith({
      client_tutorial_module: {
        name: 'DS PDV',
        description: '',
        active: true,
      },
      logo_signed_id: 'logo-signed',
    });
  });

  it('rejects a logo that is not an image', async () => {
    const wrapper = await montar();

    await wrapper.find('[data-testid="module-add"]').trigger('click');
    const input = wrapper.find('[data-testid="module-logo-input"]');
    Object.defineProperty(input.element, 'files', {
      value: [new File(['x'], 'logo.svg', { type: 'image/svg+xml' })],
    });
    await input.trigger('change');
    await flushPromises();

    expect(DirectUpload).not.toHaveBeenCalled();
    expect(wrapper.find('[data-testid="module-logo-preview"]').exists()).toBe(
      false
    );
  });

  it('removes the saved logo of a module', async () => {
    ClientTutorialModulesAPI.get.mockResolvedValue({
      data: [
        { ...modules[0], logo_url: '/blob/logo.png', logo_name: 'logo.png' },
      ],
    });
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
          ConfirmButton: { template: '<button class="confirm" />' },
        },
      },
    });
    ClientTutorialsAPI.get.mockResolvedValue({ data: [] });
    await flushPromises();

    await wrapper
      .find('[data-testid="module-row-10"]')
      .findAll('button')[2] // subir, descer, editar
      .trigger('click');
    await wrapper
      .find('[data-testid="module-form"] button.text-n-ruby-11')
      .trigger('click');
    await wrapper.find('[data-testid="module-form"]').trigger('submit');
    await flushPromises();

    expect(ClientTutorialModulesAPI.update).toHaveBeenCalledWith(10, {
      client_tutorial_module: {
        name: 'DS Connect',
        description: '',
        active: true,
      },
      remove_logo: true,
    });
  });

  it('rewrites every module position when moving one down', async () => {
    const wrapper = await montar();

    await wrapper
      .find('[data-testid="module-row-10"]')
      .findAll('button')[1] // subir, descer
      .trigger('click');
    await flushPromises();

    expect(ClientTutorialModulesAPI.update).toHaveBeenCalledWith(20, {
      client_tutorial_module: { position: 0 },
    });
    expect(ClientTutorialModulesAPI.update).toHaveBeenCalledWith(10, {
      client_tutorial_module: { position: 1 },
    });
  });

  it('deletes a module', async () => {
    const wrapper = await montar();

    await wrapper
      .find('[data-testid="module-row-10"] .confirm')
      .trigger('click');
    await flushPromises();

    expect(ClientTutorialModulesAPI.delete).toHaveBeenCalledWith(10);
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
