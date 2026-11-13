<script setup>
/**
 * A aba "Tutoriais" da Área do Cliente: os módulos (DS Connect, DS Comercial...)
 * aparecem como cards; ao clicar, abrem os vídeos que estão dentro. Tudo é
 * cadastrado pela equipe em Configurações > Tutoriais do Portal; só os
 * ativos aparecem, na ordem definida pelo administrador.
 *
 * Tutorial sem módulo cai no card "Geral". Sem nenhum módulo cadastrado, a lista
 * de vídeos aparece direto, sem os cards.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import { tutorialVideo } from 'dashboard/helper/tutorialVideo';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';

const GENERAL = 'general';

const { t } = useI18n();

const modules = ref([]);
const tutorials = ref([]);
const isLoading = ref(true);
const hasError = ref(false);
// Card aberto: id do módulo, 'general', ou null (mostrando os cards).
const selected = ref(null);

const load = async () => {
  try {
    const { data } = await ClientAreaAPI.tutorials();
    modules.value = data.modules || [];
    tutorials.value = (data.tutorials || []).map(tutorial => ({
      ...tutorial,
      video: tutorialVideo(tutorial),
    }));
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const tutorialsOf = key =>
  tutorials.value.filter(tutorial =>
    key === GENERAL ? !tutorial.module_id : tutorial.module_id === key
  );

// Só módulos com vídeo viram card (um card vazio só confunde o cliente).
const cards = computed(() => {
  const list = modules.value
    .map(module => ({ ...module, count: tutorialsOf(module.id).length }))
    .filter(card => card.count > 0);

  const loose = tutorialsOf(GENERAL).length;
  if (loose && list.length) {
    list.push({
      id: GENERAL,
      name: t('CLIENT_AREA.TUTORIALS.GENERAL'),
      description: null,
      count: loose,
    });
  }
  return list;
});

const hasCards = computed(() => cards.value.length > 0);
const openCard = computed(() =>
  cards.value.find(card => card.id === selected.value)
);
const visibleTutorials = computed(() => {
  if (!hasCards.value) return tutorials.value;
  return openCard.value ? tutorialsOf(openCard.value.id) : [];
});

onMounted(load);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4 p-4 overflow-y-auto sm:p-6">
    <div class="flex flex-col gap-1">
      <button
        v-if="openCard"
        type="button"
        class="flex items-center self-start gap-1 p-0 text-sm text-n-slate-11 hover:text-n-slate-12"
        data-testid="tutorials-back"
        @click="selected = null"
      >
        <Icon icon="i-lucide-arrow-left" class="size-4" />
        {{ t('CLIENT_AREA.TUTORIALS.BACK') }}
      </button>
      <h2 class="m-0 text-lg font-medium text-n-slate-12">
        {{ openCard ? openCard.name : t('CLIENT_AREA.TUTORIALS.TITLE') }}
      </h2>
      <p class="m-0 text-sm text-n-slate-11">
        {{
          openCard
            ? openCard.description || ''
            : t('CLIENT_AREA.TUTORIALS.DESCRIPTION')
        }}
      </p>
    </div>

    <PageLoader v-if="isLoading" />

    <p v-else-if="hasError" class="m-0 text-sm text-n-ruby-11">
      {{ t('CLIENT_AREA.TUTORIALS.ERROR') }}
    </p>

    <p
      v-else-if="!tutorials.length"
      class="m-0 text-sm text-n-slate-11"
      data-testid="tutorials-empty"
    >
      {{ t('CLIENT_AREA.TUTORIALS.EMPTY') }}
    </p>

    <!-- Os módulos, como cards. -->
    <div
      v-else-if="hasCards && !openCard"
      class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
    >
      <button
        v-for="card in cards"
        :key="card.id"
        type="button"
        class="flex flex-col items-start gap-2 p-4 text-left border rounded-xl border-n-weak bg-n-solid-1 hover:border-n-brand hover:bg-n-alpha-1"
        :data-testid="`tutorial-module-${card.id}`"
        @click="selected = card.id"
      >
        <img
          v-if="card.logo_url"
          :src="card.logo_url"
          :alt="card.name"
          class="object-contain h-14 max-w-[10rem]"
          data-testid="module-logo"
        />
        <Icon v-else icon="i-lucide-circle-play" class="size-8 text-n-brand" />
        <span class="text-base font-medium text-n-slate-12">
          {{ card.name }}
        </span>
        <span
          v-if="card.description"
          class="text-sm text-n-slate-11 line-clamp-2"
        >
          {{ card.description }}
        </span>
        <span class="mt-auto text-xs text-n-slate-10">
          {{ t('CLIENT_AREA.TUTORIALS.VIDEO_COUNT', { count: card.count }) }}
        </span>
      </button>
    </div>

    <article
      v-for="tutorial in visibleTutorials"
      :key="tutorial.id"
      class="flex flex-col w-full max-w-3xl gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
      :data-testid="`tutorial-${tutorial.id}`"
    >
      <h3 class="m-0 text-base font-medium text-n-slate-12">
        {{ tutorial.title }}
      </h3>

      <div class="overflow-hidden rounded-lg aspect-video bg-n-solid-2">
        <iframe
          v-if="tutorial.video?.type === 'iframe'"
          :src="tutorial.video.src"
          :title="tutorial.title"
          class="w-full h-full border-0"
          allow="accelerometer; encrypted-media; picture-in-picture; fullscreen"
          allowfullscreen
        />
        <video
          v-else-if="tutorial.video?.type === 'video'"
          :src="tutorial.video.src"
          class="w-full h-full"
          controls
          preload="metadata"
        />
        <div
          v-else
          class="flex flex-col items-center justify-center h-full gap-2 text-sm text-n-slate-10"
          data-testid="tutorial-video-soon"
        >
          <Icon icon="i-lucide-circle-play" class="size-10" />
          {{ t('CLIENT_AREA.TUTORIALS.VIDEO_SOON') }}
        </div>
      </div>

      <p
        v-if="tutorial.description"
        class="m-0 text-sm whitespace-pre-line text-n-slate-12"
      >
        {{ tutorial.description }}
      </p>
    </article>
  </div>
</template>
