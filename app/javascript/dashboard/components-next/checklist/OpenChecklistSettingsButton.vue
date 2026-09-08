<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();

const accountId = computed(() => store.getters.getCurrentAccountId);

// Deliberately `window.open` in a new tab, never `router.push`: the whole
// point of this shortcut is that the form the user is filling in (a Tarefa,
// a Ticket's checklist) stays exactly as it was in the current tab while they
// go build a new Checklist in another one.
const openChecklistSettings = () => {
  window.open(
    frontendURL(`accounts/${accountId.value}/settings/projects/checklists`),
    '_blank'
  );
};
</script>

<template>
  <NextButton
    type="button"
    faded
    slate
    size="xs"
    icon="i-lucide-plus"
    :label="t('CHECKLISTS.NEW_SHORTCUT')"
    @click="openChecklistSettings"
  />
</template>
