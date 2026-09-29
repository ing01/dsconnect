<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ChannelFields from './ChannelFields.vue';
import { MODERATORS, emptyChannelForm } from '../helpers/channelOptions';

const props = defineProps({
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
});

const emit = defineEmits(['create']);

const { t } = useI18n();

const dialogRef = ref(null);

const form = ref(emptyChannelForm());

const isValid = computed(() => !!form.value.name.trim());

const open = () => {
  form.value = emptyChannelForm();
  dialogRef.value?.open();
};

const submit = () => {
  if (!isValid.value) return;

  emit('create', {
    // O nome aparece exatamente como digitado - so o espaco nas pontas some.
    name: form.value.name.trim(),
    description: form.value.description.trim(),
    visibility: form.value.visibility,
    memberIds: [...new Set([props.currentUserId, ...form.value.memberIds])],
    pinned: form.value.pinned,
    postingPolicy: form.value.postingPolicy,
    // Só faz sentido enviar quando a escrita é restrita; com `everyone` a lista
    // não tem efeito nenhum e mandá-la sugeriria o contrário.
    moderatorIds:
      form.value.postingPolicy === MODERATORS
        ? [...form.value.moderatorIds]
        : [],
  });
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('INTERNAL_CHAT.CREATE_CHANNEL.TITLE')"
    :confirm-button-label="t('INTERNAL_CHAT.CREATE_CHANNEL.CONFIRM')"
    :disable-confirm-button="!isValid"
    @confirm="submit"
  >
    <ChannelFields
      v-model="form"
      :users="users"
      :current-user-id="currentUserId"
    />
  </Dialog>
</template>
