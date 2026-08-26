<script setup>
import { useI18n } from 'vue-i18n';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ServiceCatalogSection from './ServiceCatalogSection.vue';

const { t } = useI18n();
</script>

<template>
  <!-- No Mesa selector on purpose: the catalogue is account-wide. One Mesa
       attends several catalogues, so tying it to a Mesa would be wrong. -->
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.CATALOG.TITLE')"
        :description="t('TICKET.SETTINGS.CATALOG.DESCRIPTION')"
      />
    </template>

    <template #body>
      <ServiceCatalogSection />
    </template>
  </SettingsLayout>
</template>
