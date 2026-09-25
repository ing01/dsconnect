<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticket: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

// Hoje so tem a chave do Jira, vinda da importacao (coluna "Desenvolvimento"
// da planilha - ver Tickets::ImportService). Sem ela, mostra o aviso de
// painel vazio, do mesmo jeito que antes desta aba ter conteudo de verdade.
const jiraKey = computed(() => props.ticket?.jira_key);
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.DEVELOPMENT.TITLE') }}
    </h2>

    <p v-if="jiraKey" class="flex items-center gap-2 text-sm text-n-slate-12">
      <Icon icon="i-lucide-git-branch" class="size-4 flex-shrink-0 text-n-slate-11" />
      <span class="font-medium">
        {{ t('TICKET.DETAIL.DEVELOPMENT.JIRA_KEY_IMPORTED') }}
      </span>
      {{ jiraKey }}
    </p>
    <p v-else class="flex items-center gap-2 text-sm text-n-slate-10">
      <Icon icon="i-lucide-info" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.DEVELOPMENT.EMPTY') }}
    </p>
  </section>
</template>
