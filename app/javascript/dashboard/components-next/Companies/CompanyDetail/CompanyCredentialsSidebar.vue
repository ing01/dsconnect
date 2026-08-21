<script setup>
import { reactive } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  credentials: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['add', 'edit', 'delete']);

const { t } = useI18n();

const revealed = reactive(new Set());
const revealKey = (credentialId, field) => `${credentialId}:${field}`;

const isRevealed = (credentialId, field) =>
  revealed.has(revealKey(credentialId, field));

const toggleReveal = (credentialId, field) => {
  const key = revealKey(credentialId, field);
  if (revealed.has(key)) revealed.delete(key);
  else revealed.add(key);
};

const maskedValue = (credentialId, field, value) => {
  if (!value) return '—';
  return isRevealed(credentialId, field) ? value : '••••••••';
};

const SECRET_ROWS = [
  { field: 'dbPassword', labelKey: 'DB_PASSWORD' },
  { field: 'anydeskPassword', labelKey: 'ANYDESK_PASSWORD' },
  { field: 'rdpPassword', labelKey: 'RDP_PASSWORD' },
];
</script>

<template>
  <div class="flex flex-col gap-4">
    <Button
      :label="t('COMPANIES.DETAIL.CREDENTIALS.ACTIONS.ADD')"
      size="sm"
      icon="i-lucide-plus"
      class="self-start"
      @click="emit('add')"
    />

    <div v-if="isLoading" class="flex items-center justify-center py-10 text-n-slate-11">
      <Spinner />
    </div>

    <div v-else-if="credentials.length > 0" class="flex flex-col gap-3">
      <div
        v-for="credential in credentials"
        :key="credential.id"
        class="flex flex-col gap-3 p-4 rounded-xl border border-n-weak"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ credential.label }}
          </span>
          <div class="flex items-center gap-1">
            <Button
              icon="i-lucide-pencil"
              variant="ghost"
              color="slate"
              size="sm"
              @click="emit('edit', credential)"
            />
            <Button
              icon="i-lucide-trash-2"
              variant="ghost"
              color="ruby"
              size="sm"
              @click="emit('delete', credential)"
            />
          </div>
        </div>

        <div
          v-if="credential.dbHost || credential.dbName"
          class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-n-slate-11"
        >
          <span>{{ credential.dbType || '—' }}</span>
          <span>{{ credential.dbHost }}{{ credential.dbPort ? `:${credential.dbPort}` : '' }}</span>
          <span>{{ credential.dbName }}</span>
          <span>{{ credential.dbUsername }}</span>
        </div>

        <div
          v-for="row in SECRET_ROWS"
          :key="row.field"
          v-show="credential[row.field]"
          class="flex items-center justify-between gap-2 px-3 py-1.5 rounded-lg bg-n-alpha-1"
        >
          <span class="text-xs text-n-slate-11">
            {{ t(`COMPANIES.DETAIL.CREDENTIALS.FORM.${row.labelKey}.LABEL`) }}
          </span>
          <div class="flex items-center gap-2">
            <span class="text-xs font-mono text-n-slate-12">
              {{ maskedValue(credential.id, row.field, credential[row.field]) }}
            </span>
            <button
              type="button"
              class="text-xs text-n-blue-11 hover:underline"
              @click="toggleReveal(credential.id, row.field)"
            >
              {{
                isRevealed(credential.id, row.field)
                  ? t('COMPANIES.DETAIL.CREDENTIALS.ACTIONS.HIDE')
                  : t('COMPANIES.DETAIL.CREDENTIALS.ACTIONS.REVEAL')
              }}
            </button>
          </div>
        </div>

        <p v-if="credential.notes" class="text-xs text-n-slate-11">
          {{ credential.notes }}
        </p>
      </div>
    </div>

    <p
      v-else
      class="py-8 px-4 text-sm text-center rounded-xl border border-dashed border-n-strong text-n-slate-11"
    >
      {{ t('COMPANIES.DETAIL.CREDENTIALS.EMPTY') }}
    </p>
  </div>
</template>
