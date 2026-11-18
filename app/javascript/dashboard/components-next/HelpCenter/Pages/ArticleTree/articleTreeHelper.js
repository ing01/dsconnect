// Monta e consulta a arvore da Base de Conhecimento: pastas (Categorias, com subpastas) e
// artigos (com subartigos). Tudo aqui e' puro (sem Vue, sem API), para testar sem tela.
//
// Os dados chegam do servidor ja em camelCase (parentCategoryId, parentArticleId, categoryId).

export const NODE_TYPE = { FOLDER: 'folder', ARTICLE: 'article' };

// Os artigos sem pasta moram numa pasta "virtual", para nao sumirem da arvore.
export const NO_FOLDER_ID = 'none';

const byPositionThenId = (a, b) =>
  (a.position ?? 0) - (b.position ?? 0) || a.id - b.id;

const folderKey = id => `folder-${id}`;
const articleKey = id => `article-${id}`;

const articleNode = (article, childrenByParent, visited) => {
  visited.add(article.id);
  const children = (childrenByParent.get(article.id) || [])
    .filter(child => !visited.has(child.id))
    .map(child => articleNode(child, childrenByParent, visited));
  return {
    type: NODE_TYPE.ARTICLE,
    id: article.id,
    key: articleKey(article.id),
    title: article.title,
    status: article.status,
    data: article,
    children,
  };
};

/**
 * @param {Object} input
 * @param {Array} input.categories - as pastas (Categorias) do idioma
 * @param {Array} input.articles - os artigos do idioma
 * @param {string} input.noFolderLabel - o nome da pasta virtual dos artigos sem pasta
 * @returns {Array} os nos da raiz: pastas (com subpastas e artigos) e, no fim, "sem pasta"
 */
export const buildTree = ({
  categories = [],
  articles = [],
  noFolderLabel,
}) => {
  const articleIds = new Set(articles.map(article => article.id));
  const categoryIds = new Set(categories.map(category => category.id));

  // Filhos de cada artigo; o artigo cujo pai nao esta na lista (ou e' de outra pasta) vira raiz.
  const childrenByParent = new Map();
  const rootsByFolder = new Map();
  [...articles].sort(byPositionThenId).forEach(article => {
    const parentId = article.parentArticleId;
    if (parentId && articleIds.has(parentId) && parentId !== article.id) {
      if (!childrenByParent.has(parentId)) childrenByParent.set(parentId, []);
      childrenByParent.get(parentId).push(article);
      return;
    }
    const folderId = categoryIds.has(article.categoryId)
      ? article.categoryId
      : NO_FOLDER_ID;
    if (!rootsByFolder.has(folderId)) rootsByFolder.set(folderId, []);
    rootsByFolder.get(folderId).push(article);
  });

  const visited = new Set();
  const articlesOf = folderId =>
    (rootsByFolder.get(folderId) || []).map(article =>
      articleNode(article, childrenByParent, visited)
    );

  const subfoldersByParent = new Map();
  [...categories].sort(byPositionThenId).forEach(category => {
    const parentId = categoryIds.has(category.parentCategoryId)
      ? category.parentCategoryId
      : null;
    if (!subfoldersByParent.has(parentId)) subfoldersByParent.set(parentId, []);
    subfoldersByParent.get(parentId).push(category);
  });

  const seenFolders = new Set();
  const folderNode = category => {
    seenFolders.add(category.id);
    const subfolders = (subfoldersByParent.get(category.id) || [])
      .filter(sub => !seenFolders.has(sub.id))
      .map(folderNode);
    return {
      type: NODE_TYPE.FOLDER,
      id: category.id,
      key: folderKey(category.id),
      title: category.name,
      data: category,
      children: [...subfolders, ...articlesOf(category.id)],
    };
  };

  const tree = (subfoldersByParent.get(null) || []).map(folderNode);
  const orphans = articlesOf(NO_FOLDER_ID);
  if (orphans.length) {
    tree.push({
      type: NODE_TYPE.FOLDER,
      id: NO_FOLDER_ID,
      key: folderKey(NO_FOLDER_ID),
      title: noFolderLabel,
      data: null,
      virtual: true,
      children: orphans,
    });
  }
  return tree;
};

/** Percorre a arvore (pre-ordem) devolvendo os nos numa lista simples. */
export const flattenTree = (nodes, depth = 0) =>
  nodes.flatMap(node => [
    { node, depth },
    ...flattenTree(node.children, depth + 1),
  ]);

/** As chaves de todas as pastas e artigos que tem filhos (para "expandir tudo"). */
export const expandableKeys = nodes =>
  flattenTree(nodes)
    .filter(({ node }) => node.children.length)
    .map(({ node }) => node.key);

/** As chaves a abrir para que o artigo apareca na arvore (a pasta, as subpastas e os pais). */
export const pathKeysTo = (nodes, articleId) => {
  const walk = (list, trail) => {
    for (let i = 0; i < list.length; i += 1) {
      const node = list[i];
      if (node.type === NODE_TYPE.ARTICLE && node.id === articleId) {
        return trail;
      }
      const found = walk(node.children, [...trail, node.key]);
      if (found) return found;
    }
    return null;
  };
  return walk(nodes, []) || [];
};

/** O no de um artigo na arvore, ou null. */
export const findArticleNode = (nodes, articleId) =>
  flattenTree(nodes).find(
    ({ node }) => node.type === NODE_TYPE.ARTICLE && node.id === articleId
  )?.node || null;

/** O artigo e todos os subartigos dele (ids). Serve para impedir mover um pai para dentro do filho. */
export const descendantIds = node =>
  flattenTree(node.children).map(({ node: child }) => child.id);

/**
 * O que o servidor deve fazer ao soltar `dragged` (um artigo) sobre `target`:
 * - sobre uma pasta: vai para a raiz dela (no fim);
 * - sobre um artigo: vira subartigo dele (no fim).
 * Devolve null quando o movimento nao faz sentido (sobre si mesmo, sobre um descendente,
 * sobre a pasta virtual "sem pasta" ou para onde ja esta).
 */
export const dropAction = (dragged, target) => {
  if (dragged.type !== NODE_TYPE.ARTICLE || !target) return null;
  if (target.type === NODE_TYPE.ARTICLE) {
    if (target.id === dragged.id) return null;
    if (descendantIds(dragged).includes(target.id)) return null;
    if (dragged.data.parentArticleId === target.id) return null;
    return { parentArticleId: target.id, categoryId: null };
  }
  if (target.virtual) return null;
  if (!dragged.data.parentArticleId && dragged.data.categoryId === target.id) {
    return null;
  }
  return { parentArticleId: null, categoryId: target.id };
};

/**
 * Sobe ou desce um artigo entre os irmaos. Devolve { parentArticleId, categoryId, index } para o
 * `move`, ou null quando ja esta na ponta.
 */
export const reorderAction = (nodes, articleId, direction) => {
  const siblingsOf = list => {
    const direct = list.find(
      node => node.type === NODE_TYPE.ARTICLE && node.id === articleId
    );
    if (direct) return list;
    return list.reduce(
      (found, node) => found || siblingsOf(node.children),
      null
    );
  };
  const siblings = siblingsOf(nodes);
  if (!siblings) return null;

  const articlesOnly = siblings.filter(node => node.type === NODE_TYPE.ARTICLE);
  const current = articlesOnly.findIndex(node => node.id === articleId);
  const target = current + (direction === 'up' ? -1 : 1);
  if (target < 0 || target >= articlesOnly.length) return null;

  const { parentArticleId, categoryId } = articlesOnly[current].data;
  return {
    parentArticleId: parentArticleId || null,
    categoryId,
    index: target,
  };
};

/** Opcoes "Mover para..." com recuo: as pastas e os artigos que podem receber o artigo. */
export const moveTargets = (nodes, node) => {
  const blocked = new Set([node.id, ...descendantIds(node)]);
  return flattenTree(nodes)
    .filter(({ node: candidate }) => {
      if (candidate.virtual) return false;
      if (candidate.type === NODE_TYPE.ARTICLE) {
        return !blocked.has(candidate.id);
      }
      return true;
    })
    .map(({ node: candidate, depth }) => ({
      type: candidate.type,
      id: candidate.id,
      label: candidate.title,
      depth,
    }));
};
