<script setup>
/**
 * O painel central: o caminho (pasta > pais > artigo), o titulo, os dados e o conteudo ja
 * renderizado. Os links para outros artigos/formularios (inseridos pelo autor) navegam dentro
 * da propria Base de Conhecimento, mantendo a arvore ao lado.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DOMPurify from 'dompurify';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  article: { type: Object, default: null },
  folderPath: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['openArticle', 'openForm', 'edit', 'newChild']);

const { t } = useI18n();

const safeHtml = computed(() =>
  DOMPurify.sanitize(props.article?.renderedContent || '')
);

const updatedLabel = computed(() => {
  if (!props.article?.updatedAt) return '';
  const date = new Date(props.article.updatedAt * 1000).toLocaleDateString(
    'pt-BR'
  );
  return t('HELP_CENTER.KB_TREE.VIEWER.UPDATED', { date });
});

const viewsLabel = computed(() =>
  t('HELP_CENTER.KB_TREE.VIEWER.VIEWS', { count: props.article?.views || 0 })
);

const statusLabel = computed(() =>
  t(
    `HELP_CENTER.KB_TREE.STATUS.${String(props.article?.status || '').toUpperCase()}`
  )
);

// Um clique num link de referencia (data-ref-*) navega na propria base, sem sair da tela.
const onContentClick = event => {
  const link = event.target.closest?.('a[data-ref-type]');
  if (!link) return;
  event.preventDefault();
  if (link.dataset.refBroken === 'true') return;

  const id = Number(link.dataset.refId);
  if (link.dataset.refType === 'article') emit('openArticle', id);
  if (link.dataset.refType === 'form') emit('openForm', id);
};
</script>

<template>
  <div
    class="flex flex-col h-full min-h-0 border rounded-xl border-n-weak bg-n-solid-1"
  >
    <div v-if="isLoading" class="grid flex-1 place-items-center">
      <Spinner />
    </div>

    <div
      v-else-if="!article"
      class="grid flex-1 p-8 text-sm text-center place-items-center text-n-slate-11"
      data-testid="kb-viewer-empty"
    >
      {{ t('HELP_CENTER.KB_TREE.SELECT_ARTICLE') }}
    </div>

    <template v-else>
      <div class="flex-1 min-h-0 p-6 overflow-y-auto" data-testid="kb-viewer">
        <nav
          class="flex flex-wrap items-center gap-1 mb-3 text-sm text-n-slate-11"
          :aria-label="t('HELP_CENTER.KB_TREE.VIEWER.BREADCRUMB')"
        >
          <template v-for="name in folderPath" :key="`f-${name}`">
            <span>{{ name }}</span>
            <Icon icon="i-lucide-chevron-right" class="size-3.5" />
          </template>
          <template v-for="ancestor in article.ancestors" :key="ancestor.id">
            <button
              type="button"
              class="text-n-blue-11 hover:underline"
              @click="emit('openArticle', ancestor.id)"
            >
              {{ ancestor.title }}
            </button>
            <Icon icon="i-lucide-chevron-right" class="size-3.5" />
          </template>
          <span class="font-medium text-n-slate-12">{{ article.title }}</span>
        </nav>

        <div class="flex flex-wrap items-start justify-between gap-3">
          <h1 class="m-0 text-2xl font-semibold text-n-slate-12">
            {{ article.title }}
          </h1>
          <div v-if="canManage" class="flex gap-2">
            <Button
              sm
              faded
              slate
              icon="i-lucide-corner-down-right"
              :label="t('HELP_CENTER.KB_TREE.NEW_CHILD')"
              data-testid="kb-new-child"
              @click="emit('newChild', article)"
            />
            <Button
              sm
              icon="i-lucide-pencil"
              :label="t('HELP_CENTER.KB_TREE.VIEWER.EDIT')"
              data-testid="kb-edit"
              @click="emit('edit', article)"
            />
          </div>
        </div>

        <p
          class="flex flex-wrap items-center gap-2 mt-1 mb-4 text-sm text-n-slate-11"
        >
          <span>{{ statusLabel }}</span>
          <span>•</span>
          <span>{{ updatedLabel }}</span>
          <span>•</span>
          <span class="inline-flex items-center gap-1">
            <Icon icon="i-lucide-eye" class="size-4" />
            {{ viewsLabel }}
          </span>
        </p>

        <p
          v-if="article.status !== 'published'"
          class="px-3 py-2 mb-4 text-sm rounded-lg bg-n-amber-3 text-n-amber-11"
        >
          {{ t('HELP_CENTER.KB_TREE.ARTICLE_UNPUBLISHED') }}
        </p>

        <!-- eslint-disable vue/no-v-html -->
        <div
          v-if="safeHtml"
          class="kb-content prose prose-sm max-w-none break-words text-n-slate-12 prose-a:text-n-blue-11"
          data-testid="kb-content"
          @click="onContentClick"
          v-html="safeHtml"
        />
        <!-- eslint-enable vue/no-v-html -->
        <p v-else class="text-sm text-n-slate-11">
          {{ t('HELP_CENTER.KB_TREE.VIEWER.EMPTY_CONTENT') }}
        </p>

        <p
          v-if="safeHtml.includes('data-ref-broken')"
          class="mt-4 text-xs text-n-slate-11"
        >
          {{ t('HELP_CENTER.KB_TREE.VIEWER.BROKEN_REFERENCE') }}
        </p>
      </div>
    </template>
  </div>
</template>

<style scoped>
.kb-content :deep(a[data-ref-type]) {
  cursor: pointer;
}

.kb-content :deep(a[data-ref-broken='true']) {
  text-decoration: line-through;
  cursor: not-allowed;
  opacity: 0.7;
}
</style>
