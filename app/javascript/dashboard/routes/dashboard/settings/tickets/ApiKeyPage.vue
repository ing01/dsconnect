<script setup>
/**
 * A chave da API de Integracao de Tickets (Configuracoes > Tickets > API de
 * Tickets) - o que um sistema EXTERNO (ex: a IA de triagem de outro time) usa
 * para ler/rotear tickets desta conta, sem precisar logar como um usuario.
 *
 * Uma por conta de proposito: "gerar nova" sempre SUBSTITUI a anterior
 * (ver TicketApiKey no backend). O token completo so' aparece na resposta
 * de `generate` - dali em diante o servidor so devolve a versao mascarada, e
 * esta tela nunca tem como mostra-lo de novo (nem se quisesse).
 */
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import TicketApiKeyAPI from 'dashboard/api/ticketApiKey';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmButton from 'dashboard/components-next/button/ConfirmButton.vue';

const { t } = useI18n();

const isLoading = ref(true);
const isSubmitting = ref(false);
const exists = ref(false);
const maskedToken = ref('');
const revealedToken = ref('');
const lastUsedAt = ref(null);

const fetchKey = async () => {
  isLoading.value = true;
  try {
    const { data } = await TicketApiKeyAPI.get();
    exists.value = data.exists;
    maskedToken.value = data.masked_token || '';
    lastUsedAt.value = data.last_used_at;
  } catch {
    useAlert(t('TICKET.SETTINGS.API_KEY.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const generate = async () => {
  isSubmitting.value = true;
  try {
    const { data } = await TicketApiKeyAPI.generate();
    exists.value = true;
    maskedToken.value = data.masked_token;
    revealedToken.value = data.token;
    lastUsedAt.value = null;
    useAlert(t('TICKET.SETTINGS.API_KEY.API.GENERATE_SUCCESS'));
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.SETTINGS.API_KEY.API.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

const revoke = async () => {
  isSubmitting.value = true;
  try {
    await TicketApiKeyAPI.revoke();
    exists.value = false;
    maskedToken.value = '';
    revealedToken.value = '';
    lastUsedAt.value = null;
    useAlert(t('TICKET.SETTINGS.API_KEY.API.REVOKE_SUCCESS'));
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.SETTINGS.API_KEY.API.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

const copy = async () => {
  await copyTextToClipboard(revealedToken.value || maskedToken.value);
  useAlert(t('TICKET.SETTINGS.API_KEY.COPY_SUCCESS'));
};

onMounted(fetchKey);
</script>

<template>
  <SettingsLayout :is-loading="isLoading">
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.API_KEY.TITLE')"
        :description="t('TICKET.SETTINGS.API_KEY.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-4 max-w-2xl">
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <span class="font-medium text-n-slate-12">
            {{ t('TICKET.SETTINGS.API_KEY.STATUS_LABEL') }}:
          </span>
          <span>
            {{
              exists
                ? t('TICKET.SETTINGS.API_KEY.ACTIVE')
                : t('TICKET.SETTINGS.API_KEY.INACTIVE')
            }}
          </span>
          <span v-if="exists">
            ·
            {{
              lastUsedAt
                ? t('TICKET.SETTINGS.API_KEY.LAST_USED_AT', {
                    date: new Date(lastUsedAt).toLocaleString(),
                  })
                : t('TICKET.SETTINGS.API_KEY.LAST_USED_NEVER')
            }}
          </span>
        </div>

        <div v-if="exists" class="flex flex-col gap-2">
          <div class="flex flex-row gap-2">
            <woot-input
              name="ticket_api_key"
              class="flex-1 [&>input]:!py-1.5"
              :styles="{ borderRadius: '12px', fontSize: '14px' }"
              type="text"
              :model-value="revealedToken || maskedToken"
              readonly
            />
            <Button
              :label="t('TICKET.SETTINGS.API_KEY.COPY')"
              slate
              outline
              icon="i-lucide-copy"
              class="rounded-xl"
              @click="copy"
            />
          </div>
          <p v-if="revealedToken" class="m-0 text-sm text-n-amber-11">
            {{ t('TICKET.SETTINGS.API_KEY.REVEAL_NOTICE') }}
          </p>
        </div>

        <div class="flex flex-row gap-2">
          <ConfirmButton
            v-if="exists"
            :label="t('TICKET.SETTINGS.API_KEY.REGENERATE')"
            :confirm-label="t('TICKET.SETTINGS.API_KEY.CONFIRM_REGENERATE')"
            :confirm-hint="t('TICKET.SETTINGS.API_KEY.CONFIRM_REGENERATE_HINT')"
            color="slate"
            confirm-color="amber"
            variant="outline"
            icon="i-lucide-key-round"
            class="rounded-xl"
            :disabled="isSubmitting"
            @click="generate"
          />
          <Button
            v-else
            :label="t('TICKET.SETTINGS.API_KEY.GENERATE')"
            icon="i-lucide-key-round"
            class="rounded-xl"
            :disabled="isSubmitting"
            @click="generate"
          />
          <ConfirmButton
            v-if="exists"
            :label="t('TICKET.SETTINGS.API_KEY.REVOKE')"
            :confirm-label="t('TICKET.SETTINGS.API_KEY.CONFIRM_REVOKE')"
            :confirm-hint="t('TICKET.SETTINGS.API_KEY.CONFIRM_REVOKE_HINT')"
            color="slate"
            confirm-color="ruby"
            variant="outline"
            icon="i-lucide-trash-2"
            class="rounded-xl"
            :disabled="isSubmitting"
            @click="revoke"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
