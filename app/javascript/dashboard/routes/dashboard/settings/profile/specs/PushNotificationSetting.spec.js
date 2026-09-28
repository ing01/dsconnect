import { mount, flushPromises } from '@vue/test-utils';
import PushNotificationSetting from '../PushNotificationSetting.vue';

// O que estes testes protegem: a DECISÃO de receber push é do usuário e vale
// em qualquer aparelho; a permissão do navegador é de um aparelho só. Antes as
// duas viviam no mesmo botão, e entrar de outro computador mostrava
// "desligado" para quem já tinha decidido receber.
const updateUISettings = vi.fn(() => Promise.resolve());
const requestPushPermissions = vi.fn();
const alerta = vi.fn();
let uiSettings = {};
let inscricaoDoNavegador = null;
let temPermissao = true;

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: (...a) => alerta(...a) }));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: uiSettings },
    updateUISettings: (...a) => updateUISettings(...a),
  }),
}));

vi.mock('dashboard/helper/pushHelper.js', () => ({
  hasPushPermissions: () => temPermissao,
  requestPushPermissions: (...a) => requestPushPermissions(...a),
  verifyServiceWorkerExistence: cb =>
    cb({
      pushManager: {
        getSubscription: () => Promise.resolve(inscricaoDoNavegador),
      },
    }),
}));

const montar = () =>
  mount(PushNotificationSetting, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        'fluent-icon': true,
        Button: {
          props: { label: { type: String, default: '' } },
          template:
            '<button class="acao" :data-label="label" @click="$emit(\'click\')" />',
        },
        ToggleSwitch: {
          props: { modelValue: { type: Boolean, default: false } },
          emits: ['update:modelValue'],
          template:
            '<input class="toggle" type="checkbox" :checked="modelValue" @change="$emit(\'update:modelValue\', !modelValue)" />',
        },
      },
    },
  });

const botao = (wrapper, label) =>
  wrapper.findAll('button.acao').find(b => b.attributes('data-label') === label);

beforeEach(() => {
  // O jsdom nao tem Notification, e sem ela o componente nao desenha nada -
  // ele so aparece em navegador capaz de push.
  window.Notification = { permission: 'granted', requestPermission: vi.fn() };
  updateUISettings.mockClear();
  requestPushPermissions.mockClear();
  alerta.mockClear();
  uiSettings = {};
  inscricaoDoNavegador = null;
  temPermissao = true;
});

describe('PushNotificationSetting', () => {
  // Sem mudança não há o que salvar; um botão sempre clicável não diz se a
  // preferência ficou gravada.
  it('only offers Save once something changed', async () => {
    const wrapper = montar();
    await flushPromises();
    expect(botao(wrapper, 'PROFILE_SETTINGS.FORM.NOTIFICATIONS.SAVE')).toBe(
      undefined
    );

    await wrapper.find('input.toggle').trigger('change');

    expect(
      botao(wrapper, 'PROFILE_SETTINGS.FORM.NOTIFICATIONS.SAVE')
    ).not.toBe(undefined);
  });

  // O ponto central: a decisão vai para o usuário, não para o navegador.
  it('stores the choice on the user, so it travels between devices', async () => {
    const wrapper = montar();
    await flushPromises();

    await wrapper.find('input.toggle').trigger('change');
    await botao(wrapper, 'PROFILE_SETTINGS.FORM.NOTIFICATIONS.SAVE').trigger(
      'click'
    );
    await flushPromises();

    expect(updateUISettings).toHaveBeenCalledWith({
      push_notifications_enabled: true,
    });
  });

  // Ligar já pede a permissão aqui - quem acabou de decidir não deve precisar
  // de um segundo clique no mesmo lugar.
  it('asks the browser right away when turning it on', async () => {
    const wrapper = montar();
    await flushPromises();

    await wrapper.find('input.toggle').trigger('change');
    await botao(wrapper, 'PROFILE_SETTINGS.FORM.NOTIFICATIONS.SAVE').trigger(
      'click'
    );
    await flushPromises();

    expect(requestPushPermissions).toHaveBeenCalled();
  });

  // O caso que motivou tudo: já decidiu antes, entrou de outro aparelho.
  // A tela não pergunta de novo se quer receber - pede só a permissão.
  it('asks only for browser permission on a device that lacks it', async () => {
    uiSettings = { push_notifications_enabled: true };
    inscricaoDoNavegador = null;

    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_PENDING'
    );
    expect(
      botao(wrapper, 'PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_ENABLE')
    ).not.toBe(undefined);
    // A preferência já está ligada: nada a salvar.
    expect(botao(wrapper, 'PROFILE_SETTINGS.FORM.NOTIFICATIONS.SAVE')).toBe(
      undefined
    );
  });

  it('says nothing is pending when the device is already subscribed', async () => {
    uiSettings = { push_notifications_enabled: true };
    inscricaoDoNavegador = { endpoint: 'x' };

    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_READY'
    );
    expect(wrapper.text()).not.toContain(
      'PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_PENDING'
    );
  });

  // Quem nunca decidiu nada não deve ver cobrança de permissão.
  it('does not nag a user who never asked for push', async () => {
    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).not.toContain(
      'PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_PENDING'
    );
  });
});
