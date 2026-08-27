import { mount } from '@vue/test-utils';
import DurationInput from '../DurationInput.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: () => '00:00' }) }));

const mountInput = (props = {}) =>
  mount(DurationInput, { props: { modelValue: '', ...props } });

// Digita caractere a caractere, como o usuário faria - a máscara reage a cada
// tecla, então colar o texto inteiro testaria outra coisa.
const type = async (wrapper, text) => {
  const input = wrapper.find('input');
  await [...text].reduce(
    (chain, char) =>
      chain.then(() => input.setValue(input.element.value + char)),
    Promise.resolve()
  );
  return input.element.value;
};

const lastEmitted = wrapper => {
  const events = wrapper.emitted('update:modelValue');
  return events ? events.at(-1)[0] : undefined;
};

describe('DurationInput', () => {
  it('inserts the colon while typing', async () => {
    const wrapper = mountInput();

    expect(await type(wrapper, '0130')).toBe('01:30');
    expect(lastEmitted(wrapper)).toBe('01:30');
  });

  // Os dois últimos dígitos são sempre os minutos, então as horas crescem à
  // esquerda - é o que permite prazo sem teto.
  it('lets hours grow past two digits', async () => {
    expect(await type(mountInput(), '3000')).toBe('30:00');
    expect(await type(mountInput(), '13000')).toBe('130:00');
  });

  it('ignores anything that is not a digit', async () => {
    const wrapper = mountInput();

    await wrapper.find('input').setValue('a1b:2c3d0');

    expect(wrapper.find('input').element.value).toBe('12:30');
  });

  it('completes a half-typed value on blur', async () => {
    const wrapper = mountInput();
    await type(wrapper, '95');

    await wrapper.find('input').trigger('blur');

    expect(lastEmitted(wrapper)).toBe('95:00');
  });

  it('pads a single leading hour digit on blur', async () => {
    const wrapper = mountInput();
    await type(wrapper, '905');

    await wrapper.find('input').trigger('blur');

    expect(lastEmitted(wrapper)).toBe('09:05');
  });

  // Vazio continua vazio: é assim que se diz "sem prazo".
  it('keeps an empty field empty', async () => {
    const wrapper = mountInput({ modelValue: '02:00' });

    await wrapper.find('input').setValue('');
    await wrapper.find('input').trigger('blur');

    expect(lastEmitted(wrapper)).toBe('');
  });

  describe('as a clock time', () => {
    // No expediente a hora é um horário, não uma duração: 25:00 não existe.
    // Digitando 2500, o dígito que levaria a hora a 25 é recusado e o campo
    // para em 2:50, em vez de aceitar um horário que não existe.
    it('refuses the digit that would push the hour past the ceiling', async () => {
      const wrapper = mountInput({ maxHours: 23 });

      expect(await type(wrapper, '2500')).toBe('2:50');
    });

    it('accepts the last valid hour', async () => {
      expect(await type(mountInput({ maxHours: 23 }), '2359')).toBe('23:59');
    });
  });

  it('shows the saved value it was given', () => {
    const wrapper = mountInput({ modelValue: '01:30' });

    expect(wrapper.find('input').element.value).toBe('01:30');
  });

  it('marks itself invalid for assistive tech', () => {
    const wrapper = mountInput({ invalid: true });

    expect(wrapper.find('input').attributes('aria-invalid')).toBe('true');
  });
});
