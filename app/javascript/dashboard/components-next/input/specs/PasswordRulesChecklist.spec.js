import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import PasswordRulesChecklist from '../PasswordRulesChecklist.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'pt_BR',
  messages: {
    pt_BR: {
      PASSWORD_RULES: { TITLE: 'A senha precisa ter:', EXAMPLE: 'ex.' },
      REGISTER: {
        PASSWORD: {
          REQUIREMENTS_LENGTH: 'len',
          REQUIREMENTS_UPPERCASE: 'up',
          REQUIREMENTS_LOWERCASE: 'low',
          REQUIREMENTS_NUMBER: 'num',
          REQUIREMENTS_SPECIAL: 'esp',
        },
      },
    },
  },
});

const metRules = password => {
  const wrapper = mount(PasswordRulesChecklist, {
    props: { password },
    global: { plugins: [i18n] },
  });
  return ['length', 'uppercase', 'lowercase', 'number', 'special'].filter(
    id =>
      wrapper
        .find(`[data-testid="password-rule-${id}"]`)
        .attributes('data-met') === 'true'
  );
};

describe('PasswordRulesChecklist', () => {
  it('mostra todas as regras mesmo com a senha vazia', () => {
    expect(metRules('')).toEqual([]);
  });

  it('marca só o que a senha atende', () => {
    expect(metRules('senha1234')).toEqual(['length', 'lowercase', 'number']);
  });

  it('marca tudo com uma senha que cumpre a regra do servidor', () => {
    expect(metRules('Suporte@2026')).toEqual([
      'length',
      'uppercase',
      'lowercase',
      'number',
      'special',
    ]);
  });

  it('exige 6 caracteres, não 8', () => {
    expect(metRules('Ab1!x')).not.toContain('length');
    expect(metRules('Ab1!xy')).toContain('length');
  });
});
