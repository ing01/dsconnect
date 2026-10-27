<script setup>
/**
 * A Avaliação Mensal de satisfação, no Portal do Cliente.
 *
 * O texto de cada pergunta mora só aqui (i18n do frontend) - o servidor
 * nunca devolve texto traduzido, só as dez chaves estáveis em
 * `question_keys` (ver `MonthlySatisfactionSurvey::QUESTION_KEYS`). Por isso
 * o componente SEMPRE busca `question_keys`/`reference_month` de novo ao
 * abrir, em vez de receber isso por prop: é o que garante que a ordem e o
 * mês mostrados são sempre os do servidor no instante em que a pessoa abriu.
 *
 * Mesmo arranjo do `ClientManifestationDialog`/`ClientTicketDialog`: `Dialog`
 * de `components-next`, que emite `confirm` e nunca se fecha sozinho. Aqui
 * também ouve `@close` (Cancelar/Esc/clique fora) para marcar "adiada nesta
 * sessão" - ver `clientSession.js` - sem isso o modal reabriria a cada troca
 * de tela até a pessoa responder.
 *
 * A trava de "uma vez por mês" é só o SERVIDOR quem garante (ver o comentário
 * em `MonthlySatisfactionSurveys::SubmitService`) - aqui só se desabilita o
 * botão enquanto falta nota, e se trata com calma a recusa `already_answered`
 * se ela vier (ex.: a pessoa respondeu por outra aba enquanto este modal
 * estava aberto).
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import {
  getClientSession,
  setMonthlySurveyDismissed,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['answered']);

const { t } = useI18n({ useScope: 'global' });

const dialogRef = ref(null);
const etapa = ref('perguntas'); // 'perguntas' | 'obrigado'
const isLoading = ref(false);
const isSubmitting = ref(false);

const questionKeys = ref([]);
const referenceMonth = ref(null);
const respostas = ref({});
const comentario = ref('');

const notas = [1, 2, 3, 4, 5];

const isInvalid = computed(() =>
  questionKeys.value.some(chave => !respostas.value[chave])
);

const close = () => dialogRef.value?.close();

const onDialogClose = () => {
  // So' marca "adiada" se a pessoa saiu SEM responder - na tela de
  // agradecimento, fechar e' so' fechar, nao ha' nada para adiar.
  if (etapa.value !== 'perguntas') return;
  const contactId = getClientSession()?.contact?.id;
  setMonthlySurveyDismissed(contactId, referenceMonth.value);
};

const open = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClientAreaAPI.monthlySurveyStatus();
    if (data.answered) {
      // Corrida entre abas/dispositivos: outra sessao ja respondeu por este
      // contato neste mes. Nao ha' nada para mostrar.
      emit('answered');
      return;
    }

    questionKeys.value = data.question_keys;
    referenceMonth.value = data.reference_month;
    respostas.value = Object.fromEntries(
      data.question_keys.map(chave => [chave, null])
    );
    comentario.value = '';
    etapa.value = 'perguntas';

    dialogRef.value?.open();
  } catch {
    useAlert(t('CLIENT_AREA.MONTHLY_SURVEY.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const submit = async () => {
  if (isInvalid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await ClientAreaAPI.submitMonthlySurvey({
      answers: respostas.value,
      comment: comentario.value.trim() || null,
    });
    etapa.value = 'obrigado';
    emit('answered');
  } catch (error) {
    const resposta = error?.response?.data || {};
    if (resposta.code === 'already_answered') {
      useAlert(t('CLIENT_AREA.MONTHLY_SURVEY.ALREADY_ANSWERED'));
      emit('answered');
      close();
    } else if (resposta.code === 'invalid_answers') {
      useAlert(t('CLIENT_AREA.MONTHLY_SURVEY.ERRORS.INVALID_ANSWERS'));
    } else {
      useAlert(
        resposta.error ||
          resposta.message ||
          t('CLIENT_AREA.MONTHLY_SURVEY.ERROR')
      );
    }
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    overflow-y-auto
    :title="
      etapa === 'perguntas'
        ? t('CLIENT_AREA.MONTHLY_SURVEY.TITLE')
        : t('CLIENT_AREA.MONTHLY_SURVEY.THANKS_TITLE')
    "
    :description="
      etapa === 'perguntas' ? t('CLIENT_AREA.MONTHLY_SURVEY.DESCRIPTION') : ''
    "
    :confirm-button-label="t('CLIENT_AREA.MONTHLY_SURVEY.SUBMIT')"
    :cancel-button-label="
      etapa === 'perguntas'
        ? t('CLIENT_AREA.MONTHLY_SURVEY.LATER')
        : t('CLIENT_AREA.MONTHLY_SURVEY.CLOSE')
    "
    :show-cancel-button="etapa !== 'perguntas'"
    :show-confirm-button="etapa === 'perguntas'"
    :disable-confirm-button="isInvalid"
    :is-loading="isSubmitting"
    @confirm="submit"
    @close="onDialogClose"
  >
    <!-- Fecha sem precisar rolar até o rodapé. `order-first` põe a barra acima
         do título (o slot do Dialog vem depois dele) e `sticky` a mantém no
         topo enquanto as dez perguntas rolam. Nas perguntas, "Responder
         depois" mora aqui em cima e some do rodapé. -->
    <div
      class="sticky top-0 z-10 flex items-center justify-end gap-2 -mx-2 -mt-2 p-2 rounded-lg order-first bg-n-solid-2"
    >
      <Button
        v-if="etapa === 'perguntas'"
        faded
        slate
        size="sm"
        type="button"
        :label="t('CLIENT_AREA.MONTHLY_SURVEY.LATER')"
        @click="close"
      />
      <button
        type="button"
        class="flex items-center justify-center rounded-lg size-8 text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CLIENT_AREA.MONTHLY_SURVEY.CLOSE')"
        :title="t('CLIENT_AREA.MONTHLY_SURVEY.CLOSE')"
        @click="close"
      >
        <Icon icon="i-lucide-x" class="size-4" />
      </button>
    </div>

    <div v-if="etapa === 'perguntas'" class="flex flex-col gap-5 min-w-0">
      <div
        v-for="(chave, indice) in questionKeys"
        :key="chave"
        class="flex flex-col gap-2"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ indice + 1 }}.
          {{ t(`CLIENT_AREA.MONTHLY_SURVEY.QUESTIONS.${chave}`) }}
        </span>
        <div class="flex items-center gap-2 flex-wrap">
          <span class="text-xs text-n-slate-10 whitespace-nowrap">
            {{ t('CLIENT_AREA.MONTHLY_SURVEY.SCALE.WORST') }}
          </span>
          <div class="flex gap-1.5">
            <button
              v-for="nota in notas"
              :key="nota"
              type="button"
              class="flex items-center justify-center transition-colors border rounded-full size-9 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="
                respostas[chave] === nota
                  ? 'bg-n-brand text-white border-n-brand'
                  : 'bg-n-alpha-1 text-n-slate-11 border-n-weak hover:bg-n-alpha-2'
              "
              :aria-label="String(nota)"
              :aria-pressed="respostas[chave] === nota"
              @click="respostas[chave] = nota"
            >
              {{ nota }}
            </button>
          </div>
          <span class="text-xs text-n-slate-10 whitespace-nowrap">
            {{ t('CLIENT_AREA.MONTHLY_SURVEY.SCALE.BEST') }}
          </span>
        </div>
      </div>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.MONTHLY_SURVEY.COMMENT_LABEL') }}
        </span>
        <textarea
          v-model="comentario"
          rows="3"
          class="w-full mb-0"
          :placeholder="t('CLIENT_AREA.MONTHLY_SURVEY.COMMENT_PLACEHOLDER')"
        />
      </label>
    </div>

    <div v-else class="flex flex-col items-center gap-3 py-4 text-center">
      <Icon icon="i-lucide-circle-check" class="size-10 text-n-teal-9" />
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.MONTHLY_SURVEY.THANKS_DESCRIPTION') }}
      </p>
    </div>
  </Dialog>
</template>
