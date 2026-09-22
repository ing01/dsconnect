<script setup>
import { computed } from 'vue';
import { useGreeting } from 'dashboard/composables/useGreeting';
import ChangelogEntryCard from '../components/ChangelogEntryCard.vue';
import { getVisibleChangelogEntries } from '../changelogData';

const { greetingMessage, globalConfig } = useGreeting();

const visibleChangelogEntries = computed(() => getVisibleChangelogEntries());
</script>

<template>
  <div
    class="min-h-screen max-w-4xl px-8 py-8 mx-auto overflow-auto lg:max-w-5xl font-inter"
  >
    <div
      class="flex flex-col items-center gap-4 p-8 text-center rounded-2xl sm:flex-row sm:text-left bg-gradient-to-br from-n-blue-3 to-n-teal-3"
    >
      <img
        v-if="globalConfig.logoThumbnail"
        :src="globalConfig.logoThumbnail"
        alt=""
        class="flex-shrink-0 size-16"
      />
      <div>
        <p
          class="text-2xl font-semibold text-n-slate-12 font-interDisplay tracking-[0.3px]"
        >
          {{ greetingMessage }}
        </p>
        <p class="mt-1 text-base text-n-slate-11 max-w-2xl">
          {{
            $t('ONBOARDING.DESCRIPTION', {
              installationName: globalConfig.installationName,
            })
          }}
        </p>
      </div>
    </div>

    <div class="mt-8">
      <h2 class="mb-1 text-lg font-semibold text-n-slate-12">
        {{ $t('PRINCIPAL.WHATS_NEW_TITLE') }}
      </h2>
      <p class="mb-4 text-sm text-n-slate-11">
        {{ $t('PRINCIPAL.WHATS_NEW_SUBTITLE') }}
      </p>
      <div class="flex flex-col gap-3">
        <ChangelogEntryCard
          v-for="entry in visibleChangelogEntries"
          :key="entry.id"
          v-bind="entry"
        />
      </div>
    </div>
  </div>
</template>
