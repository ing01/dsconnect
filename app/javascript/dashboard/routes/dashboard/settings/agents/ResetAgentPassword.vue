<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  agent: { type: Object, required: true },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const password = ref('');
const isSaving = ref(false);

// O servidor aplica a regra de forca da senha (Devise); aqui so o comprimento,
// para o erro aparecer antes do envio.
const v$ = useVuelidate({ password: { required, minLength: minLength(8) } }, { password });

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
    // A recusa mais provavel e a do servidor quando o agente pertence a outra
    // conta tambem; a mensagem dele e mais util que uma generica.
    const message = error?.response?.data?.error;
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
