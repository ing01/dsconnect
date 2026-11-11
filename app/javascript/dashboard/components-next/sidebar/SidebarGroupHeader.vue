<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import UnreadAlertMark from '../workspace-tabs/UnreadAlertMark.vue';

const props = defineProps({
  to: { type: [Object, String], default: '' },
  // Item de topo sem rota do Vue Router (link externo) - mesma ideia de
  // SidebarGroupLeaf, pra um item de topo tambem poder ser so' um link.
  href: { type: String, default: '' },
  label: { type: String, default: '' },
  icon: { type: [String, Object], default: '' },
  expandable: { type: Boolean, default: false },
  isExpanded: { type: Boolean, default: false },
  isActive: { type: Boolean, default: false },
  hasActiveChild: { type: Boolean, default: false },
  getterKeys: { type: Object, default: () => ({}) },
  // So o menu lateral do dashboard oferece favoritar; outras telas que montam o
  // grupo nao mostram a estrela.
  favoritable: { type: Boolean, default: false },
  isFavorite: { type: Boolean, default: false },
  // Mensagem nao lida esperando nesta tela (o "!"), com o texto que o explica.
  alert: { type: Boolean, default: false },
  alertLabel: { type: String, default: '' },
});

const emit = defineEmits(['toggle', 'toggleFavorite']);

const { t } = useI18n();

const favoriteLabel = computed(() =>
  props.isFavorite ? t('SIDEBAR.UNFAVORITE') : t('SIDEBAR.FAVORITE')
);

const showBadge = useMapGetter(props.getterKeys.badge);
const dynamicCount = useMapGetter(props.getterKeys.count);
const count = computed(() =>
  dynamicCount.value > 99 ? '99+' : dynamicCount.value
);
</script>

<template>
  <component
    :is="href ? 'a' : to ? 'router-link' : 'div'"
    class="group flex items-center gap-2 px-1.5 py-1 rounded-lg h-9 min-w-0"
    role="button"
    draggable="false"
    :to="href ? undefined : to"
    :href="href || undefined"
    :target="href ? '_blank' : undefined"
    :rel="href ? 'noopener noreferrer' : undefined"
    :title="label"
    :class="{
      'text-n-slate-12 bg-n-alpha-2 font-medium': isActive && !hasActiveChild,
      'text-n-slate-12 font-medium': hasActiveChild,
      'text-n-slate-11 hover:bg-n-alpha-2': !isActive && !hasActiveChild,
    }"
    @click.stop="emit('toggle')"
  >
    <div v-if="icon" class="relative flex items-center gap-2">
      <Icon v-if="icon" :icon="icon" class="size-5" />
      <span
        v-if="showBadge"
        class="size-2 -top-px ltr:-right-px rtl:-left-px bg-n-brand absolute rounded-full border border-n-solid-2"
      />
    </div>
    <div
      class="flex items-center gap-1.5 flex-grow justify-between min-w-0 flex-1"
    >
      <span
        class="truncate text-base"
        :class="{
          'font-medium': isActive || hasActiveChild,
        }"
      >
        {{ label }}
      </span>
      <UnreadAlertMark v-if="alert" :label="alertLabel" />
      <span
        v-if="dynamicCount"
        class="inline-grid h-5 min-w-5 place-items-center rounded-full bg-n-slate-4 px-1 text-xxs font-medium leading-3 text-n-slate-12 dark:bg-n-slate-5 flex-shrink-0"
      >
        {{ count }}
      </span>
    </div>
    <!-- A estrela fica escondida ate o mouse passar; no celular, sem hover, fica
         sempre a mostra. Favoritado fica visivel sempre. -->
    <button
      v-if="favoritable"
      type="button"
      class="flex-shrink-0 grid place-items-center size-5 rounded text-n-slate-10 hover:text-n-amber-11 focus-visible:opacity-100 max-md:opacity-100"
      :class="
        isFavorite
          ? 'opacity-100 text-n-amber-11'
          : 'opacity-0 group-hover:opacity-100'
      "
      :title="favoriteLabel"
      :aria-label="favoriteLabel"
      :aria-pressed="isFavorite"
      @click.stop.prevent="emit('toggleFavorite')"
    >
      <span
        class="size-3.5"
        :class="isFavorite ? 'i-ph-star-fill' : 'i-lucide-star'"
      />
    </button>
    <span
      v-if="expandable"
      v-show="isExpanded"
      class="i-lucide-chevron-up size-3"
      @click.stop="emit('toggle')"
    />
  </component>
</template>
