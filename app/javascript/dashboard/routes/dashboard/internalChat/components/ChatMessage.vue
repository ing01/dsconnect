<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessageBody from './MessageBody.vue';
import MessageAttachment from './MessageAttachment.vue';
import { shortTime } from '../helpers/messageParser';
import { QUICK_REACTIONS } from '../helpers/constants';

const props = defineProps({
  message: { type: Object, required: true },
  author: { type: Object, default: null },
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
  // Mensagem seguida do mesmo autor: repete só o texto, sem avatar nem nome.
  grouped: { type: Boolean, default: false },
  repliedMessage: { type: Object, default: null },
  repliedAuthor: { type: Object, default: null },
});

const emit = defineEmits(['reply', 'react', 'openImage', 'openTicket', 'pin']);

const { t } = useI18n();

const time = computed(() => shortTime(props.message.createdAt));
const reactions = computed(() => props.message.reactions || []);
const isPinned = computed(() => !!props.message.pinnedAt);

const hasReacted = reaction => reaction.userIds.includes(props.currentUserId);
</script>

<template>
  <div
    class="group relative flex gap-2.5 px-4 hover:bg-n-alpha-1"
    :class="grouped ? 'py-0.5' : 'pt-3 pb-0.5'"
  >
    <!-- A calha do avatar fica reservada mesmo quando agrupado, para que o
         texto de todas as linhas do bloco fique alinhado. -->
    <div class="flex-shrink-0 w-8">
      <Avatar v-if="!grouped" :name="author?.name || '?'" :size="32" />
    </div>

    <div class="flex flex-col min-w-0 grow">
      <!-- Citação da mensagem respondida, acima da resposta. -->
      <button
        v-if="repliedMessage"
        type="button"
        class="flex items-center gap-1.5 mb-0.5 text-xs text-n-slate-10 text-start hover:text-n-slate-11"
      >
        <Icon icon="i-lucide-corner-up-right" class="flex-shrink-0 size-3" />
        <span class="font-medium">{{ repliedAuthor?.name }}</span>
        <span class="truncate max-w-[22rem]">{{ repliedMessage.body }}</span>
      </button>

      <div v-if="!grouped" class="flex items-baseline gap-2">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ author?.name }}
        </span>
        <span class="text-xs tabular-nums text-n-slate-10">{{ time }}</span>
        <span
          v-if="isPinned"
          class="flex items-center gap-0.5 text-xs text-n-amber-11"
        >
          <Icon icon="i-lucide-pin" class="size-3" />
          {{ t('INTERNAL_CHAT.MESSAGE.PINNED') }}
        </span>
      </div>

      <MessageBody
        v-if="message.body"
        :body="message.body"
        :users="users"
        @open-ticket="id => emit('openTicket', id)"
      />

      <MessageAttachment
        v-for="attachment in message.attachments || []"
        :key="attachment.id"
        :attachment="attachment"
        @open-image="chosen => emit('openImage', chosen)"
      />

      <div v-if="reactions.length" class="flex flex-wrap gap-1 mt-1.5">
        <button
          v-for="reaction in reactions"
          :key="reaction.emoji"
          type="button"
          class="flex items-center gap-1 px-1.5 py-0.5 text-xs rounded-full border"
          :class="
            hasReacted(reaction)
              ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
              : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-n-slate-7'
          "
          @click="
            emit('react', { messageId: message.id, emoji: reaction.emoji })
          "
        >
          <span>{{ reaction.emoji }}</span>
          <span class="tabular-nums">{{ reaction.userIds.length }}</span>
        </button>
      </div>
    </div>

    <!-- Ações da mensagem: aparecem no hover para não poluir a leitura. -->
    <div
      class="absolute z-10 items-center hidden gap-0.5 p-0.5 border rounded-md shadow-sm -top-3 end-4 border-n-weak bg-n-solid-1 group-hover:flex group-focus-within:flex"
    >
      <button
        v-for="emoji in QUICK_REACTIONS"
        :key="emoji"
        type="button"
        class="px-1 text-sm rounded hover:bg-n-alpha-2"
        :title="t('INTERNAL_CHAT.MESSAGE.REACT')"
        @click="emit('react', { messageId: message.id, emoji })"
      >
        {{ emoji }}
      </button>
      <button
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-11"
        :title="t('INTERNAL_CHAT.MESSAGE.REPLY')"
        @click="emit('reply', message)"
      >
        <Icon icon="i-lucide-reply" class="size-3.5" />
      </button>
      <button
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2"
        :class="isPinned ? 'text-n-amber-11' : 'text-n-slate-11'"
        :title="
          t(
            isPinned ? 'INTERNAL_CHAT.MESSAGE.UNPIN' : 'INTERNAL_CHAT.MESSAGE.PIN'
          )
        "
        @click="emit('pin', message.id)"
      >
        <Icon icon="i-lucide-pin" class="size-3.5" />
      </button>
    </div>
  </div>
</template>
