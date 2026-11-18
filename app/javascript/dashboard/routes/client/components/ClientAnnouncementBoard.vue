<script setup>
/**
 * O Mural de Avisos na tela Principal do Portal: todos os avisos em vigor para
 * esta pessoa, mesmo os que ela já fechou no modal do login. Sem avisos, o
 * bloco inteiro some (não ocupa espaço).
 */
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useClientAnnouncements } from 'dashboard/composables/useClientAnnouncements';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { announcementKind, formatAnnouncementDate } from '../announcementKinds';

const { t } = useI18n({ useScope: 'global' });
const { announcements, load } = useClientAnnouncements();

onMounted(() => load());
</script>

<template>
  <section v-if="announcements.length" data-testid="announcement-board">
    <h2 class="mb-1 text-lg font-semibold text-n-slate-12">
      {{ t('CLIENT_AREA.ANNOUNCEMENTS.TITLE') }}
    </h2>
    <p class="mb-4 text-sm text-n-slate-11">
      {{ t('CLIENT_AREA.ANNOUNCEMENTS.SUBTITLE') }}
    </p>

    <div class="flex flex-col gap-3">
      <article
        v-for="item in announcements"
        :key="item.id"
        class="flex items-start gap-3 p-4 border rounded-xl"
        :class="announcementKind(item.kind).card"
        :data-testid="`announcement-${item.id}`"
      >
        <span
          class="flex items-center justify-center flex-shrink-0 rounded-full size-9"
          :class="announcementKind(item.kind).iconWrap"
        >
          <Icon :icon="announcementKind(item.kind).icon" class="size-4" />
        </span>
        <div class="flex flex-col min-w-0 gap-1">
          <h3 class="m-0 text-base font-semibold break-words text-n-slate-12">
            {{ item.title }}
          </h3>
          <span
            v-if="item.published_at"
            class="text-xs text-n-slate-11"
            :data-testid="`announcement-date-${item.id}`"
          >
            {{
              t('CLIENT_AREA.ANNOUNCEMENTS.DATE', {
                date: formatAnnouncementDate(item.published_at),
              })
            }}
          </span>
          <p
            v-if="item.body"
            class="m-0 text-sm break-words whitespace-pre-line text-n-slate-12"
          >
            {{ item.body }}
          </p>
          <a
            v-if="item.link_url"
            :href="item.link_url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1 mt-1 text-sm font-medium text-n-brand hover:underline"
          >
            {{ item.link_label || t('CLIENT_AREA.ANNOUNCEMENTS.OPEN_LINK') }}
            <Icon icon="i-lucide-external-link" class="size-3.5" />
          </a>
        </div>
      </article>
    </div>
  </section>
</template>
