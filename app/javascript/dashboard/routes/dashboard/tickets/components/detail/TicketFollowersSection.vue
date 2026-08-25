<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
</script>

<template>
  <!-- Structure only for now: followers have no backing table yet, so nothing
       here invents data. The Responsavel above is a different concept - one
       owner, versus people merely watching the ticket. -->
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-2 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.FOLLOWERS.TITLE') }}
    </h2>
    <p class="flex items-center gap-2 text-sm text-n-slate-10">
      <Icon icon="i-lucide-users" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.FOLLOWERS.EMPTY') }}
    </p>
  </section>
</template>
