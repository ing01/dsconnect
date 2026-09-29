<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { presenceDotClass, presenceLabelKey } from '../helpers/presence';

const props = defineProps({
  room: { type: Object, default: null },
  peer: { type: Object, default: null },
  // Editar o canal e decisao sobre o canal da empresa: so administrador. Quem
  // decide isso e a tela de cima, que conhece o papel.
  canEdit: { type: Boolean, default: false },
  membersOpen: { type: Boolean, default: false },
});

const emit = defineEmits(['back', 'search', 'toggleMembers', 'edit']);

const { t } = useI18n();

const isChannel = computed(() => !!props.room?.name);
const searchOpen = ref(false);
const searchQuery = ref('');
const menuOpen = ref(false);

// O menu existe so quando ha o que colocar nele: sem acao disponivel, tres
// pontos que abrem um vazio e pior do que tres pontos que nao existem.
const hasMenu = computed(() => isChannel.value && props.canEdit);

const editar = () => {
  menuOpen.value = false;
  emit('edit');
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
          class="p-1.5 rounded hover:bg-n-alpha-2"
          :class="
            membersOpen ? 'text-n-slate-12 bg-n-alpha-2' : 'text-n-slate-11'
          "
          :title="t('INTERNAL_CHAT.HEADER.MEMBERS_TITLE')"
          :aria-pressed="membersOpen"
          @click="emit('toggleMembers')"
        >
          <Icon icon="i-lucide-users" class="size-4" />
        </button>

        <OnClickOutside v-if="hasMenu" @trigger="menuOpen = false">
          <div class="relative">
            <button
              type="button"
              class="p-1.5 rounded text-n-slate-11 hover:bg-n-alpha-2"
              :title="t('INTERNAL_CHAT.HEADER.MORE')"
              @click="menuOpen = !menuOpen"
            >
              <Icon icon="i-lucide-more-horizontal" class="size-4" />
            </button>
            <div
              v-if="menuOpen"
              class="absolute z-20 py-1 mt-1 border rounded-lg shadow-md top-full end-0 min-w-44 border-n-weak bg-n-solid-1"
            >
              <button
                type="button"
                class="flex items-center w-full gap-2 px-3 py-1.5 text-sm text-start text-n-slate-12 hover:bg-n-alpha-1"
                @click="editar"
              >
                <Icon icon="i-lucide-settings-2" class="size-4" />
                {{ t('INTERNAL_CHAT.HEADER.EDIT_CHANNEL') }}
              </button>
            </div>
          </div>
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
