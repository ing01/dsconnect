<script setup>
import { useGreeting } from 'dashboard/composables/useGreeting';

const { greetingMessage, globalConfig } = useGreeting();
</script>

<template>
  <div
    class="min-h-screen lg:max-w-5xl max-w-4xl mx-auto p-8 w-full font-inter overflow-auto"
  >
    <p
      class="text-xl font-semibold text-n-slate-12 font-interDisplay tracking-[0.3px]"
    >
      {{ greetingMessage }}
    </p>
    <p class="text-n-slate-11 max-w-2xl text-base">
      {{
        $t('ONBOARDING.DESCRIPTION', {
          installationName: globalConfig.installationName,
        })
      }}
    </p>
  </div>
</template>
