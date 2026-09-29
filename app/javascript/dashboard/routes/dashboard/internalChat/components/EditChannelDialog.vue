<script setup>
/**
 * Editar um canal que já existe.
 *
 * Os campos são os mesmos da criação (ver `ChannelFields`), menos a participação:
 * mudar quem está no canal é outro pedido, com outro endpoint. Aqui a lista de
 * membros serve apenas para dizer quem pode ser autorizado a escrever.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ChannelFields from './ChannelFields.vue';
import {
  PUBLIC,
  EVERYONE,
  MODERATORS,
  emptyChannelForm,
} from '../helpers/channelOptions';

defineProps({
  users: { type: Array, default: () => [] },
});

const emit = defineEmits(['save']);

const { t } = useI18n();

const dialogRef = ref(null);
const roomId = ref(null);
const form = ref(emptyChannelForm());

const isValid = computed(() => !!form.value.name.trim());

// Recebe a sala inteira e copia o que é editável. Copia, e não referencia: sem
// isso, cancelar o diálogo deixaria a tela já alterada.
const open = room => {
  if (!room) return;

  roomId.value = room.id;
  form.value = {
    name: room.name || '',
    description: room.description || '',
    visibility: room.visibility || PUBLIC,
    memberIds: [...(room.memberIds || [])],
    pinned: Boolean(room.pinned),
    postingPolicy: room.postingPolicy || EVERYONE,
    moderatorIds: [...(room.moderatorIds || [])],
  };
  dialogRef.value?.open();
};

const submit = () => {
  if (!isValid.value) return;

  emit('save', {
    roomId: roomId.value,
    // O nome aparece exatamente como digitado - so o espaco nas pontas some.
    name: form.value.name.trim(),
    description: form.value.description.trim(),
    visibility: form.value.visibility,
    pinned: form.value.pinned,
    postingPolicy: form.value.postingPolicy,
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
    :title="t('INTERNAL_CHAT.EDIT_CHANNEL.TITLE')"
    :description="t('INTERNAL_CHAT.EDIT_CHANNEL.DESCRIPTION')"
    :confirm-button-label="t('INTERNAL_CHAT.EDIT_CHANNEL.CONFIRM')"
    :disable-confirm-button="!isValid"
    @confirm="submit"
  >
    <ChannelFields v-model="form" :users="users" editing />
  </Dialog>
</template>
