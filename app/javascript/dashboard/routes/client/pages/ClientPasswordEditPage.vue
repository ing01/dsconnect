<script setup>
/**
 * A definição da nova senha, pelo link do e-mail.
 *
 * É a única tela da Área do Cliente que roda SEM sessão: quem esqueceu a senha
 * não tem nenhuma, e quem autoriza é o token que veio no link. Por isso ela fica
 * fora do `ClientLayout` - o menu lateral e o cabeçalho leem o contato logado,
 * que aqui não existe.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n({ useScope: 'global' });
const route = useRoute();

const MIN_LENGTH = 6;

const token = computed(() => route.query.token || '');
const senha = ref('');
const confirmacao = ref('');
const isSaving = ref(false);
const erro = ref('');
const pronto = ref(false);

// O que falta, campo a campo. O botão NÃO fica desabilitado: um botão apagado
// não diz o que falta - o clique é que aponta.
const problema = () => {
  if (senha.value.length < MIN_LENGTH) {
    return t('CLIENT_AREA.PASSWORD.ERRORS.TOO_SHORT', { count: MIN_LENGTH });
  }
  if (senha.value !== confirmacao.value) {
    return t('CLIENT_AREA.PASSWORD.ERRORS.MISMATCH');
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
    await ClientAreaAPI.resetPassword({
      token: token.value,
      password: senha.value,
      passwordConfirmation: confirmacao.value,
    });
    pronto.value = true;
  } catch (e) {
    // O servidor é quem sabe se o link venceu ou já foi usado; a mensagem dele
    // é mais precisa do que qualquer suposição daqui.
    erro.value =
      e?.response?.data?.error || t('CLIENT_AREA.PASSWORD.ERRORS.GENERIC');
  } finally {
    isSaving.value = false;
  }
};

// Carga completa, e não navegação do router: a tela de login é servida pelo
// Rails, não é rota deste SPA.
const irParaLogin = () => window.location.assign('/app/login');

// Sem token não há o que fazer nesta tela - quem chegou aqui digitando a URL vai
// para o login, onde pode pedir um link novo.
onMounted(() => {
  if (!token.value) irParaLogin();
});
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
          {{ t('CLIENT_AREA.PASSWORD.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{
            pronto
              ? t('CLIENT_AREA.PASSWORD.DONE_DESCRIPTION')
              : t('CLIENT_AREA.PASSWORD.DESCRIPTION')
          }}
        </p>
      </div>

      <template v-if="!pronto">
        <Input
          v-model="senha"
          type="password"
          :label="t('CLIENT_AREA.PASSWORD.NEW')"
          :placeholder="t('CLIENT_AREA.PASSWORD.NEW_PLACEHOLDER')"
          class="w-full"
          @keyup.enter="salvar"
        />

        <Input
          v-model="confirmacao"
          type="password"
          :label="t('CLIENT_AREA.PASSWORD.CONFIRM')"
          :placeholder="t('CLIENT_AREA.PASSWORD.CONFIRM_PLACEHOLDER')"
          :message="erro"
          :message-type="erro ? 'error' : 'info'"
          class="w-full"
          @keyup.enter="salvar"
        />

        <Button
          :label="t('CLIENT_AREA.PASSWORD.SAVE')"
          :is-loading="isSaving"
          class="w-full"
          @click="salvar"
        />
      </template>

      <Button
        v-else
        :label="t('CLIENT_AREA.PASSWORD.GO_TO_LOGIN')"
        class="w-full"
        @click="irParaLogin"
      />
    </div>
  </div>
</template>
