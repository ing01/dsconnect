<script setup>
import { ref, reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import FormsAPI from 'dashboard/api/forms';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
  item: { type: Object, default: null },
});

const emit = defineEmits(['filled']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const isSubmitting = ref(false);
const answers = reactive({});
const files = reactive({});
const response = ref(null);
const isLoadingResponse = ref(false);

const fields = computed(() => props.item?.form_fields || []);
const isReadOnly = computed(() => !!props.item?.completed);

const answerFor = fieldId =>
  response.value?.answers?.find(answer => answer.field_id === fieldId);

const loadResponse = async () => {
  if (!isReadOnly.value || !props.item?.form_id || !props.item?.form_response_id) {
    response.value = null;
    return;
  }

  isLoadingResponse.value = true;
  try {
    const { data } = await FormsAPI.getResponse(
      props.item.form_id,
      props.item.form_response_id
    );
    response.value = data;
  } finally {
    isLoadingResponse.value = false;
  }
};

const resetForm = () => {
  Object.keys(answers).forEach(key => delete answers[key]);
  Object.keys(files).forEach(key => delete files[key]);
  fields.value.forEach(field => {
    answers[field.id] = field.field_type === 'multiple_choice' ? [] : '';
  });
};

const toggleMultipleChoiceOption = (field, option) => {
  const current = answers[field.id] || [];
  answers[field.id] = current.includes(option)
    ? current.filter(value => value !== option)
    : [...current, option];
};

const handleFileChange = (field, event) => {
  files[field.id] = event.target.files?.[0] || null;
};

const canSubmit = computed(() =>
  fields.value.every(field => {
    if (!field.required) return true;
    if (field.field_type === 'file_upload') return !!files[field.id];
    if (field.field_type === 'multiple_choice') {
      return (answers[field.id] || []).length > 0;
    }
    return !!String(answers[field.id] || '').trim();
  })
);

const open = () => {
  resetForm();
  loadResponse();
  dialogRef.value?.open();
};

const submit = async () => {
  if (!canSubmit.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await store.dispatch('ticketChecklistItems/fillForm', {
      ticketId: props.ticketId,
      itemId: props.item.id,
      answers: { ...answers },
      files: { ...files },
    });
    emit('filled');
    dialogRef.value?.close();
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.DETAIL.CHECKLISTS.FORM.SUBMIT_ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

watch(() => props.item?.id, resetForm);

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="item?.form_name"
    :show-confirm-button="!isReadOnly"
    :confirm-button-label="t('TICKET.DETAIL.CHECKLISTS.FORM.SUBMIT')"
    :is-loading="isSubmitting"
    :disable-confirm-button="!canSubmit"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <div
        v-for="field in fields"
        :key="field.id"
        class="flex flex-col gap-1 min-w-0"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ field.label }}<span v-if="field.required" class="text-n-ruby-11">*</span>
        </span>
        <span v-if="field.description" class="text-xs text-n-slate-10">
          {{ field.description }}
        </span>

        <!-- Leitura (ja preenchido) -->
        <template v-if="isReadOnly">
          <p v-if="field.field_type !== 'file_upload'" class="text-sm text-n-slate-11">
            {{
              Array.isArray(answerFor(field.id)?.value)
                ? answerFor(field.id)?.value.join(', ')
                : answerFor(field.id)?.value || '—'
            }}
          </p>
          <a
            v-else-if="answerFor(field.id)?.file_url"
            :href="answerFor(field.id).file_url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1.5 w-fit px-2 py-1 text-xs border rounded-md border-n-weak text-n-slate-11 hover:text-n-brand"
          >
            <Icon icon="i-lucide-paperclip" class="size-3" />
            {{ answerFor(field.id).filename }}
          </a>
          <p v-else class="text-sm text-n-slate-10">—</p>
        </template>

        <!-- Preenchimento -->
        <template v-else>
          <input
            v-if="field.field_type === 'short_text'"
            v-model="answers[field.id]"
            type="text"
            class="w-full mb-0 text-sm"
          />
          <textarea
            v-else-if="field.field_type === 'paragraph'"
            v-model="answers[field.id]"
            rows="3"
            class="w-full mb-0 text-sm resize-y"
          />
          <div v-else-if="field.field_type === 'single_choice'" class="flex flex-col gap-1">
            <label
              v-for="option in field.options"
              :key="option"
              class="flex items-center gap-2 text-sm cursor-pointer"
            >
              <input
                v-model="answers[field.id]"
                type="radio"
                :name="field.id"
                :value="option"
              />
              {{ option }}
            </label>
          </div>
          <div v-else-if="field.field_type === 'multiple_choice'" class="flex flex-col gap-1">
            <label
              v-for="option in field.options"
              :key="option"
              class="flex items-center gap-2 text-sm cursor-pointer"
            >
              <input
                type="checkbox"
                :checked="(answers[field.id] || []).includes(option)"
                @change="toggleMultipleChoiceOption(field, option)"
              />
              {{ option }}
            </label>
          </div>
          <select
            v-else-if="field.field_type === 'dropdown'"
            v-model="answers[field.id]"
            class="w-full mb-0 text-sm"
          >
            <option value="" />
            <option v-for="option in field.options" :key="option" :value="option">
              {{ option }}
            </option>
          </select>
          <input
            v-else-if="field.field_type === 'date'"
            v-model="answers[field.id]"
            type="date"
            class="w-full mb-0 text-sm"
          />
          <input
            v-else-if="field.field_type === 'file_upload'"
            type="file"
            class="text-sm"
            @change="handleFileChange(field, $event)"
          />
        </template>
      </div>

      <p v-if="!fields.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.CHECKLISTS.FORM.EMPTY') }}
      </p>
    </div>
  </Dialog>
</template>
