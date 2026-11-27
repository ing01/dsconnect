<script setup>
import { useI18n } from 'vue-i18n';
import { useCustomerBriefingPreference } from 'dashboard/components/widgets/conversation/briefing/useCustomerBriefingPreference';

const { t } = useI18n();
const { autoOpen } = useCustomerBriefingPreference();
</script>

<template>
  <label class="flex items-center gap-2 m-0 text-sm text-n-slate-12">
    <input
      v-model="autoOpen"
      type="checkbox"
      class="m-0"
      data-testid="profile-briefing-auto-open"
    />
    {{ t('PROFILE_SETTINGS.FORM.CUSTOMER_BRIEFING.LABEL') }}
  </label>
</template>
