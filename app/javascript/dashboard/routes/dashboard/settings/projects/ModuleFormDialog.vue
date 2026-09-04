<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  projectModule: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.projectModule);

const name = ref(props.projectModule?.name || '');
const description = ref(props.projectModule?.description || '');
// Ordered list of selected task_template ids - the order here is what
// ProjectModulesController#sync_task_templates! persists as `position`, and
// what ProjectCreateDialog later reviews tasks in.
const selectedIds = ref(
  (props.projectModule?.task_templates || []).map(template => template.id)
);
const isSubmitting = ref(false);

const taskTemplates = computed(
  () => store.getters['projectTaskTemplates/getTaskTemplates'] || []
);

const selectedTemplates = computed(() =>
  selectedIds.value
    .map(id => taskTemplates.value.find(template => template.id === id))
    .filter(Boolean)
);

const availableTemplates = computed(() =>
  taskTemplates.value.filter(
    template => !selectedIds.value.includes(template.id)
  )
);

onMounted(() => {
  store.dispatch('projectTaskTemplates/get');
});

const addTemplate = id => {
  if (!id || selectedIds.value.includes(id)) return;
  selectedIds.value = [...selectedIds.value, id];
};

const removeTemplate = id => {
  selectedIds.value = selectedIds.value.filter(
    templateId => templateId !== id
  );
};

const moveTemplate = (index, delta) => {
  const target = index + delta;
  if (target < 0 || target >= selectedIds.value.length) return;
  const next = [...selectedIds.value];
  [next[index], next[target]] = [next[target], next[index]];
  selectedIds.value = next;
};

const isFormValid = computed(() => !!name.value.trim());

const submit = async () => {
  if (!isFormValid.value || isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    const payload = {
      name: name.value.trim(),
      description: description.value.trim(),
      task_template_ids: selectedIds.value,
    };

    if (isEditing.value) {
      await store.dispatch('projectModules/update', {
        id: props.projectModule.id,
        ...payload,
      });
      useAlert(t('PROJECT_MODULES.EDIT.SUCCESS'));
    } else {
      await store.dispatch('projectModules/create', payload);
      useAlert(t('PROJECT_MODULES.ADD.SUCCESS'));
    }

    emit('saved');
    emit('close');
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t(isEditing.value ? 'PROJECT_MODULES.EDIT.ERROR' : 'PROJECT_MODULES.ADD.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="
        isEditing ? t('PROJECT_MODULES.EDIT.TITLE') : t('PROJECT_MODULES.ADD.TITLE')
      "
    />
    <form class="flex-1 overflow-y-auto p-6 flex flex-col gap-5 min-h-0" @submit.prevent="submit">
      <NextInput
        v-model="name"
        :label="t('PROJECT_MODULES.FORM.NAME.LABEL')"
        :placeholder="t('PROJECT_MODULES.FORM.NAME.PLACEHOLDER')"
        required
      />

      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-12">
          {{ t('PROJECT_MODULES.FORM.DESCRIPTION.LABEL') }}
        </label>
        <textarea
          v-model="description"
          rows="2"
          class="w-full p-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none resize-none"
          :placeholder="t('PROJECT_MODULES.FORM.DESCRIPTION.PLACEHOLDER')"
        />
      </div>

      <div class="flex flex-col gap-2 p-3.5 rounded-xl border border-n-weak bg-n-alpha-1">
        <label class="text-xs font-semibold text-n-slate-12">
          {{ t('PROJECT_MODULES.FORM.TASKS.LABEL') }}
        </label>
        <p class="text-[11px] text-n-slate-10">
          {{ t('PROJECT_MODULES.FORM.TASKS.HINT') }}
        </p>

        <select
          class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
          :disabled="!availableTemplates.length"
          @change="
            addTemplate(Number($event.target.value));
            $event.target.value = '';
          "
        >
          <option value="">
            {{
              availableTemplates.length
                ? t('PROJECT_MODULES.FORM.TASKS.LABEL')
                : t('PROJECT_MODULES.FORM.TASKS.EMPTY')
            }}
          </option>
          <option
            v-for="template in availableTemplates"
            :key="template.id"
            :value="template.id"
          >
            {{ template.name }}
          </option>
        </select>

        <ul v-if="selectedTemplates.length" class="flex flex-col gap-1.5 mt-1">
          <li
            v-for="(template, idx) in selectedTemplates"
            :key="template.id"
            class="flex items-center justify-between gap-2 px-3 py-1.5 rounded-lg bg-n-solid-1 border border-n-weak text-xs text-n-slate-12"
          >
            <span class="truncate flex-1">{{ idx + 1 }}. {{ template.name }}</span>
            <div class="flex items-center gap-1 flex-shrink-0">
              <button
                type="button"
                class="p-1 text-n-slate-9 hover:text-n-slate-12 disabled:opacity-30"
                :disabled="idx === 0"
                @click="moveTemplate(idx, -1)"
              >
                <Icon icon="i-lucide-arrow-up" class="size-3.5" />
              </button>
              <button
                type="button"
                class="p-1 text-n-slate-9 hover:text-n-slate-12 disabled:opacity-30"
                :disabled="idx === selectedTemplates.length - 1"
                @click="moveTemplate(idx, 1)"
              >
                <Icon icon="i-lucide-arrow-down" class="size-3.5" />
              </button>
              <button
                type="button"
                class="p-1 text-n-ruby-11 hover:text-n-ruby-12"
                @click="removeTemplate(template.id)"
              >
                <Icon icon="i-lucide-trash-2" class="size-3.5" />
              </button>
            </div>
          </li>
        </ul>
      </div>

      <div class="flex justify-end gap-2 pt-5 border-t border-n-weak">
        <NextButton
          faded
          slate
          type="button"
          :label="t('PROJECTS.FORM.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="submit"
          :label="
            isEditing ? t('PROJECT_MODULES.EDIT.SUBMIT') : t('PROJECT_MODULES.ADD.SUBMIT')
          "
          :disabled="!isFormValid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
