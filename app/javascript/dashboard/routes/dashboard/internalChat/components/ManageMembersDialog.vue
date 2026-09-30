<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
});

const emit = defineEmits(['add', 'remove']);

const { t } = useI18n();

const dialogRef = ref(null);
const room = ref(null);

const memberIds = computed(() => room.value?.memberIds || []);

const members = computed(() =>
  props.users.filter(user => memberIds.value.includes(user.id))
);

// Quem ainda nao esta no canal, para o dropdown de "adicionar".
const nonMembers = computed(() =>
  props.users.filter(user => !memberIds.value.includes(user.id))
);

const open = record => {
  room.value = record;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const addMember = event => {
  const userId = Number(event.target.value);
  if (!userId) return;
  emit('add', userId);
  event.target.value = '';
};

const removeMember = userId => emit('remove', userId);

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('INTERNAL_CHAT.MEMBERS.TITLE')"
    :show-confirm-button="false"
    :cancel-button-label="t('INTERNAL_CHAT.MEMBERS.CLOSE')"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.MEMBERS.ADD') }}
        </span>
        <select class="w-full mb-0" @change="addMember">
          <option value="">
            {{ t('INTERNAL_CHAT.MEMBERS.ADD_PLACEHOLDER') }}
          </option>
          <option v-for="user in nonMembers" :key="user.id" :value="user.id">
            {{ user.name }}
          </option>
        </select>
      </label>

      <div class="flex flex-col gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.MEMBERS.CURRENT', { count: members.length }) }}
        </span>
        <ul class="flex flex-col gap-1">
          <li
            v-for="user in members"
            :key="user.id"
            class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-lg bg-n-alpha-1"
          >
            <div class="flex items-center min-w-0 gap-2">
              <Avatar :name="user.name" :src="user.thumbnail" :size="24" />
              <span class="text-sm truncate text-n-slate-12">
                {{ user.name }}
              </span>
            </div>
            <button
              v-if="user.id !== currentUserId"
              type="button"
              class="flex-shrink-0 p-1 rounded text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-ruby-11"
              :title="t('INTERNAL_CHAT.MEMBERS.REMOVE')"
              @click="removeMember(user.id)"
            >
              <Icon icon="i-lucide-x" class="size-3.5" />
            </button>
          </li>
        </ul>
      </div>
    </div>
  </Dialog>
</template>
