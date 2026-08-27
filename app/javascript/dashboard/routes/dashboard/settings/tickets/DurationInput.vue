<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

/**
 * Campo de hora com máscara `00:00`.
 *
 * Só aceita dígitos: os dois últimos são sempre os minutos e o resto são as
 * horas, então digitar `3000` vira `30:00` e `13000` vira `130:00`. É isso que
 * permite prazos sem teto de horas sem precisar de um segundo formato.
 */
const props = defineProps({
  modelValue: { type: String, default: '' },
  // Usado pelo expediente, onde a hora é um horário do relógio e não uma
  // duração. Nulo (o padrão) significa horas sem teto.
  maxHours: { type: Number, default: null },
  invalid: { type: Boolean, default: false },
  ariaLabel: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const inputRef = ref(null);
// O texto exibido. Fica separado do modelo para que digitar nunca seja
// interrompido por uma reformatação vinda de fora.
const display = ref(props.modelValue ?? '');

watch(
  () => props.modelValue,
  value => {
    if ((value ?? '') !== display.value) display.value = value ?? '';
  }
);

const MAX_DIGITS = 6;

/**
 * Formata uma sequência de dígitos como `HH:MM`.
 * @param {string} digits apenas dígitos
 * @returns {string} texto com os dois pontos no lugar
 */
const format = digits => {
  if (!digits) return '';
  // Até dois dígitos ainda são só as horas sendo digitadas.
  if (digits.length <= 2) return digits;

  const minutes = digits.slice(-2);
  const hours = digits.slice(0, -2);
  return `${hours}:${minutes}`;
};

/**
 * Aplica os limites do campo aos dígitos digitados.
 * @param {string} digits apenas dígitos
 * @returns {string} dígitos dentro dos limites
 */
const clamp = digits => {
  const trimmed = digits.slice(0, MAX_DIGITS);
  if (trimmed.length <= 2 || props.maxHours === null) return trimmed;

  // Num horário de relógio, `2500` não existe - o dígito que estouraria a hora
  // simplesmente não entra, em vez de virar um valor que o usuário não pediu.
  const hours = Number(trimmed.slice(0, -2));
  return hours > props.maxHours ? digits.slice(0, digits.length - 1) : trimmed;
};

const onInput = event => {
  const digits = clamp(event.target.value.replace(/\D/g, ''));
  display.value = format(digits);
  // O campo é curto e a digitação é da esquerda para a direita, então manter o
  // cursor no fim evita que ele salte quando os dois pontos entram.
  if (inputRef.value) {
    inputRef.value.value = display.value;
    inputRef.value.setSelectionRange(
      display.value.length,
      display.value.length
    );
  }
  emit('update:modelValue', display.value);
};

// Ao sair do campo, `9:5` vira `09:05`: o que ficou pela metade é completado,
// e o campo vazio continua vazio, que é como se diz "sem prazo".
const onBlur = () => {
  const digits = display.value.replace(/\D/g, '');
  if (!digits) {
    display.value = '';
    emit('update:modelValue', '');
    return;
  }

  const minutes = digits.length <= 2 ? '00' : digits.slice(-2).padStart(2, '0');
  const hours = digits.length <= 2 ? digits : digits.slice(0, -2);
  display.value = `${hours.padStart(2, '0')}:${minutes}`;
  emit('update:modelValue', display.value);
};

const classes = computed(() => ({ error: props.invalid }));
</script>

<template>
  <input
    ref="inputRef"
    :value="display"
    type="text"
    inputmode="numeric"
    autocomplete="off"
    :placeholder="t('TICKET.SETTINGS.FORM.STAGE_SLA.PLACEHOLDER')"
    :aria-label="ariaLabel || undefined"
    :aria-invalid="invalid || undefined"
    class="w-24 mb-0 tabular-nums"
    :class="classes"
    @input="onInput"
    @blur="onBlur"
  />
</template>
