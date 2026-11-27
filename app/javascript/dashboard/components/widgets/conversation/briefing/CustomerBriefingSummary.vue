<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CustomerBriefingAPI from 'dashboard/api/customerBriefing';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  companyId: { type: Number, default: null },
});

const { t } = useI18n();

const result = ref(null);
const isLoading = ref(false);
const errorMessage = ref('');

const load = async ({ force = false } = {}) => {
  isLoading.value = true;
  errorMessage.value = '';

  try {
    const { data } = await CustomerBriefingAPI.summarize(props.conversationId, {
      companyId: props.companyId,
      force,
    });
    result.value = data;
  } catch (error) {
    errorMessage.value =
      error?.response?.data?.error || t('CUSTOMER_BRIEFING.AI.ERROR');
  } finally {
    isLoading.value = false;
  }
};

const lists = computed(() => {
  const summary = result.value?.summary;
  if (!summary) return [];

  return [
    ['RECENT_TOPICS', summary.recent_topics],
    ['PENDING', summary.pending_items],
    ['ATTENTION', summary.attention_points],
  ].filter(([, items]) => items?.length);
});

const generatedAt = computed(() =>
  result.value?.generated_at
    ? new Date(result.value.generated_at * 1000).toLocaleString('pt-BR', {
        dateStyle: 'short',
        timeStyle: 'short',
      })
    : ''
);

onMounted(load);
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak bg-n-alpha-1"
    :aria-busy="isLoading"
  >
    <div class="flex items-center justify-between gap-2">
      <h4
        class="flex items-center gap-1.5 m-0 text-sm font-semibold text-n-slate-12"
      >
        <Icon icon="i-lucide-sparkles" class="size-4 text-n-blue-11" />
        {{ t('CUSTOMER_BRIEFING.AI.TITLE') }}
      </h4>
      <Button
        v-if="result?.summary"
        type="button"
        size="xs"
        variant="ghost"
        color="slate"
        icon="i-lucide-refresh-cw"
        data-testid="briefing-refresh"
        :label="t('CUSTOMER_BRIEFING.AI.REFRESH')"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="load({ force: true })"
      />
    </div>

    <p v-if="isLoading && !result" class="m-0 text-sm text-n-slate-11">
      {{ t('CUSTOMER_BRIEFING.AI.LOADING') }}
    </p>

    <div v-if="errorMessage" class="flex flex-col items-start gap-2">
      <p class="m-0 text-sm text-n-ruby-11" role="alert">{{ errorMessage }}</p>
      <Button
        type="button"
        size="xs"
        variant="faded"
        color="slate"
        data-testid="briefing-summary-retry"
        :label="t('CUSTOMER_BRIEFING.RETRY')"
        :disabled="isLoading"
        @click="load()"
      />
    </div>

    <p v-if="result?.empty" class="m-0 text-sm text-n-slate-11">
      {{ t('CUSTOMER_BRIEFING.AI.EMPTY') }}
    </p>

    <template v-if="result?.summary">
      <p
        v-if="result.summary.overview"
        class="m-0 text-sm break-words text-n-slate-12"
      >
        {{ result.summary.overview }}
      </p>
      <div v-for="[key, items] in lists" :key="key" class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-10">
          {{ t(`CUSTOMER_BRIEFING.AI.${key}`) }}
        </span>
        <ul class="flex flex-col gap-0.5 m-0 ps-4 list-disc">
          <li
            v-for="(item, index) in items"
            :key="index"
            class="text-sm break-words text-n-slate-12"
          >
            {{ item }}
          </li>
        </ul>
      </div>
      <p class="m-0 text-xs text-n-slate-10">
        {{ t('CUSTOMER_BRIEFING.AI.DISCLAIMER', { time: generatedAt }) }}
      </p>
    </template>
  </section>
</template>
