<script setup>
/**
 * Consultar (so' ver as perguntas) ou preencher um Formulario vinculado ao artigo, pelo painel.
 * O chamado e' opcional: informando o numero, a resposta fica no historico dele; sem numero, fica
 * guardada na lista de respostas do formulario (origem "Equipe").
 */
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import FormsAPI from 'dashboard/api/forms';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import FormFieldsFill from 'dashboard/components-next/forms/FormFieldsFill.vue';
import {
  emptyAnswers,
  missingFields,
} from 'dashboard/components-next/forms/formFields';

const { t } = useI18n();

const dialogRef = ref(null);
const form = ref(null);
const mode = ref('view');
const ticketNumber = ref('');
const answers = ref({});
const files = ref({});
const showErrors = ref(false);
const isSubmitting = ref(false);

const isFill = computed(() => mode.value === 'fill');
const fields = computed(() => form.value?.fields || []);
const missing = computed(() =>
  missingFields(fields.value, answers.value, files.value).map(f => f.id)
);

const open = (selectedForm, selectedMode = 'view') => {
  form.value = selectedForm;
  mode.value = selectedMode;
  ticketNumber.value = '';
  answers.value = emptyAnswers(selectedForm?.fields || []);
  files.value = {};
  showErrors.value = false;
  dialogRef.value?.open();
};

const submit = async () => {
  if (!isFill.value) {
    dialogRef.value?.close();
    return;
  }
  showErrors.value = true;
  if (missing.value.length || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await FormsAPI.fillResponse(form.value.id, {
      ticketDisplayId: ticketNumber.value.replace('#', '').trim(),
      answers: answers.value,
      files: files.value,
    });
    useAlert(
      form.value.success_message || t('HELP_CENTER.KB_TREE.FORM_DIALOG.SUCCESS')
    );
    dialogRef.value?.close();
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        parseAPIErrorResponse(error) ||
        t('HELP_CENTER.KB_TREE.FORM_DIALOG.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="
      t('HELP_CENTER.KB_TREE.FORM_DIALOG.TITLE', { name: form?.name || '' })
    "
    :description="form?.description || ''"
    :confirm-button-label="
      isFill
        ? t('HELP_CENTER.KB_TREE.FORM_DIALOG.SUBMIT')
        : t('HELP_CENTER.KB_TREE.FORM_DIALOG.CLOSE')
    "
    :show-cancel-button="isFill"
    :is-loading="isSubmitting"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4" data-testid="kb-form-dialog">
      <p v-if="!isFill" class="m-0 text-sm text-n-slate-11">
        {{ t('HELP_CENTER.KB_TREE.FORM_DIALOG.PREVIEW_HINT') }}
      </p>

      <label v-if="isFill" class="flex flex-col gap-1 text-sm">
        <span class="font-medium text-n-slate-12">
          {{ t('HELP_CENTER.KB_TREE.FORM_DIALOG.TICKET') }}
        </span>
        <input
          v-model="ticketNumber"
          type="text"
          inputmode="numeric"
          class="w-full mb-0 text-sm"
          :placeholder="t('HELP_CENTER.KB_TREE.FORM_DIALOG.TICKET_PLACEHOLDER')"
          data-testid="kb-form-ticket"
        />
        <span class="text-xs text-n-slate-11">
          {{ t('HELP_CENTER.KB_TREE.FORM_DIALOG.TICKET_HELP') }}
        </span>
      </label>

      <FormFieldsFill
        v-if="isFill"
        v-model:answers="answers"
        v-model:files="files"
        :fields="fields"
        :show-errors="showErrors"
        :missing-ids="missing"
      />

      <div v-else class="flex flex-col gap-3">
        <div
          v-for="field in fields"
          :key="field.id"
          class="flex flex-col gap-1 text-sm"
        >
          <span class="font-medium text-n-slate-12">
            {{ field.label }}
            <span v-if="field.required" class="text-n-ruby-11">*</span>
          </span>
          <span v-if="field.description" class="text-xs text-n-slate-11">
            {{ field.description }}
          </span>
          <ul
            v-if="field.options && field.options.length"
            class="m-0 text-xs list-disc ps-5 text-n-slate-11"
          >
            <li v-for="option in field.options" :key="option">{{ option }}</li>
          </ul>
        </div>
      </div>
    </div>
  </Dialog>
</template>
