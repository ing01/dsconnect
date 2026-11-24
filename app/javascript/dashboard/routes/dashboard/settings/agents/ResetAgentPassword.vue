<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, helpers } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  agent: { type: Object, required: true },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const password = ref('');
const isSaving = ref(false);

// Mesma regra do servidor (Devise: config/initializers/secure_password.rb):
// 8+ caracteres com maiuscula, minuscula, numero e caractere especial. Validar
// aqui evita o envio e mostra a regra completa em vez de um erro generico.
const hasRequiredContent = value =>
  /[A-Z]/.test(value) &&
  /[a-z]/.test(value) &&
  /[0-9]/.test(value) &&
  /[^A-Za-z0-9]/.test(value);

const v$ = useVuelidate(
  {
    password: {
      required,
      minLength: minLength(8),
      content: helpers.withMessage('', hasRequiredContent),
    },
  },
  { password }
);

const submit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid || isSaving.value) return;

  isSaving.value = true;
  try {
    await store.dispatch('agents/resetPassword', {
      agentId: props.agent.id,
      password: password.value,
    });
    useAlert(t('AGENT_MGMT.RESET_PASSWORD.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    // O servidor explica a recusa: `error` (agente de outra conta) ou `message`
    // (senha fora da regra de forca). A dele e mais util que uma generica.
    const data = error?.response?.data;
    const message = data?.error || data?.message;
    useAlert(message || t('AGENT_MGMT.RESET_PASSWORD.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.RESET_PASSWORD.TITLE')"
      :header-content="
        $t('AGENT_MGMT.RESET_PASSWORD.DESC', { name: agent.name })
      "
    />
    <form class="flex flex-col w-full" @submit.prevent="submit">
      <div class="w-full">
        <label :class="{ error: v$.password.$error }">
          {{ $t('AGENT_MGMT.RESET_PASSWORD.FORM.PASSWORD.LABEL') }}
          <input
            v-model="password"
            type="password"
            autocomplete="new-password"
            :placeholder="
              $t('AGENT_MGMT.RESET_PASSWORD.FORM.PASSWORD.PLACEHOLDER')
            "
            @input="v$.password.$touch"
          />
          <span v-if="v$.password.$error" class="message">
            {{ $t('AGENT_MGMT.RESET_PASSWORD.FORM.PASSWORD.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.RESET_PASSWORD.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.RESET_PASSWORD.SUBMIT')"
          :is-loading="isSaving"
          :disabled="v$.$invalid || isSaving"
        />
      </div>
    </form>
  </div>
</template>
