<script setup>
/**
 * A Base de Conhecimento em arvore: pastas e subpastas (Categorias), artigos com subartigos,
 * o conteudo no painel central e os detalhes/formularios na lateral direita. Escolher um artigo
 * (ou seguir uma referencia dentro do texto) mantem a arvore a vista; o artigo aberto fica no
 * endereco (`?article=<id>`), entao da' para compartilhar o link.
 */
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import articlesAPI from 'dashboard/api/helpCenter/articles';
import FormsAPI from 'dashboard/api/forms';
import Button from 'dashboard/components-next/button/Button.vue';
import ArticleTreePanel from './ArticleTreePanel.vue';
import ArticleViewerPanel from './ArticleViewerPanel.vue';
import ArticleDetailsPanel from './ArticleDetailsPanel.vue';
import ArticleFormDialog from './ArticleFormDialog.vue';
import NewFolderDialog from './NewFolderDialog.vue';
import MoveArticleDialog from './MoveArticleDialog.vue';
import {
  NODE_TYPE,
  buildTree,
  expandableKeys,
  pathKeysTo,
  findArticleNode,
  dropAction,
  reorderAction,
  moveTargets,
} from './articleTreeHelper';

const props = defineProps({
  portalSlug: { type: String, required: true },
  locale: { type: String, required: true },
  allowedLocales: { type: Array, default: () => [] },
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['localeChange']);

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const treeData = ref({ categories: [], articles: [] });
const isTreeLoading = ref(false);
const expandedKeys = ref(new Set());
const hasAutoExpanded = ref(false);

const article = ref(null);
const isArticleLoading = ref(false);

const query = ref('');
const searchResults = ref([]);
const isSearching = ref(false);

const newFolderRef = ref(null);
const moveDialogRef = ref(null);
const formDialogRef = ref(null);

const selectedId = computed(() => Number(route.query.article) || null);

const tree = computed(() =>
  buildTree({
    categories: treeData.value.categories,
    articles: treeData.value.articles,
    noFolderLabel: t('HELP_CENTER.KB_TREE.NO_FOLDER'),
  })
);

const articleNode = computed(() =>
  selectedId.value ? findArticleNode(tree.value, selectedId.value) : null
);

// O caminho de pastas ate o artigo aberto (da raiz para a pasta dele).
const folderPath = computed(() => {
  const current = treeData.value.articles.find(a => a.id === selectedId.value);
  const byId = new Map(treeData.value.categories.map(c => [c.id, c]));
  const names = [];
  const seen = new Set();
  let folder = byId.get(current?.categoryId);
  while (folder && !seen.has(folder.id)) {
    seen.add(folder.id);
    names.unshift(folder.name);
    folder = byId.get(folder.parentCategoryId);
  }
  return names;
});

// As pastas que podem receber uma nova subpasta (com recuo pela profundidade).
const folderOptions = computed(() => {
  const folders = [];
  const walk = (nodes, depth) =>
    nodes.forEach(node => {
      if (node.type === NODE_TYPE.FOLDER && !node.virtual) {
        folders.push({ id: node.id, label: node.title, depth });
        walk(node.children, depth + 1);
      }
    });
  walk(tree.value, 0);
  return folders;
});

const moveDialogTargets = ref([]);

const reportError = (error, fallbackKey) =>
  useAlert(error?.response?.data?.message || t(fallbackKey));

const openKeys = keys => {
  if (!keys.length) return;
  expandedKeys.value = new Set([...expandedKeys.value, ...keys]);
};

const loadTree = async () => {
  isTreeLoading.value = true;
  try {
    const { data } = await articlesAPI.getTree({
      portalSlug: props.portalSlug,
      locale: props.locale,
    });
    treeData.value = {
      categories: (data.categories || []).map(c => camelcaseKeys(c)),
      articles: (data.articles || []).map(a => camelcaseKeys(a)),
    };
    if (!hasAutoExpanded.value) {
      // Na primeira carga, abre as pastas principais para a pessoa ver por onde comecar.
      openKeys(tree.value.filter(n => n.children.length).map(n => n.key));
      hasAutoExpanded.value = true;
    }
    if (selectedId.value) openKeys(pathKeysTo(tree.value, selectedId.value));
  } catch (error) {
    reportError(error, 'HELP_CENTER.KB_TREE.LOADING_ERROR');
  } finally {
    isTreeLoading.value = false;
  }
};

const loadArticle = async id => {
  if (!id) {
    article.value = null;
    return;
  }
  isArticleLoading.value = true;
  try {
    const { data } = await articlesAPI.getArticle({
      id,
      portalSlug: props.portalSlug,
    });
    // So' guarda se ainda e' o artigo escolhido (um clique rapido em outro nao pode ser sobrescrito).
    if (id === selectedId.value) article.value = camelcaseKeys(data.payload);
  } catch (error) {
    article.value = null;
    reportError(error, 'HELP_CENTER.KB_TREE.ARTICLE_ERROR');
  } finally {
    isArticleLoading.value = false;
  }
};

const selectArticle = id => {
  router.replace({ query: { ...route.query, article: id } });
};

const toggle = key => {
  const next = new Set(expandedKeys.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  expandedKeys.value = next;
};

const expandAll = () => {
  expandedKeys.value = new Set(expandableKeys(tree.value));
};
const collapseAll = () => {
  expandedKeys.value = new Set();
};

// --- Busca (a mesma do servidor: titulo e conteudo, em qualquer posicao da estrutura) ---------
const runSearch = async () => {
  const term = query.value.trim();
  if (!term) {
    searchResults.value = [];
    return;
  }
  isSearching.value = true;
  try {
    const { data } = await articlesAPI.getArticles({
      pageNumber: 1,
      portalSlug: props.portalSlug,
      locale: props.locale,
      query: term,
    });
    if (term !== query.value.trim()) return;
    searchResults.value = (data.payload || []).map(item => ({
      id: item.id,
      title: item.title,
      folder: item.category?.name || '',
    }));
  } catch (error) {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
};
const debouncedSearch = debounce(runSearch, 400);

watch(query, value => {
  if (!value.trim()) {
    searchResults.value = [];
    return;
  }
  debouncedSearch();
});

const selectResult = result => {
  selectArticle(result.id);
};

// --- Reorganizar -------------------------------------------------------------------------------
const moveArticle = async ({
  articleId,
  parentArticleId,
  categoryId,
  index,
}) => {
  try {
    await articlesAPI.moveArticle({
      portalSlug: props.portalSlug,
      articleId,
      parentArticleId,
      categoryId,
      index,
    });
    useAlert(t('HELP_CENTER.KB_TREE.MOVE.SUCCESS'));
    await loadTree();
    // O destino fica visivel: abre o pai/pasta e o caminho do artigo movido.
    openKeys(pathKeysTo(tree.value, articleId));
    if (articleId === selectedId.value) loadArticle(articleId);
  } catch (error) {
    reportError(error, 'HELP_CENTER.KB_TREE.MOVE.ERROR');
  }
};

const onDrop = ({ source, target }) => {
  const action = dropAction(source, target);
  if (!action) return;
  moveArticle({ articleId: source.id, ...action });
};

const onMoveConfirm = ({ node, targetKey }) => {
  const [type, rawId] = targetKey.split('-');
  const id = Number(rawId);
  moveArticle({
    articleId: node.id,
    parentArticleId: type === NODE_TYPE.ARTICLE ? id : null,
    categoryId: type === NODE_TYPE.FOLDER ? id : null,
  });
};

// --- Criar / editar ----------------------------------------------------------------------------
const goToNewArticle = extraQuery => {
  router.push({
    name: 'portals_articles_new',
    params: { portalSlug: props.portalSlug, locale: props.locale },
    query: extraQuery,
  });
};

const goToEdit = articleId => {
  router.push({
    name: 'portals_articles_edit',
    params: {
      portalSlug: props.portalSlug,
      locale: props.locale,
      articleSlug: articleId,
    },
  });
};

const onNodeAction = ({ action, node }) => {
  const actions = {
    'new-article': () => goToNewArticle({ folder: node.id }),
    'new-subfolder': () => newFolderRef.value?.open(node.id),
    'new-child': () => goToNewArticle({ parent: node.id }),
    edit: () => goToEdit(node.id),
    move: () => {
      moveDialogTargets.value = moveTargets(tree.value, node);
      moveDialogRef.value?.open(node);
    },
    up: () => {
      const move = reorderAction(tree.value, node.id, 'up');
      if (move) moveArticle({ articleId: node.id, ...move });
    },
    down: () => {
      const move = reorderAction(tree.value, node.id, 'down');
      if (move) moveArticle({ articleId: node.id, ...move });
    },
  };
  actions[action]?.();
};

// --- Formularios -------------------------------------------------------------------------------
// `fields` volta em snake_case do servidor (field_type); o dialogo le os dois formatos.
const openForm = (form, mode) =>
  formDialogRef.value?.open({ ...form, fields: form.fields || [] }, mode);

// Uma referencia no texto a um formulario: abre para consulta (o dado vem do artigo ou do servidor).
const openFormReference = async formId => {
  const linked = (article.value?.forms || []).find(form => form.id === formId);
  if (linked) {
    openForm(linked, 'view');
    return;
  }
  try {
    const { data } = await FormsAPI.show(formId);
    openForm(data, 'view');
  } catch (error) {
    reportError(error, 'HELP_CENTER.KB_TREE.ARTICLE_ERROR');
  }
};

// --- Ciclo de vida -----------------------------------------------------------------------------
watch(
  selectedId,
  id => {
    loadArticle(id);
    if (id) openKeys(pathKeysTo(tree.value, id));
  },
  { immediate: true }
);

watch(
  () => [props.portalSlug, props.locale],
  () => {
    hasAutoExpanded.value = false;
    expandedKeys.value = new Set();
    loadTree();
  }
);

// Quando a arvore chega depois do artigo escolhido (link direto), abre o caminho dele.
watch(
  () => treeData.value.articles.length,
  () => {
    if (selectedId.value) openKeys(pathKeysTo(tree.value, selectedId.value));
  }
);

onMounted(loadTree);

defineExpose({ loadTree });
</script>

<template>
  <div class="flex flex-col gap-3" data-testid="kb-tree-board">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <label
        v-if="allowedLocales.length > 1"
        class="flex items-center gap-2 text-sm text-n-slate-11"
      >
        {{ t('HELP_CENTER.KB_TREE.LOCALE') }}
        <select
          :value="locale"
          class="mb-0 text-sm w-auto min-w-[8rem]"
          data-testid="kb-locale"
          @change="event => emit('localeChange', event.target.value)"
        >
          <option
            v-for="item in allowedLocales"
            :key="item.code"
            :value="item.code"
          >
            {{ item.name }}
          </option>
        </select>
      </label>
      <span v-else />
      <div v-if="canManage" class="flex gap-2">
        <Button
          sm
          faded
          slate
          icon="i-lucide-folder-plus"
          :label="t('HELP_CENTER.KB_TREE.NEW_FOLDER')"
          data-testid="kb-new-folder"
          @click="newFolderRef?.open()"
        />
        <Button
          sm
          icon="i-lucide-file-plus"
          :label="t('HELP_CENTER.KB_TREE.NEW_ARTICLE')"
          data-testid="kb-new-article"
          @click="goToNewArticle()"
        />
      </div>
    </div>

    <div
      class="grid gap-4 lg:grid-cols-[18rem_minmax(0,1fr)_17rem] lg:h-[calc(100vh-17rem)] lg:min-h-[30rem]"
    >
      <ArticleTreePanel
        v-model:query="query"
        class="max-h-[24rem] lg:max-h-none"
        :tree="tree"
        :expanded-keys="expandedKeys"
        :selected-article-id="selectedId"
        :can-manage="canManage"
        :is-loading="isTreeLoading && !treeData.articles.length"
        :search-results="searchResults"
        :is-searching="isSearching"
        @toggle="toggle"
        @select="node => selectArticle(node.id)"
        @select-result="selectResult"
        @drop="onDrop"
        @action="onNodeAction"
        @expand-all="expandAll"
        @collapse-all="collapseAll"
      />

      <ArticleViewerPanel
        :article="article"
        :folder-path="folderPath"
        :is-loading="isArticleLoading && !article"
        :can-manage="canManage"
        @open-article="selectArticle"
        @open-form="openFormReference"
        @edit="current => goToEdit(current.id)"
        @new-child="current => goToNewArticle({ parent: current.id })"
      />

      <ArticleDetailsPanel
        :article="article"
        :article-node="articleNode"
        :folder-name="folderPath[folderPath.length - 1] || ''"
        @open-article="selectArticle"
        @consult-form="form => openForm(form, 'view')"
        @fill-form="form => openForm(form, 'fill')"
      />
    </div>

    <NewFolderDialog
      ref="newFolderRef"
      :portal-slug="portalSlug"
      :locale="locale"
      :folders="folderOptions"
      @created="loadTree"
    />
    <MoveArticleDialog
      ref="moveDialogRef"
      :targets="moveDialogTargets"
      @confirm="onMoveConfirm"
    />
    <ArticleFormDialog ref="formDialogRef" />
  </div>
</template>
