<script setup>
/**
 * A aba "Tutoriais" da Área do Cliente: vídeos curtos com o passo a passo de
 * recursos do Portal. A lista e os vídeos vêm de `tutorialsData.js`.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { TUTORIALS, resolveTutorialVideo } from '../tutorialsData';

const { t } = useI18n();

const tutorials = computed(() =>
  TUTORIALS.map(tutorial => ({
    ...tutorial,
    video: resolveTutorialVideo(tutorial.videoUrl),
    steps: [1, 2, 3, 4, 5].map(n =>
      t(`CLIENT_AREA.TUTORIALS.${tutorial.key}.STEP_${n}`)
    ),
  }))
);
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

    <article
      v-for="tutorial in tutorials"
      :key="tutorial.id"
      class="flex flex-col w-full max-w-3xl gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
      :data-testid="`tutorial-${tutorial.id}`"
    >
      <div class="flex items-center gap-2">
        <Icon :icon="tutorial.icon" class="flex-shrink-0 size-5 text-n-brand" />
        <h3 class="m-0 text-base font-medium text-n-slate-12">
          {{ t(`CLIENT_AREA.TUTORIALS.${tutorial.key}.TITLE`) }}
        </h3>
      </div>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t(`CLIENT_AREA.TUTORIALS.${tutorial.key}.DESCRIPTION`) }}
      </p>

      <div class="overflow-hidden rounded-lg aspect-video bg-n-solid-2">
        <iframe
          v-if="tutorial.video?.type === 'iframe'"
          :src="tutorial.video.src"
          :title="t(`CLIENT_AREA.TUTORIALS.${tutorial.key}.TITLE`)"
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

      <ol class="flex flex-col gap-1 pl-5 m-0 text-sm text-n-slate-12">
        <li v-for="(step, index) in tutorial.steps" :key="index">
          {{ step }}
        </li>
      </ol>
    </article>
  </div>
</template>
