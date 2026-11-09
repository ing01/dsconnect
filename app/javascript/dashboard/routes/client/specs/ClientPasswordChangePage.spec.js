import { mount, flushPromises } from '@vue/test-utils';
import ClientPasswordChangePage from '../pages/ClientPasswordChangePage.vue';

// O defeito: a tela de "Crie a sua senha" so' dizia "pelo menos 8 caracteres". Quem
// escolhia uma senha igual a padrao so' descobria ao salvar, e o erro aparecia embaixo do
// ULTIMO campo, longe do que estava errado. Agora as regras ficam numa lista que se marca
// enquanto se digita, e cada erro vai para o campo dele.
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (key, params) => (params ? `${key}:${JSON.stringify(params)}` : key) }),
}));

const changePassword = vi.fn();
vi.mock('dashboard/api/clientArea', () => ({
  default: {
    changePassword: (...args) => changePassword(...args),
    logout: vi.fn(() => Promise.resolve()),
  },
}));

vi.mock('dashboard/helper/clientSession', () => ({
  clearClientSession: vi.fn(),
  hasClientSession: () => true,
  markClientPasswordChanged: vi.fn(),
}));

// O Input real so' importa pelo que expõe: o rotulo, o texto de erro e o campo.
const InputStub = {
  props: ['modelValue', 'type', 'label', 'message', 'messageType'],
  emits: ['update:modelValue'],
  template: `
    <label :data-label="label">
      <input :type="type" :value="modelValue" @input="$emit('update:modelValue', $event.target.value)" />
      <span v-if="message" class="mensagem" :data-tipo="messageType">{{ message }}</span>
    </label>`,
};

const montar = () =>
  mount(ClientPasswordChangePage, {
    global: {
      stubs: {
        Input: InputStub,
        Icon: true,
        Button: {
          props: ['label'],
          emits: ['click'],
          template: '<button :data-label="label" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const campo = (wrapper, rotulo) => wrapper.find(`[data-label="CLIENT_AREA.PASSWORD_CHANGE.${rotulo}"]`);
const digitar = (wrapper, rotulo, valor) => campo(wrapper, rotulo).find('input').setValue(valor);
const requisito = (wrapper, chave) => wrapper.find(`[data-requisito="${chave}"]`).attributes('data-estado');
const mensagemDe = (wrapper, rotulo) => campo(wrapper, rotulo).find('.mensagem');
const salvar = wrapper => wrapper.find('[data-label="CLIENT_AREA.PASSWORD_CHANGE.SAVE"]').trigger('click');

describe('ClientPasswordChangePage', () => {
  beforeEach(() => changePassword.mockReset());

  it('lists what the new password needs, neutral until the person types', () => {
    const wrapper = montar();

    expect(wrapper.text()).toContain('REQUIREMENTS_TITLE');
    expect(wrapper.text()).toContain('REQUIREMENT_LENGTH:{"count":8}');
    expect(wrapper.text()).toContain('REQUIREMENT_DIFFERENT');
    expect(wrapper.text()).toContain('REQUIREMENT_MATCH');
    ['tamanho', 'diferente', 'igual'].forEach(chave => expect(requisito(wrapper, chave)).toBe('neutro'));
  });

  it('ticks each requirement as it is met', async () => {
    const wrapper = montar();
    await digitar(wrapper, 'CURRENT', 'padrao123');

    await digitar(wrapper, 'NEW', 'curta');
    expect(requisito(wrapper, 'tamanho')).toBe('neutro');
    expect(requisito(wrapper, 'diferente')).toBe('ok');

    await digitar(wrapper, 'NEW', 'MinhaSenha9');
    expect(requisito(wrapper, 'tamanho')).toBe('ok');

    await digitar(wrapper, 'CONFIRM', 'MinhaSenha9');
    expect(requisito(wrapper, 'igual')).toBe('ok');
  });

  it('does not count the default password as "different"', async () => {
    const wrapper = montar();
    await digitar(wrapper, 'CURRENT', 'padrao123');
    await digitar(wrapper, 'NEW', 'padrao123');

    expect(requisito(wrapper, 'diferente')).toBe('neutro');
  });

  describe('ao salvar com algo errado', () => {
    it('puts the message under the CURRENT password and turns the pending items red', async () => {
      const wrapper = montar();
      await salvar(wrapper);

      expect(mensagemDe(wrapper, 'CURRENT').text()).toContain('ERRORS.CURRENT');
      expect(requisito(wrapper, 'tamanho')).toBe('falta');
    });

    it('puts a too short password under the NEW field, not the last one', async () => {
      const wrapper = montar();
      await digitar(wrapper, 'CURRENT', 'padrao123');
      await digitar(wrapper, 'NEW', 'curta');
      await salvar(wrapper);

      expect(mensagemDe(wrapper, 'NEW').text()).toContain('ERRORS.TOO_SHORT');
      expect(mensagemDe(wrapper, 'CONFIRM').exists()).toBe(false);
      expect(changePassword).not.toHaveBeenCalled();
    });

    it('explains that the new password cannot be the default one', async () => {
      const wrapper = montar();
      await digitar(wrapper, 'CURRENT', 'padrao123');
      await digitar(wrapper, 'NEW', 'padrao123');
      await digitar(wrapper, 'CONFIRM', 'padrao123');
      await salvar(wrapper);

      expect(mensagemDe(wrapper, 'NEW').text()).toContain('ERRORS.SAME_AS_DEFAULT');
      expect(changePassword).not.toHaveBeenCalled();
    });

    it('puts a mismatch under the CONFIRM field', async () => {
      const wrapper = montar();
      await digitar(wrapper, 'CURRENT', 'padrao123');
      await digitar(wrapper, 'NEW', 'MinhaSenha9');
      await digitar(wrapper, 'CONFIRM', 'MinhaSenha8');
      await salvar(wrapper);

      expect(mensagemDe(wrapper, 'CONFIRM').text()).toContain('ERRORS.MISMATCH');
    });
  });

  describe('a recusa do servidor', () => {
    const preencher = async wrapper => {
      await digitar(wrapper, 'CURRENT', 'padrao123');
      await digitar(wrapper, 'NEW', 'MinhaSenha9');
      await digitar(wrapper, 'CONFIRM', 'MinhaSenha9');
    };
    const recusar = (code, error) =>
      changePassword.mockRejectedValue({ response: { data: { code, error } } });

    it('goes under the CURRENT password when it is the wrong one', async () => {
      const wrapper = montar();
      await preencher(wrapper);
      recusar('wrong_current', 'A senha atual está incorreta.');

      await salvar(wrapper);
      await flushPromises();

      expect(mensagemDe(wrapper, 'CURRENT').text()).toBe('A senha atual está incorreta.');
      expect(mensagemDe(wrapper, 'NEW').exists()).toBe(false);
    });

    it('goes under the NEW password for the rules about the new one', async () => {
      const wrapper = montar();
      await preencher(wrapper);
      recusar('same_as_default', 'Escolha uma senha diferente da senha padrão.');

      await salvar(wrapper);
      await flushPromises();

      expect(mensagemDe(wrapper, 'NEW').text()).toBe('Escolha uma senha diferente da senha padrão.');
    });

    it('shows an unknown refusal as a general notice instead of hiding it', async () => {
      const wrapper = montar();
      await preencher(wrapper);
      recusar('invalid', 'Não foi possível salvar a nova senha.');

      await salvar(wrapper);
      await flushPromises();

      expect(wrapper.find('[role="alert"]').text()).toBe('Não foi possível salvar a nova senha.');
    });
  });

  it('lets the person see what they are typing', async () => {
    const wrapper = montar();
    expect(campo(wrapper, 'NEW').find('input').attributes('type')).toBe('password');

    await wrapper.find('input[type="checkbox"]').setValue(true);

    expect(campo(wrapper, 'NEW').find('input').attributes('type')).toBe('text');
    expect(campo(wrapper, 'CONFIRM').find('input').attributes('type')).toBe('text');
  });
});
