<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import TicketCatalogSelect from './TicketCatalogSelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  // So' quando o fechamento vem pela CONVERSA (Resolver): deixa ajustar o
  // assunto e a descricao ali mesmo, sem entrar no ticket. Na tela do proprio
  // ticket isso ja se edita no detalhe.
  allowEditDetails: { type: Boolean, default: false },
});

// `cancel` forwards the inner Dialog's own `close` (backdrop click, Escape, or
// the Cancelar button below) - it also fires on the `closed`/`left-open` paths,
// since both call the same Dialog's `close()`. Callers that care about a real
// cancellation (nothing was decided) must only act on it when neither of those
// has already fired for that same attempt.
const emit = defineEmits(['closed', 'left-open', 'cancel']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const isWorking = ref(false);

const catalogId = ref(null);
const areaId = ref(null);
const itemId = ref(null);
const body = ref('');
// O que foi feito para resolver. Alimenta o DueRules e a documentacao - por isso
// e' obrigatoria, e nao um campo opcional de observacao.
const resolution = ref('');
// Mesma escolha da aba Comunicacao: desmarcado, a mensagem de encerramento e
// REGISTRADA sem e-mail. Ela continua valendo para fechar o ticket - o cliente
// ve o texto na Area do Cliente -, e serve para quando a equipe ja avisou por
// telefone ou WhatsApp.
const notificarCliente = ref(true);
// Assunto e descricao editaveis (so' com `allowEditDetails`); partem do que o
// ticket ja tem e so' sao gravados se mudaram.
const title = ref('');
const description = ref('');

const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');

// The server is the authority on what is still missing; the dialog reads its
// verdict rather than re-deriving the rules here.
const missing = computed(() => props.ticket.missing_close_requirements || []);
const needsCatalog = computed(() => missing.value.includes('service_catalog'));
const needsResolution = computed(() => missing.value.includes('resolution'));
const needsCommunication = computed(() =>
  missing.value.includes('customer_communication')
);
// Pending checklist items with no Apontamento linked yet - the server bypasses
// this the moment one exists (Ticket#ensure_checklist_completed!), so this is
// informational: the agent fixes it from the Checklist/Apontamentos tabs, not
// from this dialog.
const needsChecklist = computed(() => missing.value.includes('checklist'));
// A requester with no address cannot be told anything, so this is reported on
// its own instead of failing at send time.
const missingEmail = computed(() => missing.value.includes('contact_email'));

const classification = computed(() => props.ticket.service_catalog_item);

const catalogReady = computed(() => !needsCatalog.value || !!itemId.value);
const resolutionReady = computed(
  () => !needsResolution.value || !!resolution.value.trim()
);
// The subject is not the agent's to write: the server titles every customer
// message with the ticket header, the closing notice included. Shown here so
// what will be sent is visible.
const subject = computed(() => props.ticket.display_subject);

const communicationReady = computed(
  () =>
    !needsCommunication.value || (!missingEmail.value && !!body.value.trim())
);
const detailsReady = computed(
  () => !props.allowEditDetails || !!title.value.trim()
);
const detailsChanged = computed(
  () =>
    props.allowEditDetails &&
    (title.value.trim() !== (props.ticket.title || '') ||
      description.value !== (props.ticket.description || ''))
);
const canSubmit = computed(
  () =>
    detailsReady.value &&
    catalogReady.value &&
    resolutionReady.value &&
    communicationReady.value &&
    !needsChecklist.value
);

const open = () => {
  catalogId.value = null;
  areaId.value = null;
  itemId.value = null;
  body.value = '';
  resolution.value = '';
  notificarCliente.value = true;
  title.value = props.ticket.title || '';
  description.value = props.ticket.description || '';
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
    // Primeiro o assunto/descricao: a mensagem de encerramento ao cliente usa o
    // titulo do ticket, entao ele precisa estar gravado antes do envio.
    if (detailsChanged.value) {
      await store.dispatch('tickets/updateTicket', {
        id: props.ticket.id,
        title: title.value.trim(),
        description: description.value,
      });
    }

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
        body: body.value,
        closing: true,
        notifyCustomer: notificarCliente.value,
      });
    }

    // A Resolucao vai no proprio fechamento: o servidor so' a grava se o ticket
    // fechar, entao uma recusa nao deixa texto solto no ticket.
    await store.dispatch('tickets/closeTicket', {
      id: props.ticket.id,
      resolution: needsResolution.value ? resolution.value.trim() : undefined,
    });
    // Avisa a decisao ANTES de fechar o dialogo: fechar dispara `cancel`, e quem
    // escuta (ResolveAction) so' ignora esse `cancel` se ja' soube da decisao.
    emit('closed');
    dialogRef.value?.close();
  } catch (error) {
    // The server explains what went wrong - a refused delivery, a missing
    // address - and the ticket stays exactly as it was.
    useAlert(error?.response?.data?.error || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isWorking.value = false;
  }
};

// So' resolve a conversa, sem passar pelo fechamento do ticket - a Mesa decide
// depois, com calma, se aquilo realmente acabou. Nao exige nenhum dos
// requisitos de fechamento (Catalogo, Resolucao, Comunicacao): o ticket
// continua aberto exatamente como estava.
const leaveOpen = () => {
  if (isWorking.value) return;

  // Decisao primeiro, fechamento depois: fechar o dialogo dispara `cancel`, que
  // a conversa trataria como "desisti" e NAO resolveria.
  emit('left-open');
  dialogRef.value?.close();
};

watch(
  () => props.ticket.id,
  () => {
    catalogId.value = null;
    areaId.value = null;
    itemId.value = null;
    resolution.value = '';
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
    :is-loading="isWorking"
    @confirm="submit"
    @close="emit('cancel')"
  >
    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          variant="faded"
          color="slate"
          :label="t('DIALOG.BUTTONS.CANCEL')"
          class="w-full"
          type="button"
          :disabled="isWorking"
          @click="dialogRef?.close()"
        />
        <Button
          variant="faded"
          color="amber"
          :label="t('TICKET.CLOSE.LEAVE_OPEN')"
          class="w-full"
          type="button"
          :disabled="isWorking"
          @click="leaveOpen"
        />
        <Button
          color="blue"
          :label="t('TICKET.CLOSE.CONFIRM')"
          class="w-full"
          :is-loading="isWorking"
          :disabled="!canSubmit || isWorking"
          type="submit"
        />
      </div>
    </template>

    <div class="flex flex-col gap-5 min-w-0">
      <!-- Assunto e descricao: so' no fechamento feito pela conversa. -->
      <template v-if="allowEditDetails">
        <section class="flex flex-col gap-3 min-w-0">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.CLOSE.STEP_DETAILS') }}
          </h3>
          <p class="text-xs text-n-slate-10">
            {{ t('TICKET.CLOSE.DETAILS_HINT') }}
          </p>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.DETAILS_TITLE')
              }}<span class="text-n-ruby-11">*</span>
            </span>
            <input v-model="title" type="text" class="w-full mb-0 text-sm" />
          </label>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.DETAILS_DESCRIPTION') }}
            </span>
            <textarea
              v-model="description"
              rows="4"
              class="w-full mb-0 text-sm resize-y min-h-[6rem]"
            />
          </label>
        </section>

        <div class="h-px bg-n-weak" />
      </template>

      <!-- Step 1: classification. Already done shows as done rather than
           asking again. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsCatalog ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'
            "
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

      <!-- Step 2: a Resolucao. Obrigatoria: e' o que a equipe realmente fez, e e'
           a partir dela que o DueRules e a documentacao aprendem. Ja registrada,
           aparece como feita em vez de pedir de novo. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsResolution ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'
            "
            class="flex-shrink-0 size-4"
            :class="needsResolution ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_RESOLUTION') }}
        </h3>

        <p
          v-if="!needsResolution"
          class="text-sm whitespace-pre-line text-n-slate-11"
        >
          {{ ticket.resolution }}
        </p>

        <label v-else class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.CLOSE.RESOLUTION') }}<span class="text-n-ruby-11">*</span>
          </span>
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET.CLOSE.RESOLUTION_HINT') }}
          </span>
          <textarea
            v-model="resolution"
            rows="5"
            class="resolucao w-full mb-0 text-sm resize-y min-h-[8rem]"
            :placeholder="t('TICKET.CLOSE.RESOLUTION_PLACEHOLDER')"
          />
        </label>
      </section>

      <div class="h-px bg-n-weak" />

      <!-- Checklist: informational only. The server is the authority (a linked
           Apontamento bypasses this), so this section just points the agent at
           where to fix it instead of re-deriving the rule client-side. -->
      <section v-if="needsChecklist" class="flex flex-col gap-2 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            icon="i-lucide-circle-alert"
            class="flex-shrink-0 size-4 text-n-amber-11"
          />
          {{ t('TICKET.CLOSE.STEP_CHECKLIST') }}
        </h3>
        <p class="p-3 text-sm rounded-lg text-n-amber-11 bg-n-amber-3">
          {{ t('TICKET.CLOSE.CHECKLIST_PENDING') }}
        </p>
      </section>

      <div v-if="needsChecklist" class="h-px bg-n-weak" />

      <!-- Step 2: the closing message. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsCommunication
                ? 'i-lucide-circle-alert'
                : 'i-lucide-circle-check'
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
          <!-- Destinatario e assunto so existem se houver e-mail. Sem envio nao
               ha para quem nem com que titulo, e mostra-los seria descrever uma
               mensagem que nao vai sair. -->
          <template v-if="notificarCliente">
            <p class="text-sm text-n-slate-11">
              {{ t('TICKET.CLOSE.TO') }}:
              <span class="text-n-slate-12">{{ ticket.customer_email }}</span>
            </p>

            <p class="text-sm truncate text-n-slate-11" :title="subject">
              {{ t('TICKET.CLOSE.SUBJECT') }}:
              <span class="text-n-slate-12">{{ subject }}</span>
            </p>
          </template>

          <!-- Uma `div`, e nao um `label`: o `FullEditor` carrega dentro dele um
               `<input type="file" hidden>` (o envio de imagem do editor de
               artigos). Envolto num `label`, qualquer clique na area da
               mensagem ativava esse input e abria a tela de enviar arquivo do
               sistema - ninguem pediu anexo aqui. O editor nao e um campo
               nativo, entao o `label` tambem nao dava foco a nada. -->
          <div class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.MESSAGE')
              }}<span class="text-n-ruby-11">*</span>
            </span>
            <FullEditor
              v-model="body"
              class="min-w-0 [&_.ProseMirror]:min-h-[10rem]"
              :placeholder="t('TICKET.CLOSE.MESSAGE_PLACEHOLDER')"
            />
          </div>

          <!-- Fora da `div` do campo de proposito: e uma decisao sobre o envio,
               nao parte do texto. -->
          <label class="flex items-start gap-2 cursor-pointer min-w-0">
            <Checkbox v-model="notificarCliente" class="mt-0.5 flex-shrink-0" />
            <span class="flex flex-col gap-0.5 min-w-0">
              <span class="text-sm text-n-slate-12">
                {{ t('TICKET.COMMUNICATION.NOTIFY') }}
              </span>
              <span v-if="!notificarCliente" class="text-xs text-n-slate-10">
                {{ t('TICKET.COMMUNICATION.NOTIFY_HINT') }}
              </span>
            </span>
          </label>
        </template>
      </section>
    </div>
  </Dialog>
</template>
