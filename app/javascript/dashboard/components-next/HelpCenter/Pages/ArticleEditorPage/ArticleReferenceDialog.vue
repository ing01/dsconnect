<script setup>
/**
 * "Inserir referencia": escolhe outro artigo (POP) ou um formulario e devolve o texto e o link
 * (`/dsref/article/<id>` ou `/dsref/form/<id>`) para o editor colocar no conteudo. O link e'
 * resolvido na leitura (ver Articles::ReferenceResolver no servidor).
 */
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';
import articlesAPI from 'dashboard/api/helpCenter/articles';
import FormsAPI from 'dashboard/api/forms';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  // O proprio artigo nao entra na lista (uma referencia para si mesmo nao serve).
  currentArticleId: { type: [Number, String], default: null },
  locale: { type: String, default: '' },
});

const emit = defineEmits(['insert']);

const { t } = useI18n();
const route = useRoute();

const dialogRef = ref(null);
const query = ref('');
const articles = ref([]);
const forms = ref([]);
const isLoading = ref(false);

const normalize = text =>
  String(text || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

const matches = title =>
  normalize(title).includes(normalize(query.value).trim());

const visibleArticles = computed(() =>
  articles.value.filter(
    article =>
      article.id !== Number(props.currentArticleId) && matches(article.title)
  )
);
const visibleForms = computed(() =>
  forms.value.filter(form => matches(form.name))
);

const load = async () => {
  isLoading.value = true;
  try {
    const [treeResponse, formsResponse] = await Promise.all([
      articlesAPI.getTree({
        portalSlug: route.params.portalSlug,
        locale: props.locale || route.params.locale,
      }),
      FormsAPI.get(),
    ]);
    articles.value = (treeResponse.data.articles || []).map(item =>
      camelcaseKeys(item)
    );
    // So' os publicados: o rascunho ainda nao serve para ninguem preencher.
    forms.value = (formsResponse.data?.payload || formsResponse.data || [])
      .map(item => camelcaseKeys(item))
      .filter(form => form.status === 'published');
  } catch (error) {
    articles.value = [];
    forms.value = [];
  } finally {
    isLoading.value = false;
  }
};

const open = () => {
  query.value = '';
  dialogRef.value?.open();
  load();
};

const choose = (type, item) => {
  emit('insert', {
    text: type === 'article' ? item.title : item.name,
    href: `/dsref/${type}/${item.id}`,
  });
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('HELP_CENTER.KB_TREE.REFERENCE.TITLE')"
    :description="t('HELP_CENTER.KB_TREE.REFERENCE.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="t('HELP_CENTER.KB_TREE.FORM_DIALOG.CLOSE')"
  >
    <div class="flex flex-col gap-3" data-testid="kb-reference-dialog">
      <input
        v-model="query"
        type="search"
        class="w-full mb-0 text-sm"
        :placeholder="t('HELP_CENTER.KB_TREE.REFERENCE.SEARCH')"
        data-testid="kb-reference-search"
      />

      <div v-if="isLoading" class="grid p-6 place-items-center">
        <Spinner />
      </div>

      <div v-else class="grid gap-3 overflow-y-auto max-h-80">
        <section>
          <h4 class="m-0 mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HELP_CENTER.KB_TREE.REFERENCE.ARTICLES') }}
          </h4>
          <ul class="m-0 list-none">
            <li v-for="article in visibleArticles" :key="`a-${article.id}`">
              <button
                type="button"
                class="flex items-center w-full gap-2 px-2 py-1.5 text-sm rounded-lg text-start hover:bg-n-alpha-2"
                :data-testid="`kb-reference-article-${article.id}`"
                @click="choose('article', article)"
              >
                <Icon icon="i-lucide-file-text" class="flex-shrink-0 size-4" />
                <span class="truncate">{{ article.title }}</span>
              </button>
            </li>
          </ul>
        </section>
        <section>
          <h4 class="m-0 mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HELP_CENTER.KB_TREE.REFERENCE.FORMS') }}
          </h4>
          <ul class="m-0 list-none">
            <li v-for="form in visibleForms" :key="`f-${form.id}`">
              <button
                type="button"
                class="flex items-center w-full gap-2 px-2 py-1.5 text-sm rounded-lg text-start hover:bg-n-alpha-2"
                :data-testid="`kb-reference-form-${form.id}`"
                @click="choose('form', form)"
              >
                <Icon
                  icon="i-lucide-clipboard-list"
                  class="flex-shrink-0 size-4"
                />
                <span class="truncate">{{ form.name }}</span>
              </button>
            </li>
          </ul>
        </section>
        <p
          v-if="!visibleArticles.length && !visibleForms.length"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('HELP_CENTER.KB_TREE.REFERENCE.EMPTY') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
