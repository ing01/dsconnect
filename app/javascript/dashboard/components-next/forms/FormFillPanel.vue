<script setup>
/**
 * O formulario inteiro para preencher (titulo, descricao, perguntas, envio): a parte comum das duas
 * paginas da Central de Ajuda - a do cliente logado e a publica. Quem usa cuida da chamada ao
 * servidor e do que aparece depois do envio.
 */
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import FormFieldsFill from './FormFieldsFill.vue';
import { emptyAnswers, missingFields } from './formFields';

const props = defineProps({
  form: { type: Object, required: true },
  isSubmitting: { type: Boolean, default: false },
  // Formulario aberto: pede nome/e-mail (opcionais) e leva o campo isca contra robo.
  askRespondent: { type: Boolean, default: false },
  errorMessage: { type: String, default: '' },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const answers = ref(emptyAnswers(props.form.fields));
const files = ref({});
const respondentName = ref('');
const respondentEmail = ref('');
const trap = ref('');
const showErrors = ref(false);

const missing = computed(() =>
  missingFields(props.form.fields, answers.value, files.value).map(f => f.id)
);

// Formulario novo (outro id): comeca do zero.
watch(
  () => props.form.id,
  () => {
    answers.value = emptyAnswers(props.form.fields);
    files.value = {};
    showErrors.value = false;
  }
);

const submit = () => {
  showErrors.value = true;
  if (missing.value.length || props.isSubmitting) return;

  emit('submit', {
    answers: answers.value,
    files: files.value,
    respondentName: respondentName.value.trim(),
    respondentEmail: respondentEmail.value.trim(),
    trap: trap.value,
  });
};
</script>

<template>
  <form
    class="flex flex-col gap-5"
    novalidate
    data-testid="form-fill-panel"
    @submit.prevent="submit"
  >
    <header class="flex flex-col gap-1">
      <h1 class="m-0 text-2xl font-semibold text-n-slate-12">
        {{ form.name }}
      </h1>
      <p v-if="form.description" class="m-0 text-sm text-n-slate-11">
        {{ form.description }}
      </p>
      <p class="m-0 text-xs text-n-slate-11">
        {{ t('FORMS.FILL.REQUIRED_NOTE') }}
      </p>
    </header>

    <FormFieldsFill
      v-model:answers="answers"
      v-model:files="files"
      :fields="form.fields"
      :show-errors="showErrors"
      :missing-ids="missing"
    />

    <template v-if="askRespondent">
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 text-sm">
          <span class="text-n-slate-12">{{ t('FORMS.FILL.YOUR_NAME') }}</span>
          <input
            v-model="respondentName"
            type="text"
            maxlength="120"
            autocomplete="name"
            class="w-full mb-0 text-sm"
            data-testid="respondent-name"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm">
          <span class="text-n-slate-12">{{ t('FORMS.FILL.YOUR_EMAIL') }}</span>
          <input
            v-model="respondentEmail"
            type="email"
            maxlength="160"
            autocomplete="email"
            class="w-full mb-0 text-sm"
            data-testid="respondent-email"
          />
        </label>
      </div>
      <!-- Campo isca: invisivel para quem usa; robo costuma preencher tudo. -->
      <div class="absolute -start-[9999px]" aria-hidden="true">
        <input
          v-model="trap"
          type="text"
          name="website"
          tabindex="-1"
          autocomplete="off"
          data-testid="form-trap"
        />
      </div>
    </template>

    <p
      v-if="errorMessage"
      class="p-3 m-0 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
      role="alert"
      data-testid="form-error"
    >
      {{ errorMessage }}
    </p>

    <div>
      <Button
        type="submit"
        :label="isSubmitting ? t('FORMS.FILL.SENDING') : t('FORMS.FILL.SUBMIT')"
        :is-loading="isSubmitting"
        :disabled="isSubmitting"
        data-testid="form-submit"
      />
    </div>
  </form>
</template>
