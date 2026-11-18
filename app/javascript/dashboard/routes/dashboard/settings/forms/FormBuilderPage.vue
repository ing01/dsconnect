<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();

const FIELD_TYPES = [
  'short_text',
  'paragraph',
  'single_choice',
  'multiple_choice',
  'dropdown',
  'date',
  'file_upload',
];
const CHOICE_TYPES = ['single_choice', 'multiple_choice', 'dropdown'];

const fieldTypeOptions = computed(() =>
  FIELD_TYPES.map(value => ({
    value,
    label: t(`FORMS.BUILDER.FIELD_TYPES.${value.toUpperCase()}`),
  }))
);

const isNew = computed(() => route.name === 'forms_new');
const formId = computed(() => route.params.formId);

const form = reactive({
  name: '',
  description: '',
  status: 'draft',
  article_id: null,
  access_mode: 'login',
  success_message: '',
  fields: [],
});
const isSaving = ref(false);
const activeTab = ref('questions');

const existingForm = computed(() =>
  isNew.value ? null : getters['forms/getFormById'].value(formId.value)
);
const responses = computed(() =>
  isNew.value ? [] : getters['forms/getResponsesByForm'].value(formId.value)
);
const articles = computed(() => store.getters['articles/allArticles'] || []);
// So' o primeiro Portal, de proposito: este seletor e' so' pra apontar o
// Formulario pro Artigo/POP que ele documenta, nao precisa cobrir conta com
// varios Portais na v1.
const fetchArticlesForFirstPortal = async () => {
  await store.dispatch('portals/index');
  const firstPortal = store.getters['portals/allPortals']?.[0];
  if (!firstPortal) return;

  store.dispatch('articles/index', {
    portalSlug: firstPortal.slug,
    pageNumber: 1,
  });
};

const syncForm = source => {
  form.name = source?.name || '';
  form.description = source?.description || '';
  form.status = source?.status || 'draft';
  form.article_id = source?.article_id || null;
  form.access_mode = source?.access_mode || 'login';
  form.success_message = source?.success_message || '';
  form.fields = (source?.fields || []).map(field => ({ ...field }));
};

const newFieldId = () =>
  `f_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

const addField = fieldType => {
  form.fields.push({
    id: newFieldId(),
    label: '',
    description: '',
    field_type: fieldType,
    required: false,
    options: CHOICE_TYPES.includes(fieldType) ? [''] : [],
  });
};

const duplicateField = index => {
  const copy = { ...form.fields[index], id: newFieldId() };
  form.fields.splice(index + 1, 0, copy);
};

const removeField = index => {
  form.fields.splice(index, 1);
};

const addOption = field => {
  field.options.push('');
};
const removeOption = (field, index) => {
  field.options.splice(index, 1);
};

const isChoiceType = fieldType => CHOICE_TYPES.includes(fieldType);

const canSave = computed(() => !!form.name.trim());

const save = async publish => {
  if (!canSave.value || isSaving.value) return;

  isSaving.value = true;
  try {
    const payload = {
      name: form.name.trim(),
      description: form.description,
      status: publish ? 'published' : form.status,
      article_id: form.article_id || null,
      access_mode: form.access_mode,
      success_message: form.success_message,
      fields: form.fields,
    };

    if (isNew.value) {
      const created = await store.dispatch('forms/create', payload);
      useAlert(t('FORMS.BUILDER.SAVE_SUCCESS'));
      router.replace({ name: 'forms_edit', params: { formId: created.id } });
    } else {
      await store.dispatch('forms/update', { id: formId.value, ...payload });
      useAlert(t('FORMS.BUILDER.SAVE_SUCCESS'));
    }
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('FORMS.BUILDER.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

// Os links para o cliente preencher: so' existem com o formulario publicado e salvo.
const shareLinks = computed(() => {
  const saved = existingForm.value;
  if (!saved || saved.status !== 'published') return [];
  return [
    {
      key: 'client',
      label: t('FORMS.BUILDER.LINK_CLIENT'),
      url: saved.client_url,
    },
    {
      key: 'public',
      label: t('FORMS.BUILDER.LINK_PUBLIC'),
      url: saved.public_url,
    },
  ].filter(link => link.url);
});

const copyLink = async url => {
  try {
    await navigator.clipboard.writeText(url);
    useAlert(t('FORMS.BUILDER.LINK_COPIED'));
  } catch (error) {
    useAlert(url);
  }
};

const responseSourceLabel = response =>
  t(
    `FORMS.BUILDER.RESPONSE_SOURCE.${String(response.source || 'ticket').toUpperCase()}`
  );

const responseAuthor = response =>
  response.filled_by_name ||
  response.contact_name ||
  response.respondent_name ||
  response.respondent_email ||
  '';

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '—';

watch(existingForm, value => {
  if (value) syncForm(value);
});

watch(activeTab, tab => {
  if (tab === 'responses' && !isNew.value) {
    store.dispatch('forms/getResponses', formId.value);
  }
});

onMounted(async () => {
  fetchArticlesForFirstPortal();
  if (!isNew.value) {
    const loaded = await store.dispatch('forms/show', formId.value);
    syncForm(loaded);
  }
});
</script>

<template>
  <SettingsLayout :no-records-found="false">
    <template #header>
      <BaseSettingsHeader
        :title="
          isNew ? t('FORMS.BUILDER.NEW_TITLE') : t('FORMS.BUILDER.EDIT_TITLE')
        "
        :description="t('FORMS.BUILDER.DESCRIPTION')"
        :back-button-label="t('FORMS.BUILDER.BACK')"
      >
        <template #actions>
          <Button
            variant="faded"
            color="slate"
            size="sm"
            :label="t('FORMS.BUILDER.SAVE_DRAFT')"
            :is-loading="isSaving"
            :disabled="!canSave"
            @click="save(false)"
          />
          <Button
            size="sm"
            :label="t('FORMS.BUILDER.PUBLISH')"
            :is-loading="isSaving"
            :disabled="!canSave"
            @click="save(true)"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4 max-w-3xl">
        <div class="flex flex-col gap-2">
          <input
            v-model="form.name"
            type="text"
            class="w-full mb-0 text-lg font-medium"
            :placeholder="t('FORMS.BUILDER.NAME_PLACEHOLDER')"
          />
          <textarea
            v-model="form.description"
            rows="2"
            class="w-full mb-0 text-sm resize-y"
            :placeholder="t('FORMS.BUILDER.DESCRIPTION_PLACEHOLDER')"
          />
        </div>

        <div class="flex items-center gap-4 border-b border-n-weak">
          <button
            v-for="tab in ['questions', 'responses', 'settings']"
            :key="tab"
            type="button"
            class="pb-2 text-sm font-medium border-b-2 -mb-px"
            :class="
              activeTab === tab
                ? 'border-n-blue-9 text-n-blue-11'
                : 'border-transparent text-n-slate-10'
            "
            @click="activeTab = tab"
          >
            {{ t(`FORMS.BUILDER.TABS.${tab.toUpperCase()}`) }}
          </button>
        </div>

        <!-- Perguntas -->
        <div v-if="activeTab === 'questions'" class="flex flex-col gap-3">
          <Draggable
            v-model="form.fields"
            item-key="id"
            handle=".form-field-drag"
            class="flex flex-col gap-3"
          >
            <template #item="{ element: field, index }">
              <div
                class="flex flex-col gap-2 p-3 border rounded-xl border-n-weak"
              >
                <div class="flex items-start gap-2">
                  <Icon
                    icon="i-lucide-grip-vertical"
                    class="form-field-drag cursor-grab flex-shrink-0 size-4 mt-2 text-n-slate-9"
                  />
                  <div class="flex flex-col flex-1 min-w-0 gap-2">
                    <input
                      v-model="field.label"
                      type="text"
                      class="w-full mb-0 text-sm"
                      :placeholder="t('FORMS.BUILDER.FIELD_LABEL_PLACEHOLDER')"
                    />
                    <input
                      v-model="field.description"
                      type="text"
                      class="w-full mb-0 text-xs text-n-slate-10"
                      :placeholder="
                        t('FORMS.BUILDER.FIELD_DESCRIPTION_PLACEHOLDER')
                      "
                    />

                    <div
                      v-if="isChoiceType(field.field_type)"
                      class="flex flex-col gap-1"
                    >
                      <div
                        v-for="(_option, optionIndex) in field.options"
                        :key="optionIndex"
                        class="flex items-center gap-2"
                      >
                        <input
                          v-model="field.options[optionIndex]"
                          type="text"
                          class="w-full mb-0 text-sm"
                          :placeholder="
                            t('FORMS.BUILDER.OPTION_PLACEHOLDER', {
                              number: optionIndex + 1,
                            })
                          "
                        />
                        <button
                          type="button"
                          class="flex-shrink-0 p-1 rounded hover:bg-n-alpha-2"
                          @click="removeOption(field, optionIndex)"
                        >
                          <Icon icon="i-lucide-x" class="size-3.5" />
                        </button>
                      </div>
                      <Button
                        variant="link"
                        size="sm"
                        color="slate"
                        class="w-fit"
                        :label="t('FORMS.BUILDER.ADD_OPTION')"
                        @click="addOption(field)"
                      />
                    </div>
                  </div>

                  <Select
                    v-model="field.field_type"
                    :options="fieldTypeOptions"
                    class="flex-shrink-0 w-44"
                  />
                </div>

                <div class="flex items-center justify-between pl-6">
                  <label class="flex items-center gap-2 cursor-pointer">
                    <Checkbox v-model="field.required" />
                    <span class="text-xs text-n-slate-11">
                      {{ t('FORMS.BUILDER.REQUIRED') }}
                    </span>
                  </label>
                  <div class="flex items-center gap-1">
                    <Button
                      v-tooltip.top="t('FORMS.BUILDER.DUPLICATE')"
                      icon="i-lucide-copy"
                      slate
                      ghost
                      sm
                      @click="duplicateField(index)"
                    />
                    <Button
                      v-tooltip.top="t('FORMS.BUILDER.REMOVE_FIELD')"
                      icon="i-lucide-trash-2"
                      slate
                      ghost
                      sm
                      class="hover:enabled:text-n-ruby-11"
                      @click="removeField(index)"
                    />
                  </div>
                </div>
              </div>
            </template>
          </Draggable>

          <p v-if="!form.fields.length" class="text-sm text-n-slate-10">
            {{ t('FORMS.BUILDER.NO_FIELDS') }}
          </p>

          <div class="flex flex-wrap gap-2">
            <Button
              v-for="fieldType in FIELD_TYPES"
              :key="fieldType"
              variant="faded"
              color="slate"
              size="sm"
              icon="i-lucide-plus"
              :label="t(`FORMS.BUILDER.FIELD_TYPES.${fieldType.toUpperCase()}`)"
              @click="addField(fieldType)"
            />
          </div>
        </div>

        <!-- Respostas -->
        <div v-else-if="activeTab === 'responses'" class="flex flex-col gap-2">
          <p v-if="isNew" class="text-sm text-n-slate-10">
            {{ t('FORMS.BUILDER.RESPONSES_NEEDS_SAVE') }}
          </p>
          <p v-else-if="!responses.length" class="text-sm text-n-slate-10">
            {{ t('FORMS.BUILDER.RESPONSES_EMPTY') }}
          </p>
          <ul v-else class="flex flex-col gap-2">
            <li
              v-for="response in responses"
              :key="response.id"
              class="flex items-center justify-between gap-2 p-3 border rounded-lg border-n-weak"
            >
              <span class="text-sm text-n-slate-12">
                {{
                  response.ticket_display_id
                    ? t('FORMS.BUILDER.RESPONSE_TICKET', {
                        number: response.ticket_display_id,
                      })
                    : t('FORMS.BUILDER.RESPONSE_NO_TICKET')
                }}
                <span class="text-xs text-n-slate-10">
                  · {{ responseSourceLabel(response) }}
                </span>
              </span>
              <span class="text-xs text-n-slate-10">
                {{ responseAuthor(response) }} ·
                {{ formatDate(response.created_at) }}
              </span>
            </li>
          </ul>
        </div>

        <!-- Configurações -->
        <div v-else class="flex flex-col gap-4 max-w-md">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('FORMS.BUILDER.LINKED_ARTICLE') }}
            </span>
            <select v-model="form.article_id" class="w-full mb-0 text-sm">
              <option :value="null">
                {{ t('FORMS.BUILDER.LINKED_ARTICLE_NONE') }}
              </option>
              <option
                v-for="article in articles"
                :key="article.id"
                :value="article.id"
              >
                {{ article.title }}
              </option>
            </select>
          </label>

          <fieldset class="flex flex-col gap-2 p-0 m-0 border-0">
            <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
              {{ t('FORMS.BUILDER.ACCESS_TITLE') }}
            </legend>
            <label class="flex items-start gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.access_mode"
                type="radio"
                value="login"
                class="mt-1 mb-0"
                data-testid="access-login"
              />
              <span>
                {{ t('FORMS.BUILDER.ACCESS_LOGIN') }}
                <span class="block text-xs text-n-slate-11">
                  {{ t('FORMS.BUILDER.ACCESS_LOGIN_HINT') }}
                </span>
              </span>
            </label>
            <label class="flex items-start gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.access_mode"
                type="radio"
                value="open"
                class="mt-1 mb-0"
                data-testid="access-open"
              />
              <span>
                {{ t('FORMS.BUILDER.ACCESS_OPEN') }}
                <span class="block text-xs text-n-slate-11">
                  {{ t('FORMS.BUILDER.ACCESS_OPEN_HINT') }}
                </span>
              </span>
            </label>
          </fieldset>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('FORMS.BUILDER.SUCCESS_MESSAGE') }}
            </span>
            <textarea
              v-model="form.success_message"
              rows="2"
              class="w-full mb-0 text-sm"
              :placeholder="t('FORMS.BUILDER.SUCCESS_MESSAGE_PLACEHOLDER')"
            />
          </label>

          <div class="flex flex-col gap-2" data-testid="share-links">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('FORMS.BUILDER.LINKS_TITLE') }}
            </span>
            <p v-if="!shareLinks.length" class="m-0 text-xs text-n-slate-11">
              {{ t('FORMS.BUILDER.LINKS_NEED_PUBLISH') }}
            </p>
            <div
              v-for="link in shareLinks"
              :key="link.key"
              class="flex flex-col gap-1"
            >
              <span class="text-xs text-n-slate-11">{{ link.label }}</span>
              <div class="flex gap-2">
                <input
                  :value="link.url"
                  readonly
                  class="w-full mb-0 text-xs"
                  :data-testid="`link-${link.key}`"
                />
                <Button
                  type="button"
                  variant="faded"
                  color="slate"
                  size="sm"
                  icon="i-lucide-copy"
                  :label="t('FORMS.BUILDER.LINK_COPY')"
                  @click="copyLink(link.url)"
                />
              </div>
            </div>
          </div>

          <div v-if="!isNew" class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('FORMS.BUILDER.LINKED_CATALOG') }}
            </span>
            <p class="text-sm text-n-slate-11">
              {{
                existingForm?.service_catalog_item_ids?.length
                  ? t('FORMS.BUILDER.LINKED_CATALOG_COUNT', {
                      count: existingForm.service_catalog_item_ids.length,
                    })
                  : t('FORMS.BUILDER.LINKED_CATALOG_NONE')
              }}
            </p>
            <p class="text-xs text-n-slate-10">
              {{ t('FORMS.BUILDER.LINKED_CATALOG_HINT') }}
            </p>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
