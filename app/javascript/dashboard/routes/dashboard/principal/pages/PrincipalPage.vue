<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useGreeting } from 'dashboard/composables/useGreeting';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ChangelogEntryCard from '../components/ChangelogEntryCard.vue';
import SuggestionFormDialog from '../components/SuggestionFormDialog.vue';
import { getVisibleChangelogEntries } from '../changelogData';

const { t } = useI18n();
const store = useStore();
const { greetingMessage, globalConfig } = useGreeting();

const visibleChangelogEntries = computed(() => getVisibleChangelogEntries());

const suggestionDialog = ref(null);
const isSubmittingSuggestion = ref(false);

const openSuggestionDialog = () => suggestionDialog.value?.open();

const submitSuggestion = async ({ title, description }) => {
  isSubmittingSuggestion.value = true;
  try {
    await store.dispatch('suggestions/create', { title, description });
    suggestionDialog.value?.close();
    useAlert(t('PRINCIPAL.SUGGESTIONS.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('PRINCIPAL.SUGGESTIONS.ERROR_MESSAGE'));
  } finally {
    isSubmittingSuggestion.value = false;
  }
};
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

    <div
      class="flex items-center justify-between gap-4 p-5 mt-8 rounded-2xl border border-n-weak bg-n-solid-1"
    >
      <div>
        <h2 class="mb-1 text-base font-semibold text-n-slate-12">
          {{ $t('PRINCIPAL.SUGGESTIONS.BANNER_TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('PRINCIPAL.SUGGESTIONS.BANNER_SUBTITLE') }}
        </p>
      </div>
      <NextButton
        icon="i-lucide-lightbulb"
        :label="$t('PRINCIPAL.SUGGESTIONS.BANNER_BUTTON')"
        @click="openSuggestionDialog"
      />
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

    <SuggestionFormDialog
      ref="suggestionDialog"
      :is-loading="isSubmittingSuggestion"
      @submit="submitSuggestion"
    />
  </div>
</template>
