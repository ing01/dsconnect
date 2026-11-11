<script setup>
import { computed } from 'vue';
import { formatNumber } from '@chatwoot/utils';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  // Busca rapida por nome ou empresa, so' na lista ja' carregada - pedido da
  // Ingrid, 2026-11-10.
  searchQuery: { type: String, default: '' },
  // Filtro rapido por periodo (dia especifico ou intervalo), tambem so' na
  // lista ja' carregada - pedido da Ingrid, 2026-11-11. Fica fixo do lado do
  // botao "Filtrar conversas", nao embaixo da busca (ficava estranho ali).
  dateFrom: { type: String, default: '' },
  dateTo: { type: String, default: '' },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'update:searchQuery',
  'update:dateFrom',
  'update:dateTo',
]);

const hasDateFilter = computed(() => !!(props.dateFrom || props.dateTo));

const clearDateFilter = () => {
  emit('update:dateFrom', '');
  emit('update:dateTo', '');
};

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

// "Pausadas" no lugar de "Pendentes" - pedido da Ingrid, 2026-11-11 (quem
// precisa ver pendentes usa o filtro avancado; o dia a dia e abrir/pausar/
// resolver).
const QUICK_STATUSES = ['open', 'snoozed', 'resolved'];
</script>

<template>
  <div
    class="flex flex-col gap-2 px-3 pt-2 pb-2"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <!-- Linha superior: título + botão Nova Conversa -->
    <div class="flex items-center justify-between gap-2 min-w-0">
      <div class="flex items-center min-w-0 gap-1.5">
        <h1
          class="text-base font-semibold truncate text-n-slate-12"
          :title="pageTitle"
        >
          {{ pageTitle }}
        </h1>
        <span
          v-if="
            allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
          "
          class="px-2 py-0.5 rounded-md capitalize bg-n-slate-3 text-xs text-n-slate-12 shrink-0"
          :title="allCount"
        >
          {{ formattedAllCount }}
        </span>
      </div>
      <ComposeConversation>
        <template #trigger>
          <NextButton
            icon="i-lucide-pen-line"
            size="sm"
            :label="$t('CHAT_LIST.NEW_CONVERSATION_BUTTON')"
          />
        </template>
      </ComposeConversation>
    </div>

    <!-- Busca rapida por nome ou empresa, so' na lista ja' carregada -->
    <NextInput
      :model-value="searchQuery"
      type="search"
      size="sm"
      custom-input-class="!ps-8"
      :placeholder="$t('CHAT_LIST.SEARCH_PLACEHOLDER')"
      @update:model-value="emit('update:searchQuery', $event)"
    >
      <template #prefix>
        <Icon
          icon="i-lucide-search"
          class="absolute -translate-y-1/2 text-n-slate-11 size-3.5 top-1/2 ltr:left-2.5 rtl:right-2.5"
        />
      </template>
    </NextInput>

    <!-- Linha inferior: filtros de status + ações -->
    <div class="flex items-center flex-wrap justify-between gap-1.5">
      <div
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="flex items-center gap-0.5 p-0.5 rounded-lg bg-n-slate-3 shrink-0"
      >
        <NextButton
          v-for="status in QUICK_STATUSES"
          :key="status"
          size="sm"
          variant="ghost"
          color="slate"
          no-animation
          :class="
            activeStatus === status &&
            'bg-gradient-to-r from-n-blue-9 to-n-teal-9 !text-white'
          "
          :label="$t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${status}.TEXT`)"
          @click="onBasicFilterChange(status, 'status')"
        />
      </div>
      <div v-else class="flex-1" />

      <div class="flex items-center gap-1 shrink-0">
        <!-- Filtro por periodo: fixo, do lado do botao "Filtrar conversas"
             (pedido da Ingrid, 2026-11-11) -->
        <input
          :value="dateFrom"
          type="date"
          class="mb-0 !h-8 w-28 text-xs px-2"
          :aria-label="$t('CHAT_LIST.DATE_FILTER.FROM')"
          @input="emit('update:dateFrom', $event.target.value)"
        />
        <input
          :value="dateTo"
          type="date"
          class="mb-0 !h-8 w-28 text-xs px-2"
          :aria-label="$t('CHAT_LIST.DATE_FILTER.TO')"
          @input="emit('update:dateTo', $event.target.value)"
        />
        <NextButton
          v-if="hasDateFilter"
          v-tooltip.top-end="$t('CHAT_LIST.DATE_FILTER.CLEAR')"
          icon="i-lucide-circle-x"
          ruby
          sm
          faded
          @click="clearDateFilter"
        />
        <template v-if="hasAppliedFilters && !hasActiveFolders">
          <div class="relative">
            <NextButton
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
              icon="i-lucide-save"
              slate
              sm
              faded
              @click="emit('addFolders')"
            />
            <div
              id="saveFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
            icon="i-lucide-circle-x"
            ruby
            faded
            sm
            @click="emit('resetFilters')"
          />
        </template>
        <template v-if="hasActiveFolders">
          <div class="relative">
            <NextButton
              id="toggleConversationFilterButton"
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
              icon="i-lucide-pen-line"
              slate
              sm
              faded
              @click="emit('filtersModal')"
            />
            <div
              id="conversationFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
            icon="i-lucide-trash-2"
            ruby
            sm
            faded
            @click="emit('deleteFolders')"
          />
        </template>
        <div v-else class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
            icon="i-lucide-list-filter"
            slate
            sm
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
      </div>
    </div>
  </div>
</template>
