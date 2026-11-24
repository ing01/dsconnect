<script setup>
/**
 * Regras da senha, SEMPRE visíveis embaixo do campo (não só ao focar), cada uma
 * marcada quando atendida. É a mesma regra do servidor (Devise):
 * 6+ caracteres com maiúscula, minúscula, número e caractere especial.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  password: { type: String, default: '' },
});

const MIN_LENGTH = 6;
const SPECIAL_CHAR = /[!@#$%^&*()_+\-=[\]{}|'"/.,\\`<>:;?~]/;

const { t } = useI18n();

const rules = computed(() => {
  const value = props.password || '';
  return [
    {
      id: 'length',
      met: value.length >= MIN_LENGTH,
      label: t('REGISTER.PASSWORD.REQUIREMENTS_LENGTH'),
    },
    {
      id: 'uppercase',
      met: /[A-Z]/.test(value),
      label: t('REGISTER.PASSWORD.REQUIREMENTS_UPPERCASE'),
    },
    {
      id: 'lowercase',
      met: /[a-z]/.test(value),
      label: t('REGISTER.PASSWORD.REQUIREMENTS_LOWERCASE'),
    },
    {
      id: 'number',
      met: /[0-9]/.test(value),
      label: t('REGISTER.PASSWORD.REQUIREMENTS_NUMBER'),
    },
    {
      id: 'special',
      met: SPECIAL_CHAR.test(value),
      label: t('REGISTER.PASSWORD.REQUIREMENTS_SPECIAL'),
    },
  ];
});
</script>

<template>
  <div
    class="flex flex-col gap-1.5 px-3 py-2.5 mb-4 text-sm border rounded-xl border-n-weak bg-n-alpha-1"
    data-testid="password-rules"
  >
    <p class="m-0 font-medium text-n-slate-12">
      {{ t('PASSWORD_RULES.TITLE') }}
    </p>
    <ul class="flex flex-col gap-1 p-0 m-0 list-none">
      <li
        v-for="rule in rules"
        :key="rule.id"
        class="flex items-center gap-2"
        :class="rule.met ? 'text-n-teal-11' : 'text-n-slate-11'"
        :data-testid="`password-rule-${rule.id}`"
        :data-met="rule.met"
      >
        <span
          class="block size-4 shrink-0"
          :class="rule.met ? 'i-lucide-circle-check-big' : 'i-lucide-circle'"
          aria-hidden="true"
        />
        {{ rule.label }}
      </li>
    </ul>
    <p class="m-0 text-xs text-n-slate-11">
      {{ t('PASSWORD_RULES.EXAMPLE') }}
    </p>
  </div>
</template>
