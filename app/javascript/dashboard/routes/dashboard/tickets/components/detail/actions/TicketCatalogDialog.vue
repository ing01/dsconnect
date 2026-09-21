<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketCatalogSelect from './TicketCatalogSelect.vue';

defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const catalogId = ref(null);
const areaId = ref(null);
const itemId = ref(null);

const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');

// O Item e o unico nivel guardado no ticket; Catalogo e Area vem por
// associacao. Por isso o formulario abre vazio mesmo num ticket ja classificado:
// so o Item nao permite reconstruir os dois niveis acima sem uma busca, e o
// caminho atual ja esta visivel no card logo atras do modal.
const open = () => {
  // Busca a cada abertura, como faz o dialogo de fechamento: o catalogo muda nas
  // Configuracoes, e uma lista carregada uma vez so envelheceria na aba aberta.
  store.dispatch('serviceCatalogs/fetch');

  catalogId.value = null;
  areaId.value = null;
  itemId.value = null;
  dialogRef.value?.open();
};

const podeConfirmar = computed(() => Boolean(itemId.value));

const handleConfirm = () => {
  if (!podeConfirmar.value) return;

  emit('submit', {
    serviceCatalogId: catalogId.value,
    serviceCatalogAreaId: areaId.value,
    serviceCatalogItemId: itemId.value,
  });
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="md"
    :title="t('TICKET.CATALOG.DIALOG.TITLE', { number: ticket.display_id })"
    :description="t('TICKET.CATALOG.DIALOG.DESCRIPTION')"
    :cancel-button-label="t('TICKET.CATALOG.DIALOG.BACK')"
    :confirm-button-label="t('TICKET.CATALOG.DIALOG.CONFIRM')"
    :disable-confirm-button="!podeConfirmar"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-3 min-w-0">
      <p v-if="!catalogs.length" class="m-0 text-sm text-n-slate-11">
        {{ t('TICKET.CATALOG.DIALOG.NO_CATALOG') }}
      </p>

      <TicketCatalogSelect
        v-else
        v-model:catalog-id="catalogId"
        v-model:area-id="areaId"
        v-model:item-id="itemId"
        :catalogs="catalogs"
      />
    </div>
  </Dialog>
</template>
