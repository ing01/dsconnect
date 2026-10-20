<script setup>
/**
 * "Enviar para Sugestões e Melhorias".
 *
 * Mais simples que o diálogo de ticket de propósito: o quadro de Sugestões é
 * UM só por conta (não por Mesa), então não há nada para escolher - só
 * confirmar. Quem decide SE isso é uma sugestão (em vez de um atendimento de
 * verdade) é quem está olhando a manifestação, antes de abrir o diálogo.
 *
 * O diálogo não impede a segunda conversão: quem impede é o servidor (a
 * manifestação só vira UM dos dois destinos). Aqui o botão simplesmente deixa
 * de aparecer, o que é conveniência, não regra.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  manifestation: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const dialogRef = ref(null);
const uiFlags = getters['manifestations/getUIFlags'];

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();

const confirmar = async () => {
  try {
    await store.dispatch(
      'manifestations/convertToSuggestion',
      props.manifestation.id
    );
    useAlert(t('MANIFESTATION.CONVERT_SUGGESTION.DONE'));
    close();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('MANIFESTATION.API.ERROR'));
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('MANIFESTATION.CONVERT_SUGGESTION.TITLE')"
    :description="t('MANIFESTATION.CONVERT_SUGGESTION.DESCRIPTION')"
    :confirm-button-label="t('MANIFESTATION.CONVERT_SUGGESTION.CONFIRM')"
    :cancel-button-label="t('MANIFESTATION.CONVERT_SUGGESTION.CANCEL')"
    :is-loading="uiFlags.isConverting"
    @confirm="confirmar"
  />
</template>
