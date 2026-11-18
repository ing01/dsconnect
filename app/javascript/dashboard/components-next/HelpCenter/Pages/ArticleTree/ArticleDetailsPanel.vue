<script setup>
/**
 * A coluna da direita: os dados do artigo, a estrutura dele (os subartigos) e os formularios
 * vinculados, com acesso para consultar e preencher.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  article: { type: Object, default: null },
  articleNode: { type: Object, default: null },
  folderName: { type: String, default: '' },
});

const emit = defineEmits(['openArticle', 'consultForm', 'fillForm']);

const { t } = useI18n();

const NONE = computed(() => t('HELP_CENTER.KB_TREE.DETAILS.NONE'));

const updatedAt = computed(() =>
  props.article?.updatedAt
    ? new Date(props.article.updatedAt * 1000).toLocaleDateString('pt-BR')
    : NONE.value
);

const tags = computed(() => props.article?.meta?.tags || []);
const forms = computed(() => props.article?.forms || []);
const children = computed(() => props.articleNode?.children || []);

const rows = computed(() => [
  {
    icon: 'i-lucide-folder',
    label: t('HELP_CENTER.KB_TREE.DETAILS.CATEGORY'),
    value: props.folderName || NONE.value,
  },
  {
    icon: 'i-lucide-layers',
    label: t('HELP_CENTER.KB_TREE.DETAILS.STATUS'),
    value: t(
      `HELP_CENTER.KB_TREE.STATUS.${String(props.article?.status || '').toUpperCase()}`
    ),
  },
  {
    icon: 'i-lucide-calendar',
    label: t('HELP_CENTER.KB_TREE.DETAILS.UPDATED_AT'),
    value: updatedAt.value,
  },
  {
    icon: 'i-lucide-user',
    label: t('HELP_CENTER.KB_TREE.DETAILS.AUTHOR'),
    value: props.article?.author?.name || NONE.value,
  },
  {
    icon: 'i-lucide-tag',
    label: t('HELP_CENTER.KB_TREE.DETAILS.TAGS'),
    value: tags.value.length ? tags.value.join(', ') : NONE.value,
  },
]);
</script>

<template>
  <div class="flex flex-col h-full min-h-0 gap-3 overflow-y-auto">
    <template v-if="article">
      <section
        class="p-4 border rounded-xl border-n-weak bg-n-solid-1"
        data-testid="kb-details"
      >
        <h3
          class="flex items-center gap-2 m-0 mb-3 text-sm font-semibold text-n-slate-12"
        >
          <Icon icon="i-lucide-info" class="size-4 text-n-blue-11" />
          {{ t('HELP_CENTER.KB_TREE.DETAILS.TITLE') }}
        </h3>
        <dl class="grid gap-2 m-0 text-sm">
          <div
            v-for="row in rows"
            :key="row.label"
            class="flex items-start gap-2"
          >
            <Icon
              :icon="row.icon"
              class="flex-shrink-0 mt-0.5 size-4 text-n-slate-11"
            />
            <div class="min-w-0">
              <dt class="inline text-n-slate-11">{{ row.label }}:</dt>
              <dd class="inline m-0 ms-1 text-n-slate-12 break-words">
                {{ row.value }}
              </dd>
            </div>
          </div>
        </dl>
      </section>

      <section
        class="p-4 border rounded-xl border-n-weak bg-n-solid-1"
        data-testid="kb-structure"
      >
        <h3
          class="flex items-center gap-2 m-0 mb-3 text-sm font-semibold text-n-slate-12"
        >
          <Icon icon="i-lucide-network" class="size-4 text-n-teal-11" />
          {{ t('HELP_CENTER.KB_TREE.DETAILS.STRUCTURE') }}
        </h3>
        <p class="m-0 mb-2 text-sm font-medium text-n-slate-12">
          {{ article.title }}
        </p>
        <ul v-if="children.length" class="m-0 list-none">
          <li v-for="child in children" :key="child.key">
            <button
              type="button"
              class="flex items-center w-full gap-2 px-2 py-1 text-sm rounded-lg text-start text-n-blue-11 hover:bg-n-alpha-2"
              @click="emit('openArticle', child.id)"
            >
              <Icon
                icon="i-lucide-corner-down-right"
                class="flex-shrink-0 size-4"
              />
              <span class="truncate">{{ child.title }}</span>
            </button>
          </li>
        </ul>
        <p v-else class="m-0 text-sm text-n-slate-11">
          {{ t('HELP_CENTER.KB_TREE.DETAILS.NO_CHILDREN') }}
        </p>
      </section>

      <section
        class="p-4 border rounded-xl border-n-weak bg-n-solid-1"
        data-testid="kb-forms"
      >
        <h3
          class="flex items-center gap-2 m-0 mb-3 text-sm font-semibold text-n-slate-12"
        >
          <Icon icon="i-lucide-clipboard-list" class="size-4 text-n-amber-11" />
          {{ t('HELP_CENTER.KB_TREE.FORMS.TITLE') }}
        </h3>
        <p v-if="!forms.length" class="m-0 text-sm text-n-slate-11">
          {{ t('HELP_CENTER.KB_TREE.FORMS.EMPTY') }}
        </p>
        <ul v-else class="grid gap-2 m-0 list-none">
          <li
            v-for="form in forms"
            :key="form.id"
            class="flex flex-col gap-2 p-2 border rounded-lg border-n-weak"
          >
            <div class="min-w-0">
              <p class="m-0 text-sm font-medium truncate text-n-slate-12">
                {{ form.name }}
              </p>
              <p class="m-0 text-xs text-n-slate-11">
                {{
                  t('HELP_CENTER.KB_TREE.FORMS.QUESTIONS', {
                    count: (form.fields || []).length,
                  })
                }}
              </p>
            </div>
            <div class="flex gap-2">
              <Button
                xs
                faded
                slate
                icon="i-lucide-eye"
                :label="t('HELP_CENTER.KB_TREE.FORMS.CONSULT')"
                :data-testid="`kb-form-consult-${form.id}`"
                @click="emit('consultForm', form)"
              />
              <Button
                xs
                icon="i-lucide-pencil-line"
                :label="t('HELP_CENTER.KB_TREE.FORMS.FILL')"
                :data-testid="`kb-form-fill-${form.id}`"
                @click="emit('fillForm', form)"
              />
            </div>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
