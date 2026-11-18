import {
  buildTree,
  flattenTree,
  expandableKeys,
  pathKeysTo,
  findArticleNode,
  descendantIds,
  dropAction,
  reorderAction,
  moveTargets,
  NODE_TYPE,
} from '../articleTreeHelper';

const categories = [
  { id: 2, name: 'Sistemas', position: 20, parentCategoryId: null },
  { id: 1, name: 'Processos (POPs)', position: 10, parentCategoryId: null },
  { id: 3, name: 'ERP', position: 10, parentCategoryId: 2 },
];

const articles = [
  {
    id: 11,
    title: 'POP 1',
    position: 10,
    categoryId: 1,
    parentArticleId: null,
  },
  {
    id: 12,
    title: 'POP 1.1',
    position: 10,
    categoryId: 1,
    parentArticleId: 11,
  },
  {
    id: 13,
    title: 'POP 1.2',
    position: 20,
    categoryId: 1,
    parentArticleId: 11,
  },
  {
    id: 14,
    title: 'POP 2',
    position: 20,
    categoryId: 1,
    parentArticleId: null,
  },
  { id: 21, title: 'Emissão de Nota Fiscal', position: 10, categoryId: 3 },
  { id: 99, title: 'Solto', position: 10, categoryId: null },
];

const tree = () =>
  buildTree({ categories, articles, noFolderLabel: 'Sem pasta' });

describe('buildTree', () => {
  it('puts the folders in order, with the subfolders before the articles', () => {
    const roots = tree();

    expect(roots.map(node => node.title)).toEqual([
      'Processos (POPs)',
      'Sistemas',
      'Sem pasta',
    ]);
    const systems = roots[1];
    expect(systems.children.map(node => node.title)).toEqual(['ERP']);
    expect(systems.children[0].children.map(node => node.title)).toEqual([
      'Emissão de Nota Fiscal',
    ]);
  });

  it('nests the sub-articles under the parent article, without a folder in between', () => {
    const pops = tree()[0];

    expect(pops.children.map(node => node.title)).toEqual(['POP 1', 'POP 2']);
    expect(pops.children[0].children.map(node => node.title)).toEqual([
      'POP 1.1',
      'POP 1.2',
    ]);
  });

  it('keeps the articles without a folder in a virtual folder', () => {
    const loose = tree()[2];

    expect(loose.virtual).toBe(true);
    expect(loose.children.map(node => node.id)).toEqual([99]);
  });

  it('does not show the virtual folder when everything has a folder', () => {
    const roots = buildTree({
      categories,
      articles: articles.filter(article => article.id !== 99),
      noFolderLabel: 'Sem pasta',
    });

    expect(roots.some(node => node.virtual)).toBe(false);
  });

  it('treats an article whose parent is missing as a root of its folder', () => {
    const roots = buildTree({
      categories,
      articles: [
        { id: 1, title: 'A', position: 1, categoryId: 1, parentArticleId: 404 },
      ],
      noFolderLabel: 'Sem pasta',
    });

    expect(roots[0].children.map(node => node.id)).toEqual([1]);
  });

  it('survives a loop in the data', () => {
    const roots = buildTree({
      categories,
      articles: [
        { id: 1, title: 'A', position: 1, categoryId: 1, parentArticleId: 2 },
        { id: 2, title: 'B', position: 1, categoryId: 1, parentArticleId: 1 },
      ],
      noFolderLabel: 'Sem pasta',
    });

    expect(flattenTree(roots).length).toBeLessThan(10);
  });
});

describe('paths and lookups', () => {
  it('lists what to open to reveal an article', () => {
    expect(pathKeysTo(tree(), 12)).toEqual(['folder-1', 'article-11']);
    expect(pathKeysTo(tree(), 21)).toEqual(['folder-2', 'folder-3']);
    expect(pathKeysTo(tree(), 777)).toEqual([]);
  });

  it('finds an article node and its descendants', () => {
    const pop1 = findArticleNode(tree(), 11);

    expect(pop1.title).toBe('POP 1');
    expect(descendantIds(pop1)).toEqual([12, 13]);
  });

  it('lists the nodes that can be expanded', () => {
    expect(expandableKeys(tree())).toEqual(
      expect.arrayContaining(['folder-1', 'article-11', 'folder-2', 'folder-3'])
    );
  });
});

describe('dropAction', () => {
  const pop1 = () => findArticleNode(tree(), 11);
  const pop2 = () => findArticleNode(tree(), 14);

  it('makes the dragged article a child of the target article', () => {
    expect(dropAction(pop2(), pop1())).toEqual({
      parentArticleId: 11,
      categoryId: null,
    });
  });

  it('takes the article to the root of the target folder', () => {
    const systems = tree()[1];

    expect(dropAction(pop2(), systems)).toEqual({
      parentArticleId: null,
      categoryId: 2,
    });
  });

  it('refuses a parent being dropped into its own child, or itself', () => {
    const child = findArticleNode(tree(), 12);

    expect(dropAction(pop1(), child)).toBeNull();
    expect(dropAction(pop1(), pop1())).toBeNull();
  });

  it('refuses moves that change nothing, the virtual folder and folders as dragged items', () => {
    const [pops, , loose] = tree();

    expect(dropAction(pop2(), pops)).toBeNull();
    expect(dropAction(findArticleNode(tree(), 12), pop1())).toBeNull();
    expect(dropAction(pop2(), loose)).toBeNull();
    expect(dropAction({ type: NODE_TYPE.FOLDER }, pops)).toBeNull();
  });

  it('lets a child go back to the root of its folder', () => {
    const child = findArticleNode(tree(), 12);

    expect(dropAction(child, tree()[0])).toEqual({
      parentArticleId: null,
      categoryId: 1,
    });
  });
});

describe('reorderAction', () => {
  it('moves an article up or down among its siblings', () => {
    expect(reorderAction(tree(), 14, 'up')).toEqual({
      parentArticleId: null,
      categoryId: 1,
      index: 0,
    });
    expect(reorderAction(tree(), 12, 'down')).toEqual({
      parentArticleId: 11,
      categoryId: 1,
      index: 1,
    });
  });

  it('does nothing at the ends', () => {
    expect(reorderAction(tree(), 11, 'up')).toBeNull();
    expect(reorderAction(tree(), 14, 'down')).toBeNull();
    expect(reorderAction(tree(), 404, 'up')).toBeNull();
  });
});

describe('moveTargets', () => {
  it('offers folders and articles, but never the article itself or its descendants', () => {
    const pop1 = findArticleNode(tree(), 11);
    const labels = moveTargets(tree(), pop1).map(target => target.label);

    expect(labels).toContain('Sistemas');
    expect(labels).toContain('POP 2');
    expect(labels).not.toContain('POP 1');
    expect(labels).not.toContain('POP 1.1');
    expect(labels).not.toContain('Sem pasta');
  });
});
