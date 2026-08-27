<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { presenceDotClass, presenceLabelKey } from '../helpers/presence';

const props = defineProps({
  room: { type: Object, default: null },
  peer: { type: Object, default: null },
});

const emit = defineEmits(['back', 'search']);

const { t } = useI18n();

const isChannel = computed(() => !!props.room?.name);
const searchOpen = ref(false);
const searchQuery = ref('');

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
        >
          <Icon icon="i-lucide-users" class="size-4" />
        </button>
        <button
          type="button"
          class="p-1.5 rounded text-n-slate-11 hover:bg-n-alpha-2"
          :title="t('INTERNAL_CHAT.HEADER.MORE')"
        >
          <Icon icon="i-lucide-more-horizontal" class="size-4" />
        </button>
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
