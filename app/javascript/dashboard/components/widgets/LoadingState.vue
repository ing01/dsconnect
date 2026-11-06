<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  message: { type: String, default: '' },
});

const { t } = useI18n();

// Sem mensagem informada, mostra o texto padrao: so o icone girando parece tela travada.
const text = computed(() => props.message || t('GENERAL.LOADING'));
</script>

<template>
  <div class="flex items-center justify-center p-8">
    <h6
      class="flex items-center gap-3 text-base text-center w-100 text-n-slate-11"
    >
      <span class="text-body-main !text-base text-n-slate-12">
        {{ text }}
      </span>
      <Spinner class="text-n-brand" />
    </h6>
  </div>
</template>
