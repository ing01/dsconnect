<script setup>
/**
 * Configurações > Painel de Conversas.
 *
 * O administrador define em quanto tempo a conversa passa de verde para laranja
 * e para vermelho, a frequência de atualização, o tamanho das listas e o som.
 * Quem pode VER o painel é decidido na Função personalizada.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { conversationPanelSettingsAPI } from 'dashboard/api/conversationPanel';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const isLoading = ref(true);
const isSaving = ref(false);
const form = ref({
  green_until_minutes: 5,
  orange_until_minutes: 15,
  refresh_seconds: 30,
  list_limit: 50,
  sound_enabled: false,
});

const isInvalid = computed(
  () =>
    Number(form.value.orange_until_minutes) <=
    Number(form.value.green_until_minutes)
);

const load = async () => {
  try {
    const { data } = await conversationPanelSettingsAPI.show();
    form.value = { ...form.value, ...data };
  } catch {
    useAlert(t('CONVERSATION_PANEL.SETTINGS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  if (isInvalid.value) {
    useAlert(t('CONVERSATION_PANEL.SETTINGS.INVALID'));
    return;
  }
  isSaving.value = true;
  try {
    const { data } = await conversationPanelSettingsAPI.save({
      green_until_minutes: Number(form.value.green_until_minutes),
      orange_until_minutes: Number(form.value.orange_until_minutes),
      refresh_seconds: Number(form.value.refresh_seconds),
      list_limit: Number(form.value.list_limit),
      sound_enabled: Boolean(form.value.sound_enabled),
    });
    form.value = { ...form.value, ...data };
    useAlert(t('CONVERSATION_PANEL.SETTINGS.SAVED'));
  } catch (error) {
    useAlert(
      error?.response?.data?.message || t('CONVERSATION_PANEL.SETTINGS.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <SettingsLayout :is-loading="isLoading">
    <template #header>
      <BaseSettingsHeader
        :title="t('CONVERSATION_PANEL.SETTINGS.TITLE')"
        :description="t('CONVERSATION_PANEL.SETTINGS.DESCRIPTION')"
      />
    </template>

    <template #body>
      <form
        class="flex flex-col max-w-xl gap-4 min-w-0"
        data-testid="panel-settings-form"
        @submit.prevent="save"
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION_PANEL.SETTINGS.GREEN_UNTIL') }}
          </span>
          <span class="flex items-center gap-2">
            <input
              v-model.number="form.green_until_minutes"
              type="number"
              min="1"
              max="1440"
              class="!mb-0 w-28"
              data-testid="panel-setting-green"
            />
            <span class="text-sm text-n-slate-11">
              {{ t('CONVERSATION_PANEL.SETTINGS.MINUTES') }}
            </span>
          </span>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION_PANEL.SETTINGS.ORANGE_UNTIL') }}
          </span>
          <span class="flex items-center gap-2">
            <input
              v-model.number="form.orange_until_minutes"
              type="number"
              min="2"
              max="10080"
              class="!mb-0 w-28"
              data-testid="panel-setting-orange"
            />
            <span class="text-sm text-n-slate-11">
              {{ t('CONVERSATION_PANEL.SETTINGS.MINUTES') }}
            </span>
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('CONVERSATION_PANEL.SETTINGS.RED_HINT') }}
          </span>
          <span
            v-if="isInvalid"
            class="text-xs text-n-ruby-11"
            data-testid="panel-settings-invalid"
          >
            {{ t('CONVERSATION_PANEL.SETTINGS.INVALID') }}
          </span>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION_PANEL.SETTINGS.REFRESH') }}
          </span>
          <span class="flex items-center gap-2">
            <input
              v-model.number="form.refresh_seconds"
              type="number"
              min="10"
              max="300"
              class="!mb-0 w-28"
            />
            <span class="text-sm text-n-slate-11">
              {{ t('CONVERSATION_PANEL.SETTINGS.SECONDS') }}
            </span>
          </span>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION_PANEL.SETTINGS.LIST_LIMIT') }}
          </span>
          <input
            v-model.number="form.list_limit"
            type="number"
            min="5"
            max="200"
            class="!mb-0 w-28"
          />
          <span class="text-xs text-n-slate-11">
            {{ t('CONVERSATION_PANEL.SETTINGS.LIST_LIMIT_HELP') }}
          </span>
        </label>

        <label class="flex items-start gap-2">
          <input v-model="form.sound_enabled" type="checkbox" class="mt-1" />
          <span class="text-sm text-n-slate-12">
            {{ t('CONVERSATION_PANEL.SETTINGS.SOUND') }}
          </span>
        </label>

        <div>
          <Button
            type="submit"
            size="sm"
            :label="t('CONVERSATION_PANEL.SETTINGS.SAVE')"
            :is-loading="isSaving"
            :disabled="isInvalid"
            data-testid="panel-settings-save"
          />
        </div>
      </form>
    </template>
  </SettingsLayout>
</template>
