<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import HelpButton from 'dashboard/components-next/help/HelpButton.vue';

const props = defineProps({
  checklist: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.checklist);

const ITEM_TYPES = ['checkbox', 'text', 'single_select', 'number'];

const name = ref(props.checklist?.name || '');
const items = ref(
  (props.checklist?.items || []).map((item, idx) => ({
    id: idx,
    title: item.title || item,
    type: ITEM_TYPES.includes(item.type) ? item.type : 'checkbox',
    required: !!item.required,
    options: Array.isArray(item.options) ? [...item.options] : [],
  }))
);
const isSubmitting = ref(false);

// A new item is built up here (title, tipo, obrigatório e, se for seleção
// única, as opções) before it's added to `items` below - editar um item já
// adicionado não é suportado ainda: remove e adiciona de novo.
const newItem = ref({ title: '', type: 'checkbox', required: false });
const newItemOptions = ref([]);
const newOptionText = ref('');

const itemTypeLabel = type => t(`CHECKLISTS.FORM.ITEMS.TYPE.${type.toUpperCase()}`);

const addOption = () => {
  const text = newOptionText.value.trim();
  if (!text) return;
  newItemOptions.value.push(text);
  newOptionText.value = '';
};

const removeOption = index => {
  newItemOptions.value.splice(index, 1);
};

const addItem = () => {
  const title = newItem.value.title.trim();
  if (!title) return;
  if (newItem.value.type === 'single_select' && !newItemOptions.value.length) return;

  items.value.push({
    id: Date.now(),
    title,
    type: newItem.value.type,
    required: newItem.value.required,
    options: newItem.value.type === 'single_select' ? [...newItemOptions.value] : [],
  });

  newItem.value = { title: '', type: 'checkbox', required: false };
  newItemOptions.value = [];
};

const removeItem = index => {
  items.value.splice(index, 1);
};

const isFormValid = computed(() => !!name.value.trim());

const submit = async () => {
  if (!isFormValid.value || isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    const payload = {
      name: name.value.trim(),
      items: items.value.map(item => ({
        title: item.title,
        type: item.type,
        required: item.required,
        options: item.options,
      })),
    };

    if (isEditing.value) {
      await store.dispatch('checklists/update', { id: props.checklist.id, ...payload });
      useAlert(t('CHECKLISTS.EDIT.SUCCESS'));
    } else {
      await store.dispatch('checklists/create', payload);
      useAlert(t('CHECKLISTS.ADD.SUCCESS'));
    }

    emit('saved');
    emit('close');
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t(isEditing.value ? 'CHECKLISTS.EDIT.ERROR' : 'CHECKLISTS.ADD.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="isEditing ? t('CHECKLISTS.EDIT.TITLE') : t('CHECKLISTS.ADD.TITLE')"
    />
    <form class="flex-1 overflow-y-auto p-6 flex flex-col gap-5 min-h-0" @submit.prevent="submit">
      <div class="flex justify-end -mb-2">
        <HelpButton :title="t('PROJECTS.HELP.CHECKLIST.TITLE')">
          <p>{{ t('PROJECTS.HELP.CHECKLIST.INTRO') }}</p>
          <p>{{ t('PROJECTS.HELP.CHECKLIST.REQUIRED') }}</p>
        </HelpButton>
      </div>

      <NextInput
        v-model="name"
        :label="t('CHECKLISTS.FORM.NAME.LABEL')"
        :placeholder="t('CHECKLISTS.FORM.NAME.PLACEHOLDER')"
        required
      />

      <div class="flex flex-col gap-3 p-3.5 rounded-xl border border-n-weak bg-n-alpha-1">
        <label class="text-xs font-semibold text-n-slate-12">
          {{ t('CHECKLISTS.FORM.ITEMS.LABEL') }}
        </label>

        <ul v-if="items.length" class="flex flex-col gap-1.5">
          <li
            v-for="(item, idx) in items"
            :key="item.id"
            class="flex items-start justify-between gap-2 px-3 py-2 rounded-lg bg-n-solid-1 border border-n-weak text-xs text-n-slate-12"
          >
            <div class="flex flex-col gap-1 min-w-0">
              <div class="flex items-center gap-1.5 min-w-0">
                <Icon icon="i-lucide-check-square" class="size-3.5 text-n-slate-9 flex-shrink-0" />
                <span class="truncate font-medium">{{ item.title }}</span>
                <span v-if="item.required" class="text-n-ruby-11 flex-shrink-0">*</span>
              </div>
              <div class="flex items-center gap-1.5 flex-wrap">
                <span class="px-1.5 py-0.5 rounded bg-n-slate-3 text-[10px] text-n-slate-11">
                  {{ itemTypeLabel(item.type) }}
                </span>
                <span
                  v-for="(opt, optIdx) in item.options"
                  :key="optIdx"
                  class="px-1.5 py-0.5 rounded bg-n-slate-3 text-[10px] text-n-slate-10"
                >
                  {{ opt }}
                </span>
              </div>
            </div>
            <button
              type="button"
              class="text-n-ruby-11 hover:text-n-ruby-12 p-1 flex-shrink-0"
              @click="removeItem(idx)"
            >
              <Icon icon="i-lucide-trash-2" class="size-3.5" />
            </button>
          </li>
        </ul>
        <p v-else class="text-[11px] text-n-slate-10">
          {{ t('CHECKLISTS.FORM.ITEMS.EMPTY') }}
        </p>

        <!-- Builder do próximo item -->
        <div class="flex flex-col gap-2 pt-2 border-t border-n-weak">
          <div class="grid grid-cols-2 gap-2">
            <input
              v-model="newItem.title"
              type="text"
              class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
              :placeholder="t('CHECKLISTS.FORM.ITEMS.PLACEHOLDER')"
            />
            <select
              v-model="newItem.type"
              class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option v-for="type in ITEM_TYPES" :key="type" :value="type">
                {{ itemTypeLabel(type) }}
              </option>
            </select>
          </div>

          <!-- Opções (só para seleção única) -->
          <div v-if="newItem.type === 'single_select'" class="flex flex-col gap-1.5">
            <div class="flex gap-2">
              <input
                v-model="newOptionText"
                type="text"
                class="flex-1 h-8 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
                :placeholder="t('CHECKLISTS.FORM.ITEMS.OPTION_PLACEHOLDER')"
                @keydown.enter.prevent="addOption"
              />
              <NextButton
                size="xs"
                type="button"
                faded
                slate
                icon="i-lucide-plus"
                :label="t('CHECKLISTS.FORM.ITEMS.ADD_OPTION')"
                @click="addOption"
              />
            </div>
            <div v-if="newItemOptions.length" class="flex flex-wrap gap-1.5">
              <span
                v-for="(opt, optIdx) in newItemOptions"
                :key="optIdx"
                class="flex items-center gap-1 px-2 py-0.5 rounded bg-n-slate-3 text-[11px] text-n-slate-11"
              >
                {{ opt }}
                <button type="button" @click="removeOption(optIdx)">
                  <Icon icon="i-lucide-x" class="size-3" />
                </button>
              </span>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <label class="flex items-center gap-1.5 text-xs text-n-slate-11">
              <input v-model="newItem.required" type="checkbox" />
              {{ t('CHECKLISTS.FORM.ITEMS.REQUIRED') }}
            </label>
            <NextButton
              size="sm"
              type="button"
              icon="i-lucide-plus"
              :label="t('CHECKLISTS.FORM.ITEMS.ADD')"
              :disabled="
                !newItem.title.trim() ||
                (newItem.type === 'single_select' && !newItemOptions.length)
              "
              @click="addItem"
            />
          </div>
        </div>
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
          :label="isEditing ? t('CHECKLISTS.EDIT.SUBMIT') : t('CHECKLISTS.ADD.SUBMIT')"
          :disabled="!isFormValid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
