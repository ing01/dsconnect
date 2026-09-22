<script setup>
import { computed, ref, watch } from 'vue';
import { useEventListener } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import Icon from 'next/icon/Icon.vue';
import SidebarGroupLeaf from './SidebarGroupLeaf.vue';
import SidebarGroupSeparator from './SidebarGroupSeparator.vue';

import { useSidebarContext } from './provider';

const props = defineProps({
  name: { type: String, required: true },
  isExpanded: { type: Boolean, default: false },
  label: { type: String, required: true },
  icon: { type: [Object, String], required: true },
  children: { type: Array, default: undefined },
  activeChild: { type: Object, default: undefined },
  sortOptions: { type: Array, default: () => [] },
  activeSort: { type: String, default: '' },
  collapsible: { type: Boolean, default: false },
  // A collapsible subgroup is open until the user closes it. Groups that were
  // promoted into another menu start the other way around, so entering the
  // parent does not dump every child on screen at once.
  startCollapsed: { type: Boolean, default: false },
  showTreeLine: { type: Boolean, default: false },
  endTreeLine: { type: Boolean, default: false },
  // Vide SidebarGroupSeparator: cabecalho que e item de menu, nao rotulo.
  asMenuItem: { type: Boolean, default: false },
});

const emit = defineEmits(['update-sort']);

// Named so the template can render itself: a child that carries children of its
// own is another subgroup, not a leaf. Nothing changes for the existing menus,
// where subgroup children are always leaves - this only takes effect when one
// is nested.
defineOptions({ name: 'SidebarSubGroup' });

const { isAllowed } = useSidebarContext();
const scrollableContainer = ref(null);
const accountId = useMapGetter('getCurrentAccountId');

const minimizedSectionsKey = LOCAL_STORAGE_KEYS.SIDEBAR_MINIMIZED_SECTIONS;

const getMinimizedSections = () => {
  const minimizedSections = LocalStorage.get(minimizedSectionsKey);
  return minimizedSections &&
    typeof minimizedSections === 'object' &&
    !Array.isArray(minimizedSections)
    ? minimizedSections
    : {};
};

const minimizedSections = ref(getMinimizedSections());
const storageKey = computed(() =>
  accountId.value ? `${accountId.value}:${props.name}` : props.name
);
// One stored flag, two readings: for a group that starts open it means "the
// user closed this", for one that starts closed it means "the user opened it".
const isSubGroupExpanded = computed(() => {
  if (!props.collapsible) return true;

  const stored = Boolean(minimizedSections.value[storageKey.value]);
  return props.startCollapsed ? stored : !stored;
});
const hasActiveChild = computed(() =>
  props.children.some(child => child.name === props.activeChild?.name)
);

const accessibleItems = computed(() =>
  props.children.filter(child => {
    return child.to && isAllowed(child.to);
  })
);

const hasAccessibleItems = computed(() => {
  return accessibleItems.value.length > 0;
});

const isScrollable = computed(() => {
  return (
    props.isExpanded &&
    isSubGroupExpanded.value &&
    accessibleItems.value.length > 7
  );
});

const scrollEnd = ref(false);

const CHILDREN_TRUNK =
  "before:content-[''] before:absolute before:top-0 before:bottom-0 before:w-0.5 before:bg-n-slate-4 before:start-[-0.5rem]";

const hideLeafTreeLine = computed(
  () => props.showTreeLine && !props.isExpanded
);

const toggleSubGroup = () => {
  if (!props.collapsible) return;

  // The flag records the state that differs from the default, so toggling
  // back to the default clears it.
  const shouldStore = props.startCollapsed
    ? !isSubGroupExpanded.value
    : isSubGroupExpanded.value;

  if (shouldStore) {
    LocalStorage.updateJsonStore(minimizedSectionsKey, storageKey.value, true);
  } else {
    LocalStorage.deleteFromJsonStore(minimizedSectionsKey, storageKey.value);
  }

  minimizedSections.value = getMinimizedSections();
};

const expandSubGroupOnActiveChild = () => {
  if (!props.collapsible || !hasActiveChild.value || isSubGroupExpanded.value) {
    return;
  }

  // Being on one of its routes opens it - which for a start-closed group means
  // writing the flag, not clearing it.
  if (props.startCollapsed) {
    LocalStorage.updateJsonStore(minimizedSectionsKey, storageKey.value, true);
  } else {
    LocalStorage.deleteFromJsonStore(minimizedSectionsKey, storageKey.value);
  }

  minimizedSections.value = getMinimizedSections();
};

const shouldShowItem = child => {
  return (
    isSubGroupExpanded.value &&
    (props.isExpanded || props.activeChild?.name === child.name)
  );
};

// set scrollEnd to true when the scroll reaches the end
useEventListener(scrollableContainer, 'scroll', () => {
  const { scrollHeight, scrollTop, clientHeight } = scrollableContainer.value;
  scrollEnd.value = scrollHeight - scrollTop === clientHeight;
});

useEventListener(window, 'storage', event => {
  if (event.key === minimizedSectionsKey) {
    minimizedSections.value = getMinimizedSections();
  }
});

watch([hasActiveChild, storageKey], expandSubGroupOnActiveChild, {
  immediate: true,
});
</script>

<template>
  <li class="group/sidebar-section relative flex flex-col list-none min-w-0">
    <template v-if="hasAccessibleItems">
      <SidebarGroupSeparator
        v-show="isExpanded"
        :label
        :icon
        :collapsible
        :is-expanded="isSubGroupExpanded"
        :show-tree-line="showTreeLine"
        :end-tree-line="endTreeLine"
        :as-menu-item="asMenuItem"
        :sort-options="sortOptions"
        :active-sort="activeSort"
        class="my-1"
        @toggle="toggleSubGroup"
        @update-sort="sortBy => emit('update-sort', sortBy)"
      />
      <ul
        v-if="children.length"
        class="m-0 list-none reset-base relative group min-w-0"
        :class="[
          { 'ms-5': collapsible },
          showTreeLine && !endTreeLine && CHILDREN_TRUNK,
        ]"
      >
        <div
          ref="scrollableContainer"
          class="min-w-0"
          :class="{
            'max-h-60 overflow-y-scroll no-scrollbar': isScrollable,
          }"
        >
          <template v-for="child in children" :key="child.name">
            <SidebarSubGroup
              v-if="child.children"
              v-show="shouldShowItem(child)"
              v-bind="child"
              :active-child="activeChild"
              collapsible
              show-tree-line
            />
            <SidebarGroupLeaf
              v-else
              v-show="shouldShowItem(child)"
              v-bind="child"
              :active="activeChild?.name === child.name"
              :hide-tree-line="hideLeafTreeLine"
              thin-tree-line
            />
          </template>
        </div>
        <div
          v-if="isScrollable && isExpanded"
          v-show="!scrollEnd"
          class="absolute bg-gradient-to-t from-n-background w-full h-12 to-transparent -bottom-1 pointer-events-none flex items-end justify-end px-2 animate-fade-in-up"
        >
          <Icon
            icon="i-woot-chevrons-down"
            class="w-4 h-6 text-n-slate-9 opacity-50 group-hover:opacity-100"
          />
        </div>
      </ul>
    </template>
  </li>
</template>
