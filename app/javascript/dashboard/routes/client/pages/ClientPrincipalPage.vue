<script setup>
/**
 * O "Principal" do Portal do Cliente - primeira tela ao entrar, mesmo
 * esquema da tela Principal dos atendentes: uma saudação e uma lista de
 * novidades. A diferença é o CONTEÚDO: aqui só entra o que muda a
 * experiência do PORTAL (chat, tickets, notificações) - nunca novidade
 * interna da equipe, que tem a própria lista.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getClientSession } from 'dashboard/helper/clientSession';
import ChangelogEntryCard from 'dashboard/routes/dashboard/principal/components/ChangelogEntryCard.vue';
import { getVisiblePrincipalEntries } from '../principalData';

const { t } = useI18n();

const contactName = computed(
  () => getClientSession()?.contact?.name?.split(' ')[0] || ''
);

const greeting = computed(() => {
  const hours = new Date().getHours();
  let key = 'CLIENT_AREA.PRINCIPAL.GREETING_AFTERNOON';
  if (hours < 12) key = 'CLIENT_AREA.PRINCIPAL.GREETING_MORNING';
  else if (hours >= 18) key = 'CLIENT_AREA.PRINCIPAL.GREETING_EVENING';
  return t(key, { name: contactName.value });
});

const visibleEntries = computed(() => getVisiblePrincipalEntries());
</script>

<template>
  <div
    class="flex flex-col w-full h-full min-h-0 gap-8 p-4 overflow-y-auto sm:p-6"
  >
    <div
      class="flex flex-col gap-1 p-8 text-center rounded-2xl sm:text-left bg-gradient-to-br from-n-blue-3 to-n-teal-3"
    >
      <p
        class="m-0 text-2xl font-semibold text-n-slate-12 font-interDisplay tracking-[0.3px]"
      >
        {{ greeting }}
      </p>
      <p class="max-w-2xl m-0 mt-1 text-base text-n-slate-11">
        {{ t('CLIENT_AREA.PRINCIPAL.DESCRIPTION') }}
      </p>
    </div>

    <div>
      <h2 class="mb-1 text-lg font-semibold text-n-slate-12">
        {{ t('CLIENT_AREA.PRINCIPAL.WHATS_NEW_TITLE') }}
      </h2>
      <p class="mb-4 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.PRINCIPAL.WHATS_NEW_SUBTITLE') }}
      </p>

      <div v-if="visibleEntries.length" class="flex flex-col gap-3">
        <ChangelogEntryCard
          v-for="entry in visibleEntries"
          :key="entry.id"
          v-bind="entry"
        />
      </div>
      <p v-else class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.PRINCIPAL.WHATS_NEW_EMPTY') }}
      </p>
    </div>
  </div>
</template>
