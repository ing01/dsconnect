<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { shortTime } from '../helpers/messageParser';
import { presenceDotClass } from '../helpers/presence';

const props = defineProps({
  directs: { type: Array, default: () => [] },
  channels: { type: Array, default: () => [] },
  users: { type: Array, default: () => [] },
  activeRoomId: { type: String, default: '' },
});

const emit = defineEmits(['select', 'newConversation', 'createChannel']);

const { t } = useI18n();

const query = ref('');

const userFor = userId => props.users.find(user => user.id === userId);

const lastMessage = room => room.messages[room.messages.length - 1] || null;

// Conversas privadas e canais ficam em listas separadas de propósito: são
// coisas diferentes, e misturá-las é o que torna a barra lateral confusa.
const matches = text => text.toLowerCase().includes(query.value.toLowerCase());

const visibleDirects = computed(() =>
  props.directs.filter(direct => matches(userFor(direct.userId)?.name || ''))
);

const visibleChannels = computed(() =>
  props.channels.filter(channel => matches(channel.name))
);
</script>

<template>
  <aside
    class="flex flex-col h-full min-h-0 border-e border-n-weak bg-n-solid-1"
  >
    <div class="flex flex-col gap-2 p-3 border-b border-n-weak">
      <label class="relative flex items-center">
        <Icon
          icon="i-lucide-search"
          class="absolute size-4 text-n-slate-10 start-2.5"
        />
        <input
          v-model="query"
          type="search"
          class="w-full py-1.5 mb-0 text-sm ps-8"
          :placeholder="t('INTERNAL_CHAT.SIDEBAR.SEARCH')"
        />
      </label>
    </div>

    <div class="flex flex-col gap-4 py-3 overflow-y-auto grow">
      <!-- Conversas privadas -->
      <section class="flex flex-col gap-0.5">
        <header class="flex items-center justify-between gap-2 px-3 pb-1">
          <h3
            class="text-xs font-semibold tracking-wider uppercase text-n-slate-10"
          >
            {{ t('INTERNAL_CHAT.SIDEBAR.DIRECTS') }}
          </h3>
          <button
            type="button"
            class="p-0.5 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
            :title="t('INTERNAL_CHAT.SIDEBAR.NEW_CONVERSATION')"
            @click="emit('newConversation')"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
          </button>
        </header>

        <button
          v-for="direct in visibleDirects"
          :key="direct.id"
          type="button"
          class="flex items-center w-full gap-2.5 px-3 py-1.5 text-start"
          :class="
            direct.id === activeRoomId
              ? 'bg-n-alpha-2 text-n-slate-12'
              : 'hover:bg-n-alpha-1'
          "
          @click="emit('select', direct.id)"
        >
          <span class="relative flex-shrink-0">
            <Avatar :name="userFor(direct.userId)?.name || '?'" :size="28" />
            <span
              class="absolute bottom-0 size-2.5 rounded-full border-2 border-n-solid-1 end-0"
              :class="presenceDotClass(userFor(direct.userId)?.status)"
            />
          </span>

          <span class="flex flex-col min-w-0 grow">
            <span class="flex items-baseline justify-between gap-2">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ userFor(direct.userId)?.name }}
              </span>
              <span
                v-if="lastMessage(direct)"
                class="flex-shrink-0 text-xs tabular-nums text-n-slate-10"
              >
                {{ shortTime(lastMessage(direct).createdAt) }}
              </span>
            </span>
            <span class="text-xs truncate text-n-slate-10">
              {{
                lastMessage(direct)?.body ||
                t('INTERNAL_CHAT.SIDEBAR.NO_MESSAGES')
              }}
            </span>
          </span>

          <span
            v-if="direct.unread"
            class="flex-shrink-0 min-w-[1.25rem] px-1 py-0.5 text-xs font-semibold text-center rounded-full text-white bg-n-blue-9 tabular-nums"
          >
            {{ direct.unread }}
          </span>
        </button>
      </section>

      <!-- Canais -->
      <section class="flex flex-col gap-0.5">
        <header class="flex items-center justify-between gap-2 px-3 pb-1">
          <h3
            class="text-xs font-semibold tracking-wider uppercase text-n-slate-10"
          >
            {{ t('INTERNAL_CHAT.SIDEBAR.CHANNELS') }}
          </h3>
          <button
            type="button"
            class="p-0.5 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
            :title="t('INTERNAL_CHAT.SIDEBAR.CREATE_CHANNEL')"
            @click="emit('createChannel')"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
          </button>
        </header>

        <button
          v-for="channel in visibleChannels"
          :key="channel.id"
          type="button"
          class="flex items-center w-full gap-2 px-3 py-1.5 text-start"
          :class="
            channel.id === activeRoomId
              ? 'bg-n-alpha-2 text-n-slate-12'
              : 'hover:bg-n-alpha-1'
          "
          @click="emit('select', channel.id)"
        >
          <span class="flex-shrink-0 text-sm text-n-slate-10">#</span>
          <span
            class="text-sm truncate grow"
            :class="
              channel.unread
                ? 'font-semibold text-n-slate-12'
                : 'text-n-slate-11'
            "
          >
            {{ channel.name }}
          </span>
          <span
            v-if="channel.unread"
            class="flex-shrink-0 min-w-[1.25rem] px-1 py-0.5 text-xs font-semibold text-center rounded-full text-white bg-n-blue-9 tabular-nums"
          >
            {{ channel.unread }}
          </span>
        </button>
      </section>
    </div>
  </aside>
</template>
