<script setup>
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CustomerBriefingContent from './CustomerBriefingContent.vue';
import CustomerBriefingSummary from './CustomerBriefingSummary.vue';
import { useCustomerBriefingPreference } from './useCustomerBriefingPreference';
import CustomerBriefingAPI from 'dashboard/api/customerBriefing';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  assigneeId: { type: Number, default: null },
  status: { type: String, default: '' },
});

const { t } = useI18n();
const currentUserId = useMapGetter('getCurrentUserID');
const accountId = useMapGetter('getCurrentAccountId');
const { autoOpen, wasShown, markShown } = useCustomerBriefingPreference();

const dialogRef = ref(null);
const briefing = ref(null);
const isLoading = ref(false);
const hasError = ref(false);
// Troca de conversa ou de empresa no meio do caminho: so' a ultima resposta vale.
let latestRequest = 0;

const load = async companyId => {
  latestRequest += 1;
  const request = latestRequest;
  isLoading.value = true;
  hasError.value = false;

  try {
    const { data } = await CustomerBriefingAPI.getBriefing(
      props.conversationId,
      companyId
    );
    if (request === latestRequest) briefing.value = data;
  } catch (error) {
    if (request === latestRequest) hasError.value = true;
  } finally {
    if (request === latestRequest) isLoading.value = false;
  }
};

// Busca de novo a cada abertura: tickets e conversas mudam o tempo todo.
const open = () => {
  briefing.value = null;
  dialogRef.value.open();
  load();
};

const close = () => dialogRef.value?.close();

// Abre sozinho uma unica vez, na primeira vez em que a pessoa ve uma conversa
// que e' dela - ao assumir, ou ao abrir uma que foi atribuida a ela.
const openIfJustTaken = () => {
  if (!autoOpen.value || props.status === 'resolved') return;
  if (!props.assigneeId || props.assigneeId !== currentUserId.value) return;

  const key = `${accountId.value}:${props.conversationId}`;
  if (wasShown(key)) return;

  markShown(key);
  open();
};

watch(
  () => [props.conversationId, props.assigneeId, props.status],
  ([conversationId], [previousId]) => {
    if (conversationId !== previousId) {
      latestRequest += 1;
      close();
    }
    openIfJustTaken();
  }
);

onMounted(openIfJustTaken);
</script>

<template>
  <Button
    size="sm"
    variant="ghost"
    color="slate"
    icon="i-lucide-contact-round"
    class="rounded-md"
    data-testid="open-customer-briefing"
    :label="t('CUSTOMER_BRIEFING.BUTTON')"
    @click="open"
  />
  <Dialog
    ref="dialogRef"
    width="3xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="flex items-center justify-between gap-3">
      <h3 class="m-0 text-base font-medium text-n-slate-12">
        {{ t('CUSTOMER_BRIEFING.TITLE') }}
      </h3>
      <Button
        type="button"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-x"
        data-testid="close-customer-briefing"
        :aria-label="t('CUSTOMER_BRIEFING.CLOSE')"
        @click="close"
      />
    </div>

    <p v-if="isLoading && !briefing" class="m-0 text-sm text-n-slate-11">
      {{ t('CUSTOMER_BRIEFING.LOADING') }}
    </p>
    <div v-else-if="hasError" class="flex flex-col items-start gap-2">
      <p class="m-0 text-sm text-n-ruby-11">
        {{ t('CUSTOMER_BRIEFING.ERROR') }}
      </p>
      <Button
        type="button"
        size="sm"
        variant="faded"
        color="slate"
        :label="t('CUSTOMER_BRIEFING.RETRY')"
        @click="load()"
      />
    </div>
    <CustomerBriefingContent
      v-else-if="briefing"
      :briefing="briefing"
      :class="{ 'opacity-60': isLoading }"
      @select-company="load"
      @navigate="close"
    >
      <template #summary>
        <CustomerBriefingSummary
          :key="`${conversationId}-${briefing.company?.id}`"
          :conversation-id="conversationId"
          :company-id="briefing.company?.id"
        />
      </template>
    </CustomerBriefingContent>

    <label
      class="flex items-center gap-2 pt-3 m-0 text-sm border-t cursor-pointer border-n-weak text-n-slate-11"
    >
      <input
        v-model="autoOpen"
        type="checkbox"
        class="m-0"
        data-testid="briefing-auto-open"
      />
      {{ t('CUSTOMER_BRIEFING.AUTO_OPEN') }}
    </label>
  </Dialog>
</template>
