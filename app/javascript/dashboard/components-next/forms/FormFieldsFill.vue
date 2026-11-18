<script setup>
/**
 * As perguntas de um Formulario, para preencher. Compartilhado: o dialogo do artigo (agente), a
 * pagina do cliente logado e a pagina publica usam este mesmo desenho, entao um tipo de pergunta
 * novo se resolve num lugar so'.
 */
import { useI18n } from 'vue-i18n';
import { typeOf } from './formFields';

defineProps({
  fields: { type: Array, default: () => [] },
  // Marca as obrigatorias vazias (depois de uma tentativa de envio).
  showErrors: { type: Boolean, default: false },
  missingIds: { type: Array, default: () => [] },
});

const answers = defineModel('answers', { type: Object, required: true });
const files = defineModel('files', { type: Object, default: () => ({}) });

const { t } = useI18n();

const setAnswer = (id, value) => {
  answers.value = { ...answers.value, [id]: value };
};

const toggleOption = (field, option) => {
  const current = answers.value[field.id] || [];
  setAnswer(
    field.id,
    current.includes(option)
      ? current.filter(value => value !== option)
      : [...current, option]
  );
};

const onFile = (field, event) => {
  files.value = { ...files.value, [field.id]: event.target.files?.[0] || null };
};
</script>

<template>
  <div class="flex flex-col gap-4" data-testid="form-fields">
    <div
      v-for="field in fields"
      :key="field.id"
      class="flex flex-col gap-1.5 text-sm"
      :data-testid="`field-${field.id}`"
    >
      <span class="font-medium text-n-slate-12">
        {{ field.label }}
        <span v-if="field.required" class="text-n-ruby-11">*</span>
      </span>
      <span v-if="field.description" class="text-xs text-n-slate-11">
        {{ field.description }}
      </span>

      <input
        v-if="typeOf(field) === 'short_text'"
        :value="answers[field.id]"
        type="text"
        class="w-full mb-0 text-sm"
        @input="setAnswer(field.id, $event.target.value)"
      />
      <textarea
        v-else-if="typeOf(field) === 'paragraph'"
        :value="answers[field.id]"
        rows="3"
        class="w-full mb-0 text-sm"
        @input="setAnswer(field.id, $event.target.value)"
      />
      <input
        v-else-if="typeOf(field) === 'date'"
        :value="answers[field.id]"
        type="date"
        class="w-full mb-0 text-sm"
        @input="setAnswer(field.id, $event.target.value)"
      />
      <select
        v-else-if="typeOf(field) === 'dropdown'"
        :value="answers[field.id]"
        class="w-full mb-0 text-sm"
        @change="setAnswer(field.id, $event.target.value)"
      >
        <option value="">{{ t('FORMS.FILL.CHOOSE') }}</option>
        <option v-for="option in field.options" :key="option" :value="option">
          {{ option }}
        </option>
      </select>
      <div v-else-if="typeOf(field) === 'single_choice'" class="grid gap-1">
        <label
          v-for="option in field.options"
          :key="option"
          class="flex items-center gap-2"
        >
          <input
            type="radio"
            :name="`field-${field.id}`"
            :value="option"
            :checked="answers[field.id] === option"
            class="mb-0"
            @change="setAnswer(field.id, option)"
          />
          {{ option }}
        </label>
      </div>
      <div v-else-if="typeOf(field) === 'multiple_choice'" class="grid gap-1">
        <label
          v-for="option in field.options"
          :key="option"
          class="flex items-center gap-2"
        >
          <input
            type="checkbox"
            class="mb-0"
            :checked="(answers[field.id] || []).includes(option)"
            @change="toggleOption(field, option)"
          />
          {{ option }}
        </label>
      </div>
      <input
        v-else-if="typeOf(field) === 'file_upload'"
        type="file"
        class="w-full mb-0 text-sm"
        @change="onFile(field, $event)"
      />

      <span
        v-if="showErrors && missingIds.includes(field.id)"
        class="text-xs text-n-ruby-11"
        :data-testid="`error-${field.id}`"
      >
        {{ t('FORMS.FILL.REQUIRED_ERROR') }}
      </span>
    </div>
  </div>
</template>
