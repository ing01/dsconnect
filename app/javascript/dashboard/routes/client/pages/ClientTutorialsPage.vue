<script setup>
/**
 * A aba "Tutoriais" da Área do Cliente: vídeos e textos cadastrados pela equipe
 * em Configurações > Tickets > Tutoriais do Portal. Só os ativos, na ordem
 * definida pelo administrador.
 */
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import { tutorialVideo } from 'dashboard/helper/tutorialVideo';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';

const { t } = useI18n();

const tutorials = ref([]);
const isLoading = ref(true);
const hasError = ref(false);

const load = async () => {
  try {
    const { data } = await ClientAreaAPI.tutorials();
    tutorials.value = data.map(tutorial => ({
      ...tutorial,
      video: tutorialVideo(tutorial),
    }));
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4 p-4 overflow-y-auto sm:p-6">
    <div class="flex flex-col gap-1">
      <h2 class="m-0 text-lg font-medium text-n-slate-12">
        {{ t('CLIENT_AREA.TUTORIALS.TITLE') }}
      </h2>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.TUTORIALS.DESCRIPTION') }}
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

    <article
      v-for="tutorial in tutorials"
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
