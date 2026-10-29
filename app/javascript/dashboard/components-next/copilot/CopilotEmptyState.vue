<script setup>
import { useRoute } from 'vue-router';
import DueBotName from './DueBotName.vue';

defineProps({
  hasAssistants: {
    type: Boolean,
    default: false,
  },
  // 'agent' (colaborador) ou 'client' - muda so' o texto de apresentacao.
  audience: {
    type: String,
    default: 'agent',
    validator: value => ['agent', 'client'].includes(value),
  },
});

const route = useRoute();
</script>

<template>
  <div class="flex-1 flex flex-col gap-6 px-2">
    <div class="flex flex-col space-y-4 py-4">
      <DueBotName size="lg" />
      <div class="space-y-1">
        <h3 class="text-base font-medium text-n-slate-12 leading-8">
          {{ $t('CAPTAIN.COPILOT.PANEL_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 leading-6">
          {{
            audience === 'client'
              ? $t('CAPTAIN.COPILOT.KICK_OFF_MESSAGE_CLIENT')
              : $t('CAPTAIN.COPILOT.KICK_OFF_MESSAGE')
          }}
        </p>
      </div>
    </div>
    <div v-if="!hasAssistants" class="w-full space-y-2">
      <p class="text-sm text-n-slate-11 leading-6">
        {{ $t('CAPTAIN.ASSISTANTS.NO_ASSISTANTS_AVAILABLE') }}
      </p>
      <router-link
        :to="{
          name: 'captain_assistants_create_index',
          params: {
            accountId: route.params.accountId,
          },
        }"
        class="text-n-slate-11 underline hover:text-n-slate-12"
      >
        {{ $t('CAPTAIN.ASSISTANTS.ADD_NEW') }}
      </router-link>
    </div>
  </div>
</template>
