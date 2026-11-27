<script setup>
/**
 * A coluna da esquerda: busca + arvore. A busca e' a mesma do servidor (titulo e conteudo) e
 * mostra o resultado em lista, em qualquer posicao da estrutura; sem texto, volta a arvore.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ArticleTreeNode from './ArticleTreeNode.vue';

const props = defineProps({
  tree: { type: Array, default: () => [] },
  expandedKeys: { type: Object, required: true },
  selectedArticleId: { type: Number, default: null },
  canManage: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  query: { type: String, default: '' },
  searchResults: { type: Array, default: () => [] },
  isSearching: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update:query',
  'toggle',
  'select',
  'selectResult',
  'drop',
  'action',
  'expandAll',
  'collapseAll',
]);

const { t } = useI18n();

const dragged = ref(null);

const hasQuery = computed(() => props.query.trim().length > 0);
const isEmpty = computed(() => !props.isLoading && props.tree.length === 0);

const onDrop = target => {
  const source = dragged.value;
  dragged.value = null;
  if (source) emit('drop', { source, target });
};
</script>

<template>
  <div
    class="flex flex-col h-full min-h-0 gap-2 p-3 border rounded-xl border-n-weak bg-n-solid-1"
  >
    <Input
      :model-value="query"
      type="search"
      size="sm"
      :placeholder="t('HELP_CENTER.KB_TREE.SEARCH_PLACEHOLDER')"
      @update:model-value="value => emit('update:query', value)"
    />

    <div v-if="!hasQuery" class="flex items-center gap-1">
      <Button
        xs
        ghost
        slate
        icon="i-lucide-chevrons-down-up"
        :label="t('HELP_CENTER.KB_TREE.COLLAPSE_ALL')"
        @click="emit('collapseAll')"
      />
      <Button
        xs
        ghost
        slate
        icon="i-lucide-chevrons-up-down"
        :label="t('HELP_CENTER.KB_TREE.EXPAND_ALL')"
        @click="emit('expandAll')"
      />
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <div v-if="isLoading || isSearching" class="grid p-6 place-items-center">
        <Spinner />
      </div>

      <!-- A busca: independe da posicao do artigo na estrutura. -->
      <template v-else-if="hasQuery">
        <p class="px-2 py-1 m-0 text-xs font-medium text-n-slate-11">
          {{ t('HELP_CENTER.KB_TREE.SEARCH_RESULTS') }}
        </p>
        <p
          v-if="!searchResults.length"
          class="px-2 py-3 m-0 text-sm text-n-slate-11"
          data-testid="kb-search-empty"
        >
          {{ t('HELP_CENTER.KB_TREE.SEARCH_EMPTY') }}
        </p>
        <ul v-else class="m-0 list-none" data-testid="kb-search-results">
          <li v-for="result in searchResults" :key="result.id">
            <button
              type="button"
              class="flex flex-col w-full gap-0.5 px-2 py-1.5 text-start rounded-lg hover:bg-n-alpha-2"
              :class="result.id === selectedArticleId ? 'bg-n-blue-3' : ''"
              @click="emit('selectResult', result)"
            >
              <span class="flex items-start gap-1.5 text-sm text-n-slate-12">
                <Icon
                  icon="i-lucide-file-text"
                  class="flex-shrink-0 mt-0.5 size-4"
                />
                <span class="min-w-0 leading-5 break-words">
                  {{ result.title }}
                </span>
              </span>
              <span
                v-if="result.folder"
                class="ps-5 text-xs break-words text-n-slate-11"
              >
                {{ result.folder }}
              </span>
            </button>
          </li>
        </ul>
      </template>

      <p
        v-else-if="isEmpty"
        class="px-2 py-4 m-0 text-sm text-center text-n-slate-11"
        data-testid="kb-tree-empty"
      >
        {{ t('HELP_CENTER.KB_TREE.EMPTY_TITLE') }}
      </p>

      <ul v-else role="tree" class="m-0 list-none" data-testid="kb-tree">
        <ArticleTreeNode
          v-for="node in tree"
          :key="node.key"
          :node="node"
          :expanded-keys="expandedKeys"
          :selected-article-id="selectedArticleId"
          :can-manage="canManage"
          :dragged="dragged"
          @toggle="key => emit('toggle', key)"
          @select="selected => emit('select', selected)"
          @drag-start="dragNode => (dragged = dragNode)"
          @drag-end="dragged = null"
          @drop="onDrop"
          @action="payload => emit('action', payload)"
        />
      </ul>
    </div>
  </div>
</template>
