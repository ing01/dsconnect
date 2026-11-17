import { mount } from '@vue/test-utils';
import CreateScheduleDialog from '../CreateScheduleDialog.vue';
import ProjectsAPI from 'dashboard/api/projects';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/projects', () => ({
  default: {
    createSchedule: vi.fn(() =>
      Promise.resolve({ data: { created_count: 1, failed: [] } })
    ),
  },
}));
vi.mock('dashboard/api/projectModules', () => ({
  default: { get: vi.fn(() => Promise.resolve({ data: [] })) },
}));

const mountDialog = () =>
  mount(CreateScheduleDialog, {
    props: { projectId: 1 },
    global: {
      stubs: {
        Dialog: { template: '<div><slot /><slot name="footer" /></div>' },
        NextButton: {
          props: ['label', 'disabled'],
          template:
            '<button :disabled="disabled" :data-label="label" @click="$emit(\'click\')" />',
        },
      },
    },
  });

const saveButton = wrapper =>
  wrapper.find('[data-label="PROJECTS.SCHEDULE.SAVE"]');

describe('CreateScheduleDialog - novo ticket', () => {
  it('asks for a description and only enables saving once it is filled', async () => {
    const wrapper = mountDialog();
    await wrapper.findAll('button')[1].trigger('click'); // aba "Novo ticket"

    await wrapper.find('input[type="text"]').setValue('1. Levantamento');
    await wrapper
      .find('input[type="datetime-local"]')
      .setValue('2026-11-19T09:00');
    expect(saveButton(wrapper).attributes('disabled')).toBeDefined();

    await wrapper
      .find('[data-testid="new-ticket-description"]')
      .setValue('Levantar requisitos');
    expect(saveButton(wrapper).attributes('disabled')).toBeUndefined();
  });

  it('sends the description with the new ticket', async () => {
    const wrapper = mountDialog();
    await wrapper.findAll('button')[1].trigger('click');
    await wrapper.find('input[type="text"]').setValue('1. Levantamento');
    await wrapper
      .find('[data-testid="new-ticket-description"]')
      .setValue('Levantar requisitos');
    await wrapper
      .find('input[type="datetime-local"]')
      .setValue('2026-11-19T09:00');

    await saveButton(wrapper).trigger('click');

    const items = ProjectsAPI.createSchedule.mock.calls[0][1];
    expect(items[0]).toMatchObject({
      new_ticket_title: '1. Levantamento',
      description: 'Levantar requisitos',
    });
  });
});
