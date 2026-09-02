<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
});

const emit = defineEmits(['create']);

const { t } = useI18n();

const dialogRef = ref(null);
const name = ref('');
const description = ref('');
// Os mesmos valores do enum `ChatChannel#visibility`. Com 'public'/'private' o
// servidor recusa a criacao inteira com 'is not a valid visibility'.
const PUBLIC = 'public_channel';
const PRIVATE = 'private_channel';

const visibility = ref(PUBLIC);
const memberIds = ref([]);

const isValid = computed(() => !!name.value.trim());

const selectableUsers = computed(() =>
  props.users.filter(user => user.id !== props.currentUserId)
);

const open = () => {
  name.value = '';
  description.value = '';
  visibility.value = PUBLIC;
  memberIds.value = [];
  dialogRef.value?.open();
};

const toggleMember = id => {
  const index = memberIds.value.indexOf(id);
  if (index === -1) memberIds.value.push(id);
  else memberIds.value.splice(index, 1);
};

const submit = () => {
  if (!isValid.value) return;

  emit('create', {
    // O nome do canal segue a convenção de handle: minúsculo e sem espaço.
    name: name.value.trim().toLowerCase().replace(/\s+/g, '-'),
    description: description.value.trim(),
    visibility: visibility.value,
    memberIds: [...new Set([props.currentUserId, ...memberIds.value])],
  });
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('INTERNAL_CHAT.CREATE_CHANNEL.TITLE')"
    :confirm-button-label="t('INTERNAL_CHAT.CREATE_CHANNEL.CONFIRM')"
    :disable-confirm-button="!isValid"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.NAME') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <input
          v-model="name"
          type="text"
          class="w-full mb-0"
          :placeholder="t('INTERNAL_CHAT.CREATE_CHANNEL.NAME_PLACEHOLDER')"
        />
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.DESCRIPTION') }}
        </span>
        <input
          v-model="description"
          type="text"
          class="w-full mb-0"
          :placeholder="
            t('INTERNAL_CHAT.CREATE_CHANNEL.DESCRIPTION_PLACEHOLDER')
          "
        />
      </label>

      <fieldset class="flex flex-col gap-1.5 p-0 m-0 border-0">
        <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.VISIBILITY') }}
        </legend>
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="visibility"
            type="radio"
            :value="PUBLIC"
            class="m-0"
          />
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PUBLIC') }}
        </label>
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="visibility"
            type="radio"
            :value="PRIVATE"
            class="m-0"
          />
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PRIVATE') }}
        </label>
      </fieldset>

      <div class="flex flex-col gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.MEMBERS') }}
        </span>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="user in selectableUsers"
            :key="user.id"
            type="button"
            class="px-2 py-1 text-xs border rounded-full"
            :class="
              memberIds.includes(user.id)
                ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                : 'border-n-weak text-n-slate-11 hover:border-n-slate-7'
            "
            @click="toggleMember(user.id)"
          >
            {{ user.name }}
          </button>
        </div>
      </div>
    </div>
  </Dialog>
</template>
