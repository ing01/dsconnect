<script setup>
/**
 * A troca da senha padrão, no primeiro acesso.
 *
 * Diferente da definição por link de e-mail (`ClientPasswordEditPage`), esta tela
 * roda COM sessão: a pessoa acabou de entrar com a senha padrão que a equipe
 * entregou, e o servidor só aceita a troca de senha até ela acontecer. Por isso
 * pede a senha atual de novo, e fica fora do `ClientLayout` - o menu e o
 * cabeçalho leem dados que só são liberados depois da troca.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import {
  clearClientSession,
  hasClientSession,
  markClientPasswordChanged,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n({ useScope: 'global' });

// Mesmo mínimo do servidor (ContactClientAccess::MIN_CHANGED_PASSWORD_LENGTH).
const MIN_LENGTH = 8;

const atual = ref('');
const senha = ref('');
const confirmacao = ref('');
const isSaving = ref(false);
const erro = ref('');

// O botão NÃO fica desabilitado: um botão apagado não diz o que falta - o clique
// é que aponta.
const problema = () => {
  if (!atual.value) return t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.CURRENT');
  if (senha.value.length < MIN_LENGTH) {
    return t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.TOO_SHORT', {
      count: MIN_LENGTH,
    });
  }
  if (senha.value !== confirmacao.value) {
    return t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.MISMATCH');
  }
  return '';
};

const salvar = async () => {
  if (isSaving.value) return;

  const falta = problema();
  if (falta) {
    erro.value = falta;
    return;
  }

  erro.value = '';
  isSaving.value = true;
  try {
    await ClientAreaAPI.changePassword({
      currentPassword: atual.value,
      password: senha.value,
      passwordConfirmation: confirmacao.value,
    });
    markClientPasswordChanged();
    // Carga completa: o layout da área sobe do zero, já sem a trava.
    window.location.assign('/app/client/tickets');
  } catch (e) {
    // O servidor sabe qual regra falhou (senha atual errada, igual à padrão...).
    erro.value =
      e?.response?.data?.error || t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.GENERIC');
  } finally {
    isSaving.value = false;
  }
};

const sair = async () => {
  try {
    await ClientAreaAPI.logout();
  } catch {
    // Sair não pode depender do servidor responder.
  }
  clearClientSession();
  window.location.assign('/app/login');
};

// Sem sessão não há o que trocar.
if (!hasClientSession()) window.location.assign('/app/login');
</script>

<template>
  <div
    class="flex items-center justify-center w-full min-h-screen p-4 bg-n-background"
  >
    <div
      class="flex flex-col w-full max-w-md gap-4 p-6 border rounded-xl border-n-weak bg-n-solid-1"
    >
      <div class="flex flex-col gap-1">
        <h1 class="m-0 text-xl font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.PASSWORD_CHANGE.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CLIENT_AREA.PASSWORD_CHANGE.DESCRIPTION') }}
        </p>
      </div>

      <Input
        v-model="atual"
        type="password"
        :label="t('CLIENT_AREA.PASSWORD_CHANGE.CURRENT')"
        :placeholder="t('CLIENT_AREA.PASSWORD_CHANGE.CURRENT_PLACEHOLDER')"
        class="w-full"
        @keyup.enter="salvar"
      />

      <Input
        v-model="senha"
        type="password"
        :label="t('CLIENT_AREA.PASSWORD_CHANGE.NEW')"
        :placeholder="t('CLIENT_AREA.PASSWORD_CHANGE.NEW_PLACEHOLDER')"
        class="w-full"
        @keyup.enter="salvar"
      />

      <Input
        v-model="confirmacao"
        type="password"
        :label="t('CLIENT_AREA.PASSWORD_CHANGE.CONFIRM')"
        :placeholder="t('CLIENT_AREA.PASSWORD_CHANGE.CONFIRM_PLACEHOLDER')"
        :message="erro"
        :message-type="erro ? 'error' : 'info'"
        class="w-full"
        @keyup.enter="salvar"
      />

      <div class="flex flex-col gap-2">
        <Button
          :label="t('CLIENT_AREA.PASSWORD_CHANGE.SAVE')"
          :is-loading="isSaving"
          class="w-full"
          @click="salvar"
        />
        <Button
          variant="faded"
          color="slate"
          :label="t('CLIENT_AREA.PASSWORD_CHANGE.LOGOUT')"
          class="w-full"
          @click="sair"
        />
      </div>
    </div>
  </div>
</template>
