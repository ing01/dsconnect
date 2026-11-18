/* global axios */

import PortalsAPI from './portals';
import { getArticleSearchURL } from 'dashboard/helper/URLHelper.js';

class ArticlesAPI extends PortalsAPI {
  constructor() {
    super('articles', { accountScoped: true });
  }

  getArticles({
    pageNumber,
    portalSlug,
    locale,
    status,
    authorId,
    categorySlug,
    sort,
    query,
    signal,
  }) {
    const url = getArticleSearchURL({
      pageNumber,
      portalSlug,
      locale,
      status,
      authorId,
      categorySlug,
      sort,
      query,
      host: this.url,
    });

    return axios.get(url, { signal });
  }

  searchArticles({ portalSlug, query }) {
    const url = getArticleSearchURL({
      portalSlug,
      query,
      host: this.url,
    });
    return axios.get(url);
  }

  getArticle({ id, portalSlug }) {
    return axios.get(`${this.url}/${portalSlug}/articles/${id}`);
  }

  updateArticle({ portalSlug, articleId, articleObj }) {
    return axios.patch(
      `${this.url}/${portalSlug}/articles/${articleId}`,
      articleObj
    );
  }

  createArticle({ portalSlug, articleObj }) {
    const { content, title, authorId, categoryId, locale, parentArticleId } =
      articleObj;
    return axios.post(`${this.url}/${portalSlug}/articles`, {
      content,
      title,
      author_id: authorId,
      category_id: categoryId,
      locale,
      // Subartigo: o servidor o coloca na pasta do pai.
      ...(parentArticleId ? { parent_article_id: parentArticleId } : {}),
    });
  }

  // A arvore inteira do idioma (pastas + artigos, so os campos leves).
  getTree({ portalSlug, locale }) {
    return axios.get(`${this.url}/${portalSlug}/articles/tree`, {
      params: { locale },
    });
  }

  // Reorganiza: leva o artigo (e os subartigos) para outra pasta ou para baixo de outro artigo.
  moveArticle({ portalSlug, articleId, parentArticleId, categoryId, index }) {
    return axios.patch(`${this.url}/${portalSlug}/articles/${articleId}/move`, {
      parent_article_id: parentArticleId || null,
      category_id: categoryId || null,
      index,
    });
  }

  deleteArticle({ articleId, portalSlug }) {
    return axios.delete(`${this.url}/${portalSlug}/articles/${articleId}`);
  }

  reorderArticles({ portalSlug, reorderedGroup, categorySlug }) {
    return axios.post(`${this.url}/${portalSlug}/articles/reorder`, {
      positions_hash: reorderedGroup,
      category_slug: categorySlug,
    });
  }

  bulkTranslate({ portalSlug, articleIds, locale, categoryId, force = false }) {
    return axios.post(
      `${this.url}/${portalSlug}/articles/bulk_actions/translate`,
      { ids: articleIds, locale, category_id: categoryId, force }
    );
  }

  bulkUpdateStatus({ portalSlug, articleIds, status }) {
    return axios.patch(
      `${this.url}/${portalSlug}/articles/bulk_actions/update_status`,
      { ids: articleIds, status }
    );
  }

  bulkUpdateCategory({ portalSlug, articleIds, categoryId }) {
    return axios.patch(
      `${this.url}/${portalSlug}/articles/bulk_actions/update_category`,
      { ids: articleIds, category_id: categoryId }
    );
  }

  bulkDelete({ portalSlug, articleIds }) {
    return axios.delete(
      `${this.url}/${portalSlug}/articles/bulk_actions/delete_articles`,
      { data: { ids: articleIds } }
    );
  }
}

export default new ArticlesAPI();
