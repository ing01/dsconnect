<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const dialogRef = ref(null);
const query = ref('');

// Ninguém conversa consigo mesmo.
const matches = computed(() =>
  props.users
    .filter(user => user.id !== props.currentUserId)
    .filter(user => user.name.toLowerCase().includes(query.value.toLowerCase()))
);

const open = () => {
  query.value = '';
  dialogRef.value?.open();
};

const choose = user => {
  emit('select', user.id);
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('INTERNAL_CHAT.NEW_CONVERSATION.TITLE')"
    :show-confirm-button="false"
  >
    <div class="flex flex-col gap-3 min-w-0">
      <input
        v-model="query"
        type="search"
        class="w-full mb-0 text-sm"
        :placeholder="t('INTERNAL_CHAT.NEW_CONVERSATION.SEARCH')"
      />

      <div class="flex flex-col overflow-y-auto max-h-64">
        <button
          v-for="user in matches"
          :key="user.id"
          type="button"
          class="flex items-center gap-2.5 px-2 py-2 rounded text-start hover:bg-n-alpha-2"
          @click="choose(user)"
        >
          <Avatar :name="user.name" :src="user.thumbnail" :size="28" />
          <span class="flex flex-col min-w-0">
            <span class="text-sm truncate text-n-slate-12">{{
              user.name
            }}</span>
            <span class="text-xs truncate text-n-slate-10">{{
              user.role
            }}</span>
          </span>
        </button>

        <p v-if="!matches.length" class="px-2 py-3 text-sm text-n-slate-10">
          {{ t('INTERNAL_CHAT.NEW_CONVERSATION.EMPTY') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
