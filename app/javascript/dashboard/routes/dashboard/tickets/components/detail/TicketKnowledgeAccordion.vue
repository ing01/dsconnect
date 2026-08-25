<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import ArticlesAPI from 'dashboard/api/helpCenter/articles';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const RESULT_LIMIT = 5;

const { t } = useI18n();
const store = useStore();

const articles = ref([]);
const isLoading = ref(false);
const hasLoaded = ref(false);
const hasPortal = ref(true);

// Article search is always portal-scoped, so the account's first portal is used.
// No portal configured is a legitimate state, not an error.
const load = async () => {
  if (hasLoaded.value) return;

  isLoading.value = true;
  try {
    await store.dispatch('portals/index');
    const portal = store.getters['portals/allPortals']?.[0];
    if (!portal) {
      hasPortal.value = false;
      return;
    }

    const { data } = await ArticlesAPI.getArticles({
      portalSlug: portal.slug,
      query: props.ticket.title,
      status: 'published',
    });
    articles.value = (data?.payload || []).slice(0, RESULT_LIMIT);
  } catch (error) {
    articles.value = [];
  } finally {
    hasLoaded.value = true;
    isLoading.value = false;
  }
};
</script>

<template>
  <Accordion
    :title="t('TICKET.DETAIL.KNOWLEDGE.TITLE')"
    @toggle="expanded => expanded && load()"
  >
    <div class="pt-2">
      <div v-if="isLoading" class="flex justify-center py-3">
        <Spinner :size="20" />
      </div>

      <p v-else-if="!hasPortal" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.KNOWLEDGE.NO_PORTAL') }}
      </p>

      <p v-else-if="!articles.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.KNOWLEDGE.EMPTY') }}
      </p>

      <ul v-else class="flex flex-col gap-1">
        <li v-for="article in articles" :key="article.id">
          <span
            class="block px-2 py-1.5 text-sm rounded-lg text-n-slate-12 truncate"
            :title="article.title"
          >
            {{ article.title }}
          </span>
        </li>
      </ul>
    </div>
  </Accordion>
</template>
