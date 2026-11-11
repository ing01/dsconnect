<script setup>
import { computed, ref } from 'vue';
import { OnClickOutside } from '@vueuse/components';
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

// O periodo mora dentro do menu do funil (so um icone na tela). "Filtros avancados"
// continua sendo o que o funil abria antes, agora o primeiro item do menu.
const isFilterMenuOpen = ref(false);

const openAdvancedFilters = () => {
  isFilterMenuOpen.value = false;
  emit('filtersModal');
};

const clearDateFilter = () => {
  emit('update:dateFrom', '');
  emit('update:dateTo', '');
};

// (x) em cada campo, pra limpar so' aquela data sem precisar abrir o link
// "Limpar filtro de data" la embaixo - pedido da Ingrid, 2026-11-11.
const clearDateFrom = () => emit('update:dateFrom', '');
const clearDateTo = () => emit('update:dateTo', '');

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

      <div class="relative flex items-center gap-1 shrink-0">
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
              v-tooltip.top-end="$t('CHAT_LIST.DATE_FILTER.TITLE')"
              data-filter-menu-trigger
              data-testid="date-menu-trigger"
              icon="i-lucide-calendar-range"
              slate
              sm
              faded
              @click="isFilterMenuOpen = !isFilterMenuOpen"
            />
            <span
              v-if="hasDateFilter"
              class="absolute rounded-full -top-0.5 size-2 ltr:-right-0.5 rtl:-left-0.5 bg-n-brand border border-n-solid-2"
            />
          </div>
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
            data-filter-menu-trigger
            data-testid="filter-menu-trigger"
            icon="i-lucide-list-filter"
            slate
            sm
            faded
            @click="isFilterMenuOpen = !isFilterMenuOpen"
          />
          <span
            v-if="hasDateFilter"
            data-testid="date-filter-dot"
            class="absolute rounded-full pointer-events-none -top-0.5 size-2 ltr:-right-0.5 rtl:-left-0.5 bg-n-brand border border-n-solid-2"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>

        <OnClickOutside
          v-if="isFilterMenuOpen"
          :options="{ ignore: ['[data-filter-menu-trigger]'] }"
          @trigger="isFilterMenuOpen = false"
        >
          <div
            data-testid="filter-menu"
            class="absolute z-50 flex flex-col gap-2 p-3 mt-1 border rounded-lg shadow-md top-full ltr:right-0 rtl:left-0 w-60 border-n-weak bg-n-solid-1"
          >
            <template v-if="!hasActiveFolders">
              <button
                type="button"
                data-testid="advanced-filters"
                class="flex items-center gap-2 px-1 py-1 text-sm rounded text-start text-n-slate-12 hover:bg-n-alpha-1"
                @click="openAdvancedFilters"
              >
                <Icon icon="i-lucide-list-filter" class="size-4" />
                {{ $t('FILTER.TOOLTIP_LABEL') }}
              </button>
              <div class="h-px bg-n-weak" />
            </template>

            <span class="text-xs font-medium text-n-slate-11">
              {{ $t('CHAT_LIST.DATE_FILTER.TITLE') }}
            </span>
            <label class="flex items-center gap-2 text-xs text-n-slate-11">
              <span class="w-8 shrink-0">
                {{ $t('CHAT_LIST.DATE_FILTER.FROM') }}
              </span>
              <span class="relative flex-1">
                <input
                  :value="dateFrom"
                  data-testid="date-from"
                  type="date"
                  class="mb-0 !h-8 w-full text-xs px-2"
                  :class="{ 'pe-6': dateFrom }"
                  @input="emit('update:dateFrom', $event.target.value)"
                />
                <button
                  v-if="dateFrom"
                  type="button"
                  data-testid="date-from-clear"
                  :aria-label="$t('CHAT_LIST.DATE_FILTER.CLEAR')"
                  class="absolute -translate-y-1/2 top-1/2 ltr:right-1.5 rtl:left-1.5 text-n-slate-10 hover:text-n-ruby-11"
                  @click="clearDateFrom"
                >
                  <Icon icon="i-lucide-x" class="size-3.5" />
                </button>
              </span>
            </label>
            <label class="flex items-center gap-2 text-xs text-n-slate-11">
              <span class="w-8 shrink-0">
                {{ $t('CHAT_LIST.DATE_FILTER.TO') }}
              </span>
              <span class="relative flex-1">
                <input
                  :value="dateTo"
                  data-testid="date-to"
                  type="date"
                  class="mb-0 !h-8 w-full text-xs px-2"
                  :class="{ 'pe-6': dateTo }"
                  @input="emit('update:dateTo', $event.target.value)"
                />
                <button
                  v-if="dateTo"
                  type="button"
                  data-testid="date-to-clear"
                  :aria-label="$t('CHAT_LIST.DATE_FILTER.CLEAR')"
                  class="absolute -translate-y-1/2 top-1/2 ltr:right-1.5 rtl:left-1.5 text-n-slate-10 hover:text-n-ruby-11"
                  @click="clearDateTo"
                >
                  <Icon icon="i-lucide-x" class="size-3.5" />
                </button>
              </span>
            </label>
            <button
              v-if="hasDateFilter"
              type="button"
              data-testid="date-clear"
              class="flex items-center gap-1.5 text-xs text-start text-n-ruby-11 hover:underline"
              @click="clearDateFilter"
            >
              <Icon icon="i-lucide-circle-x" class="size-3.5" />
              {{ $t('CHAT_LIST.DATE_FILTER.CLEAR') }}
            </button>
          </div>
        </OnClickOutside>
      </div>
    </div>
  </div>
</template>
