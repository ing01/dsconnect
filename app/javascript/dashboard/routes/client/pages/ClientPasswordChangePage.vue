<script setup>
/**
 * A troca da senha padrão, no primeiro acesso.
 *
 * Diferente da definição por link de e-mail (`ClientPasswordEditPage`), esta tela
 * roda COM sessão: a pessoa acabou de entrar com a senha padrão que a equipe
 * entregou, e o servidor só aceita a troca de senha até ela acontecer. Por isso
 * pede a senha atual de novo, e fica fora do `ClientLayout` - o menu e o
 * cabeçalho leem dados que só são liberados depois da troca.
 *
 * As REGRAS da nova senha aparecem na tela, numa lista que se marca enquanto a
 * pessoa digita: antes, só o "8 caracteres" estava dito, e quem escolhia uma senha
 * igual à padrão só descobria ao clicar em salvar - e com o erro embaixo do último
 * campo, longe do que estava errado.
 */
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import {
  clearClientSession,
  hasClientSession,
  markClientPasswordChanged,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n({ useScope: 'global' });

// Mesmo mínimo do servidor (ContactClientAccess::MIN_CHANGED_PASSWORD_LENGTH).
const MIN_LENGTH = 8;

// Qual campo cada recusa do servidor (`code` na resposta) pertence: a mensagem vai
// embaixo dele. O que não estiver aqui (ex.: `invalid`) vai para o aviso geral.
const CAMPO_DO_ERRO = {
  wrong_current: 'atual',
  too_short: 'senha',
  same_as_current: 'senha',
  same_as_default: 'senha',
  mismatch: 'confirmacao',
};

const atual = ref('');
const senha = ref('');
const confirmacao = ref('');
const mostrar = ref(false);
const isSaving = ref(false);
// Depois da primeira tentativa que falhou, o que ainda não foi cumprido fica em
// vermelho; antes, só neutro - ninguém quer ver erro numa tela que acabou de abrir.
const tentou = ref(false);
const erros = reactive({ atual: '', senha: '', confirmacao: '', geral: '' });

const tipo = computed(() => (mostrar.value ? 'text' : 'password'));

// O que a nova senha já cumpre. "Diferente da padrão" compara com o que foi
// digitado em "Senha atual": no primeiro acesso, é a própria senha padrão.
const cumpre = computed(() => ({
  tamanho: senha.value.length >= MIN_LENGTH,
  diferente: senha.value.length > 0 && senha.value !== atual.value,
  igual: confirmacao.value.length > 0 && confirmacao.value === senha.value,
}));

const requisitos = computed(() => [
  {
    chave: 'tamanho',
    texto: t('CLIENT_AREA.PASSWORD_CHANGE.REQUIREMENT_LENGTH', {
      count: MIN_LENGTH,
    }),
  },
  {
    chave: 'diferente',
    texto: t('CLIENT_AREA.PASSWORD_CHANGE.REQUIREMENT_DIFFERENT'),
  },
  {
    chave: 'igual',
    texto: t('CLIENT_AREA.PASSWORD_CHANGE.REQUIREMENT_MATCH'),
  },
]);

const estado = chave => {
  if (cumpre.value[chave]) return 'ok';
  return tentou.value ? 'falta' : 'neutro';
};

const ICONE = {
  ok: 'i-lucide-circle-check',
  falta: 'i-lucide-circle-x',
  neutro: 'i-lucide-circle',
};
const COR = {
  ok: 'text-n-teal-11',
  falta: 'text-n-ruby-11',
  neutro: 'text-n-slate-10',
};

const limparErros = () => {
  Object.assign(erros, { atual: '', senha: '', confirmacao: '', geral: '' });
};

// O botão NÃO fica desabilitado: um botão apagado não diz o que falta - o clique
// é que aponta, e agora aponta o campo.
const problema = () => {
  if (!atual.value) {
    return { campo: 'atual', texto: t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.CURRENT') };
  }
  if (senha.value.length < MIN_LENGTH) {
    return {
      campo: 'senha',
      texto: t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.TOO_SHORT', {
        count: MIN_LENGTH,
      }),
    };
  }
  if (senha.value === atual.value) {
    return {
      campo: 'senha',
      texto: t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.SAME_AS_DEFAULT'),
    };
  }
  if (senha.value !== confirmacao.value) {
    return {
      campo: 'confirmacao',
      texto: t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.MISMATCH'),
    };
  }
  return null;
};

const salvar = async () => {
  if (isSaving.value) return;

  limparErros();
  const falta = problema();
  if (falta) {
    tentou.value = true;
    erros[falta.campo] = falta.texto;
    return;
  }

  isSaving.value = true;
  try {
    await ClientAreaAPI.changePassword({
      currentPassword: atual.value,
      password: senha.value,
      passwordConfirmation: confirmacao.value,
    });
    markClientPasswordChanged();
    // Carga completa: o layout da área sobe do zero, já sem a trava.
    window.location.assign('/app/client');
  } catch (e) {
    tentou.value = true;
    // O servidor sabe qual regra falhou (senha atual errada, igual à padrão...) e diz
    // em `code`; a mensagem vai embaixo do campo dela.
    const dados = e?.response?.data || {};
    const campo = CAMPO_DO_ERRO[dados.code] || 'geral';
    erros[campo] =
      dados.error || t('CLIENT_AREA.PASSWORD_CHANGE.ERRORS.GENERIC');
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

const tipoDaMensagem = campo => (erros[campo] ? 'error' : 'info');

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
        :type="tipo"
        :label="t('CLIENT_AREA.PASSWORD_CHANGE.CURRENT')"
        :placeholder="t('CLIENT_AREA.PASSWORD_CHANGE.CURRENT_PLACEHOLDER')"
        :message="erros.atual"
        :message-type="tipoDaMensagem('atual')"
        class="w-full"
        @keyup.enter="salvar"
      />

      <div class="flex flex-col gap-2">
        <Input
          v-model="senha"
          :type="tipo"
          :label="t('CLIENT_AREA.PASSWORD_CHANGE.NEW')"
          :placeholder="t('CLIENT_AREA.PASSWORD_CHANGE.NEW_PLACEHOLDER')"
          :message="erros.senha"
          :message-type="tipoDaMensagem('senha')"
          class="w-full"
          @keyup.enter="salvar"
        />

        <!-- O que a senha precisa ter: cada item se marca sozinho enquanto a pessoa
             digita. São exatamente as regras que o servidor aplica. -->
        <div
          class="flex flex-col gap-1.5 p-3 border rounded-lg border-n-weak bg-n-alpha-black2"
        >
          <p class="m-0 text-xs font-medium text-n-slate-11">
            {{ t('CLIENT_AREA.PASSWORD_CHANGE.REQUIREMENTS_TITLE') }}
          </p>
          <ul class="flex flex-col gap-1 m-0 list-none">
            <li
              v-for="requisito in requisitos"
              :key="requisito.chave"
              class="flex items-center gap-2 text-sm"
              :class="COR[estado(requisito.chave)]"
              :data-requisito="requisito.chave"
              :data-estado="estado(requisito.chave)"
            >
              <Icon
                :icon="ICONE[estado(requisito.chave)]"
                class="flex-shrink-0 size-4"
              />
              {{ requisito.texto }}
            </li>
          </ul>
        </div>
      </div>

      <Input
        v-model="confirmacao"
        :type="tipo"
        :label="t('CLIENT_AREA.PASSWORD_CHANGE.CONFIRM')"
        :placeholder="t('CLIENT_AREA.PASSWORD_CHANGE.CONFIRM_PLACEHOLDER')"
        :message="erros.confirmacao"
        :message-type="tipoDaMensagem('confirmacao')"
        class="w-full"
        @keyup.enter="salvar"
      />

      <!-- Senha escondida é o jeito mais comum de errar a confirmação. -->
      <label class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-11">
        <input v-model="mostrar" type="checkbox" class="mb-0" />
        {{ t('CLIENT_AREA.PASSWORD_CHANGE.SHOW_PASSWORDS') }}
      </label>

      <p v-if="erros.geral" class="m-0 text-sm text-n-ruby-11" role="alert">
        {{ erros.geral }}
      </p>

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
