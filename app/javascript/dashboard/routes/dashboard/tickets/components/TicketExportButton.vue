<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import TicketsAPI from 'dashboard/api/tickets';
import { downloadBlob } from 'dashboard/helper/downloadHelper';
import { toSearchParams } from '../helpers/ticketSearchParams';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

/**
 * Exporta o resultado da Busca detalhada.
 *
 * O arquivo é montado no servidor, com os mesmos filtros da tela e sem
 * paginação: leva todos os tickets que atendem à busca, não só a página aberta.
 */
const props = defineProps({
  // Os filtros já aplicados, os mesmos que a lista está mostrando.
  filters: { type: Object, default: () => ({}) },
  // Quantos tickets a busca encontrou; sem nenhum, não há o que exportar.
  count: { type: Number, default: 0 },
});

const { t } = useI18n();

const isOpen = ref(false);
// Enquanto o servidor monta o arquivo o botão fica ocupado, o que também
// impede o clique duplo disparar duas gerações.
const isExporting = ref(false);

const isDisabled = computed(() => props.count === 0 || isExporting.value);

const menuItems = computed(() => [
  {
    label: t('TICKET.EXPORT.EXCEL'),
    value: 'xlsx',
    action: 'export',
    icon: 'i-lucide-sheet',
  },
  {
    label: t('TICKET.EXPORT.PDF'),
    value: 'pdf',
    action: 'export',
    icon: 'i-lucide-file-text',
  },
]);

const label = computed(() =>
  isExporting.value ? t('TICKET.EXPORT.WORKING') : t('TICKET.EXPORT.LABEL')
);

const toggle = () => {
  if (isDisabled.value) return;
  isOpen.value = !isOpen.value;
};

// Nem todo ambiente traz `Blob.text()`, então o FileReader entra como segundo
// caminho - sem isso a mensagem real do servidor se perderia.
const blobToText = blob => {
  if (typeof blob.text === 'function') return blob.text();

  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsText(blob);
  });
};

// A resposta de erro também vem como blob, porque o pedido esperava um arquivo.
const readError = async error => {
  const data = error?.response?.data;
  if (data instanceof Blob) {
    try {
      const parsed = JSON.parse(await blobToText(data));
      if (parsed?.error) return parsed.error;
    } catch (parseError) {
      // Cai no aviso genérico abaixo.
    }
  }
  return t('TICKET.EXPORT.FAILED');
};

const handleAction = async ({ value }) => {
  if (isExporting.value) return;

  isOpen.value = false;
  isExporting.value = true;
  try {
    const response = await TicketsAPI.exportSearch(
      toSearchParams(props.filters),
      value
    );
    downloadBlob(
      response.data,
      `tickets.${value}`,
      response.headers?.['content-disposition']
    );
  } catch (error) {
    // O servidor recusa uma busca vazia ou grande demais, e explica por quê.
    useAlert(await readError(error));
  } finally {
    isExporting.value = false;
  }
};
</script>

<template>
  <OnClickOutside class="relative" @trigger="isOpen = false">
    <button
      type="button"
      class="flex items-center justify-between h-10 gap-2 px-3 text-sm border rounded-lg border-n-strong bg-n-alpha-black2 text-n-slate-12 hover:border-n-slate-8 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand disabled:opacity-50 disabled:cursor-not-allowed"
      :disabled="isDisabled"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      :title="count === 0 ? t('TICKET.EXPORT.EMPTY') : undefined"
      @click="toggle"
    >
      <Icon
        :icon="isExporting ? 'i-lucide-loader-circle' : 'i-lucide-download'"
        class="shrink-0 text-n-slate-11"
        :class="{ 'animate-spin': isExporting }"
      />
      <span class="whitespace-nowrap">{{ label }}</span>
      <Icon
        :icon="isOpen ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        class="shrink-0 text-n-slate-11"
      />
    </button>

    <DropdownMenu
      v-if="isOpen"
      :menu-items="menuItems"
      class="mt-1 top-full ltr:right-0 rtl:left-0 w-40"
      @action="handleAction"
    />
  </OnClickOutside>
</template>
