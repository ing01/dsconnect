<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { presenceDotClass, presenceLabelKey } from '../helpers/presence';

const props = defineProps({
  room: { type: Object, default: null },
  peer: { type: Object, default: null },
  pinnedCount: { type: Number, default: 0 },
});

const emit = defineEmits([
  'back',
  'search',
  'manageMembers',
  'deleteChannel',
  'togglePinned',
]);

const { t } = useI18n();

const isChannel = computed(() => !!props.room?.name);
const searchOpen = ref(false);
const searchQuery = ref('');
const isMoreMenuOpen = ref(false);

const moreMenuItems = computed(() => [
  {
    label: t('INTERNAL_CHAT.HEADER.PINNED_MESSAGES', {
      count: props.pinnedCount,
    }),
    value: 'pinned',
    action: 'pinned',
    icon: 'i-lucide-pin',
  },
  {
    label: t('INTERNAL_CHAT.HEADER.DELETE_CHANNEL'),
    value: 'delete',
    action: 'delete',
    icon: 'i-lucide-trash-2',
  },
]);

const handleMoreAction = ({ action }) => {
  isMoreMenuOpen.value = false;
  if (action === 'pinned') emit('togglePinned');
  if (action === 'delete') emit('deleteChannel');
};

const onSearch = () => emit('search', searchQuery.value);

const toggleSearch = () => {
  searchOpen.value = !searchOpen.value;
  if (!searchOpen.value) {
    searchQuery.value = '';
    emit('search', '');
  }
};
</script>

<template>
  <header class="flex flex-col border-b border-n-weak bg-n-solid-1">
    <div class="flex items-center gap-2.5 px-4 py-2.5 min-w-0">
      <!-- No celular a conversa ocupa a tela inteira, então precisa de saída. -->
      <button
        type="button"
        class="p-1 -ms-1 rounded md:hidden text-n-slate-11 hover:bg-n-alpha-2"
        :title="t('INTERNAL_CHAT.HEADER.BACK')"
        @click="emit('back')"
      >
        <Icon icon="i-lucide-arrow-left" class="size-5" />
      </button>

      <template v-if="isChannel">
        <span class="text-lg text-n-slate-10">#</span>
        <div class="flex flex-col min-w-0 grow">
          <span class="text-sm font-semibold truncate text-n-slate-12">
            {{ room.name }}
          </span>
          <span class="text-xs truncate text-n-slate-10">
            {{ room.description }}
          </span>
        </div>
        <span class="flex-shrink-0 hidden text-xs sm:block text-n-slate-10">
          {{
            t('INTERNAL_CHAT.HEADER.MEMBERS', { count: room.memberIds.length })
          }}
        </span>
      </template>

      <template v-else>
        <Avatar :name="peer?.name || '?'" :size="32" />
        <div class="flex flex-col min-w-0 grow">
          <span class="text-sm font-semibold truncate text-n-slate-12">
            {{ peer?.name }}
          </span>
          <span class="flex items-center gap-1.5 text-xs text-n-slate-10">
            <span
              class="size-1.5 rounded-full"
              :class="presenceDotClass(peer?.status)"
            />
            {{ t(presenceLabelKey(peer?.status)) }}
          </span>
        </div>
      </template>

      <div class="flex items-center flex-shrink-0 gap-0.5">
        <button
          type="button"
          class="p-1.5 rounded text-n-slate-11 hover:bg-n-alpha-2"
          :title="t('INTERNAL_CHAT.HEADER.SEARCH')"
          @click="toggleSearch"
        >
          <Icon icon="i-lucide-search" class="size-4" />
        </button>
        <button
          v-if="isChannel"
          type="button"
          class="p-1.5 rounded text-n-slate-11 hover:bg-n-alpha-2"
          :title="t('INTERNAL_CHAT.HEADER.MEMBERS_TITLE')"
          @click="emit('manageMembers')"
        >
          <Icon icon="i-lucide-users" class="size-4" />
        </button>
        <OnClickOutside
          v-if="isChannel"
          class="relative"
          @trigger="isMoreMenuOpen = false"
        >
          <button
            type="button"
            class="p-1.5 rounded text-n-slate-11 hover:bg-n-alpha-2"
            :title="t('INTERNAL_CHAT.HEADER.MORE')"
            @click="isMoreMenuOpen = !isMoreMenuOpen"
          >
            <Icon icon="i-lucide-more-horizontal" class="size-4" />
          </button>
          <DropdownMenu
            v-if="isMoreMenuOpen"
            :menu-items="moreMenuItems"
            class="mt-1 top-full end-0 w-56"
            @action="handleMoreAction"
          />
        </OnClickOutside>
      </div>
    </div>

    <div v-if="searchOpen" class="px-4 pb-2.5">
      <input
        v-model="searchQuery"
        type="search"
        class="w-full py-1.5 mb-0 text-sm"
        :placeholder="t('INTERNAL_CHAT.HEADER.SEARCH_PLACEHOLDER')"
        @input="onSearch"
      />
    </div>
  </header>
</template>
