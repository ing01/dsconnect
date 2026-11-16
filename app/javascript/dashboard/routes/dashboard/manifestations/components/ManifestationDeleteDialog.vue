<script setup>
/**
 * "Excluir SAC": só administrador (a regra é do `ManifestationPolicy#destroy?`; a
 * tela só esconde o botão, o servidor é quem recusa).
 *
 * Apagar leva junto as mensagens, o histórico e os anexos, e não tem volta - por
 * isso a pergunta vem num diálogo, com o que se perde dito com todas as letras.
 * Se a manifestação virou ticket ou sugestão, esse registro continua existindo.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  manifestation: { type: Object, required: true },
});
const emit = defineEmits(['deleted']);

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const dialogRef = ref(null);
const uiFlags = getters['manifestations/getUIFlags'];

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();

const confirmar = async () => {
  try {
    await store.dispatch('manifestations/destroy', props.manifestation.id);
    useAlert(
      t('MANIFESTATION.DELETE.DONE', {
        reference: props.manifestation.reference,
      })
    );
    close();
    emit('deleted');
  } catch (error) {
    useAlert(error?.response?.data?.error || t('MANIFESTATION.API.ERROR'));
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="t('MANIFESTATION.DELETE.TITLE')"
    :description="
      t('MANIFESTATION.DELETE.DESCRIPTION', {
        reference: manifestation.reference,
      })
    "
    :confirm-button-label="t('MANIFESTATION.DELETE.CONFIRM')"
    :cancel-button-label="t('MANIFESTATION.DELETE.CANCEL')"
    :is-loading="uiFlags.isDeleting"
    @confirm="confirmar"
  />
</template>
