<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import TicketCatalogSelect from './TicketCatalogSelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const emit = defineEmits(['closed']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const isWorking = ref(false);

const catalogId = ref(null);
const areaId = ref(null);
const itemId = ref(null);
const subject = ref('');
const body = ref('');

const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');

// The server is the authority on what is still missing; the dialog reads its
// verdict rather than re-deriving the rules here.
const missing = computed(() => props.ticket.missing_close_requirements || []);
const needsCatalog = computed(() => missing.value.includes('service_catalog'));
const needsCommunication = computed(() =>
  missing.value.includes('customer_communication')
);
// A requester with no address cannot be told anything, so this is reported on
// its own instead of failing at send time.
const missingEmail = computed(() => missing.value.includes('contact_email'));

const classification = computed(() => props.ticket.service_catalog_item);

const catalogReady = computed(() => !needsCatalog.value || !!itemId.value);
const communicationReady = computed(
  () =>
    !needsCommunication.value ||
    (!missingEmail.value && !!subject.value.trim() && !!body.value.trim())
);
const canSubmit = computed(() => catalogReady.value && communicationReady.value);

const open = () => {
  catalogId.value = null;
  areaId.value = null;
  itemId.value = null;
  subject.value = t('TICKET.CLOSE.DEFAULT_SUBJECT', {
    number: props.ticket.display_id,
  });
  body.value = '';
  store.dispatch('serviceCatalogs/fetch');
  dialogRef.value?.open();
};

// The classification comes first, then the message, then the close - and each
// step only runs once the one before it succeeded. A failed send leaves the
// ticket open with whatever was already saved, so retrying costs nothing.
const submit = async () => {
  if (!canSubmit.value || isWorking.value) return;

  isWorking.value = true;
  try {
    if (needsCatalog.value) {
      await store.dispatch('tickets/classifyTicket', {
        id: props.ticket.id,
        serviceCatalogId: catalogId.value,
        serviceCatalogAreaId: areaId.value,
        serviceCatalogItemId: itemId.value,
      });
    }

    if (needsCommunication.value) {
      await store.dispatch('tickets/sendCustomerCommunication', {
        ticketId: props.ticket.id,
        subject: subject.value.trim(),
        body: body.value,
        closing: true,
      });
    }

    await store.dispatch('tickets/closeTicket', props.ticket.id);
    dialogRef.value?.close();
    emit('closed');
  } catch (error) {
    // The server explains what went wrong - a refused delivery, a missing
    // address - and the ticket stays exactly as it was.
    useAlert(
      error?.response?.data?.error || t('TICKET.API.ERROR_MESSAGE')
    );
  } finally {
    isWorking.value = false;
  }
};

watch(
  () => props.ticket.id,
  () => {
    catalogId.value = null;
    areaId.value = null;
    itemId.value = null;
  }
);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    overflow-y-auto
    :title="t('TICKET.CLOSE.TITLE', { number: ticket.display_id })"
    :confirm-button-label="t('TICKET.CLOSE.CONFIRM')"
    :disable-confirm-button="!canSubmit"
    :is-loading="isWorking"
    @confirm="submit"
  >
    <div class="flex flex-col gap-5 min-w-0">
      <!-- Step 1: classification. Already done shows as done rather than
           asking again. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="needsCatalog ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'"
            class="flex-shrink-0 size-4"
            :class="needsCatalog ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_CLASSIFICATION') }}
        </h3>

        <p v-if="!needsCatalog" class="text-sm text-n-slate-11">
          {{ classification?.full_path?.join(' → ') }}
        </p>

        <TicketCatalogSelect
          v-else
          v-model:catalog-id="catalogId"
          v-model:area-id="areaId"
          v-model:item-id="itemId"
          :catalogs="catalogs"
        />
      </section>

      <div class="h-px bg-n-weak" />

      <!-- Step 2: the closing message. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsCommunication ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'
            "
            class="flex-shrink-0 size-4"
            :class="needsCommunication ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_COMMUNICATION') }}
        </h3>

        <p v-if="!needsCommunication" class="text-sm text-n-slate-11">
          {{ t('TICKET.CLOSE.COMMUNICATION_DONE') }}
        </p>

        <!-- Nothing can be sent without an address, and saying so beats letting
             the agent write a message that cannot go out. -->
        <p
          v-else-if="missingEmail"
          class="p-3 text-sm rounded-lg text-n-amber-11 bg-n-amber-3"
        >
          {{ t('TICKET.CLOSE.NO_CONTACT_EMAIL') }}
        </p>

        <template v-else>
          <p class="text-sm text-n-slate-11">
            {{ t('TICKET.CLOSE.TO') }}:
            <span class="text-n-slate-12">{{ ticket.customer_email }}</span>
          </p>

          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.SUBJECT') }}<span class="text-n-ruby-11">*</span>
            </span>
            <input v-model="subject" type="text" class="w-full mb-0" />
          </label>

          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.MESSAGE') }}<span class="text-n-ruby-11">*</span>
            </span>
            <FullEditor
              v-model="body"
              class="min-w-0 [&_.ProseMirror]:min-h-[10rem]"
              :placeholder="t('TICKET.CLOSE.MESSAGE_PLACEHOLDER')"
            />
          </label>
        </template>
      </section>
    </div>
  </Dialog>
</template>
