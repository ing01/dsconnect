<script setup>
/**
 * Pergunta o ESCOPO antes de aplicar uma edição ou exclusão a uma ocorrência
 * de uma série recorrente - sempre com as 3 opções, mesmo na primeira
 * ocorrência da série (onde "esta e as próximas" e "toda a série" dão no
 * mesmo resultado, mas sem caso especial na tela).
 *
 * Mostrado pelo `AgendaPage.vue` ANTES de despachar `calendarEvents/update`
 * ou `calendarEvents/delete`, nunca para um evento simples.
 */
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  // 'update' | 'destroy' - so troca o titulo mostrado.
  action: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['close', 'confirm']);

const { t } = useI18n();

const scope = ref('occurrence');

// Volta pra opcao padrao a cada vez que o dialogo abre, pra nao repetir por
// engano a escolha da ultima edicao/exclusao.
watch(
  () => props.show,
  show => {
    if (show) scope.value = 'occurrence';
  }
);
</script>

<template>
  <woot-modal :show="show" :on-close="() => emit('close')" size="small">
    <div class="flex flex-col gap-4 p-6">
      <woot-modal-header
        :header-title="
          action === 'destroy'
            ? t('AGENDA.RECURRENCE_SCOPE.DESTROY_TITLE')
            : t('AGENDA.RECURRENCE_SCOPE.UPDATE_TITLE')
        "
      />

      <div class="flex flex-col gap-2">
        <label
          v-for="option in ['occurrence', 'future', 'series']"
          :key="option"
          class="flex items-center gap-2 text-sm text-n-slate-12"
        >
          <input v-model="scope" type="radio" :value="option" />
          {{ t(`AGENDA.RECURRENCE_SCOPE.${option.toUpperCase()}`) }}
        </label>
      </div>

      <div class="flex items-center justify-end gap-2">
        <NextButton
          variant="ghost"
          color="slate"
          :label="t('AGENDA.FORM.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          :label="t('AGENDA.RECURRENCE_SCOPE.CONFIRM')"
          @click="emit('confirm', scope)"
        />
      </div>
    </div>
  </woot-modal>
</template>
