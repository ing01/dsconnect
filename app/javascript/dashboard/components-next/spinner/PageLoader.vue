<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from './Spinner.vue';

// Carregamento de uma tela (ou de uma area grande) que ainda nao tem nada para
// mostrar: icone de tamanho controlado + texto, centralizados. Nunca deve ser
// so o icone - sem texto parece que a tela travou.
const props = defineProps({
  message: { type: String, default: '' },
  size: { type: [Number, String], default: 32 },
});

const { t } = useI18n();

const text = computed(() => props.message || t('GENERAL.LOADING'));
</script>

<template>
  <div
    class="flex flex-col items-center justify-center w-full gap-3 py-10 min-h-[10rem] text-n-slate-11"
    role="status"
    aria-live="polite"
  >
    <Spinner :size="size" class="flex-shrink-0 text-n-brand" />
    <span class="text-sm text-center">{{ text }}</span>
  </div>
</template>
