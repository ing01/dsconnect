<script setup>
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { downloadBlob } from 'dashboard/helper/downloadHelper';
import TicketProposalsAPI from 'dashboard/api/ticketProposals';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TicketProposalForm from './TicketProposalForm.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
});

const { t } = useI18n();

const STATUS_COLOR = { pending: 'amber', approved: 'teal', refused: 'ruby' };

const proposals = ref([]);
const isFormOpen = ref(false);
const busyId = ref(null);

const currency = value =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    Number(value)
  );

// "2026-10-27" vira "27/10/2026" sem passar por Date, que deslocaria o dia pelo
// fuso do navegador.
const day = value => value.split('-').reverse().join('/');

const statusLabel = proposal =>
  t(`TICKET.DETAIL.PROPOSALS.STATUS.${proposal.status.toUpperCase()}`);

const load = async () => {
  try {
    const { data } = await TicketProposalsAPI.getProposals(props.ticketId);
    proposals.value = data;
  } catch (error) {
    useAlert(t('TICKET.DETAIL.PROPOSALS.LOAD_ERROR'));
  }
};

const onSaved = async () => {
  isFormOpen.value = false;
  await load();
};

const toggleVisibility = async (proposal, visible) => {
  busyId.value = proposal.id;
  try {
    await TicketProposalsAPI.updateProposal(props.ticketId, proposal.id, {
      visible_to_client: visible,
    });
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.DETAIL.PROPOSALS.SAVE_ERROR')
    );
  } finally {
    busyId.value = null;
    await load();
  }
};

const downloadPdf = async proposal => {
  busyId.value = proposal.id;
  try {
    const response = await TicketProposalsAPI.downloadPdf(
      props.ticketId,
      proposal.id
    );
    downloadBlob(
      response.data,
      `proposta-${props.ticketId}-${proposal.id}.pdf`,
      response.headers?.['content-disposition']
    );
  } catch (error) {
    useAlert(t('TICKET.DETAIL.PROPOSALS.PDF_ERROR'));
  } finally {
    busyId.value = null;
  }
};

const removeProposal = async proposal => {
  try {
    await TicketProposalsAPI.deleteProposal(props.ticketId, proposal.id);
    await load();
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.DETAIL.PROPOSALS.DELETE_ERROR')
    );
  }
};

onMounted(load);
watch(
  () => props.ticketId,
  () => {
    isFormOpen.value = false;
    load();
  }
);
</script>

<template>
  <section
    class="flex flex-col min-w-0 gap-3 p-4 border rounded-xl border-n-weak"
  >
    <div class="flex items-center justify-between">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.PROPOSALS.TITLE') }}
      </h2>
      <NextButton
        v-if="!isFormOpen"
        size="sm"
        icon="i-lucide-plus"
        :label="t('TICKET.DETAIL.PROPOSALS.BUTTON')"
        @click="isFormOpen = true"
      />
    </div>

    <TicketProposalForm
      v-if="isFormOpen"
      :ticket-id="ticketId"
      @saved="onSaved"
      @cancel="isFormOpen = false"
    />

    <p
      v-if="!proposals.length && !isFormOpen"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-file-text" class="flex-shrink-0 size-4" />
      {{ t('TICKET.DETAIL.PROPOSALS.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-2">
      <li
        v-for="proposal in proposals"
        :key="proposal.id"
        class="flex flex-col gap-2 px-3 py-3 rounded-lg bg-n-alpha-1 min-w-0"
      >
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ currency(proposal.amount) }}
          </span>
          <Label
            :label="statusLabel(proposal)"
            :color="STATUS_COLOR[proposal.status]"
            size="small"
          />
          <Label
            v-if="proposal.expired && proposal.status === 'pending'"
            :label="t('TICKET.DETAIL.PROPOSALS.EXPIRED')"
            color="ruby"
            size="small"
          />
          <span class="text-xs ltr:ml-auto rtl:mr-auto text-n-slate-10">
            {{ proposal.company_name }}
          </span>
        </div>

        <p class="m-0 text-xs whitespace-pre-line text-n-slate-11 line-clamp-3">
          {{ proposal.description }}
        </p>

        <span class="text-xs text-n-slate-10">
          {{
            t('TICKET.DETAIL.PROPOSALS.SUMMARY', {
              from: day(proposal.proposal_date),
              to: day(proposal.valid_until),
              days: proposal.deadline_days,
            })
          }}
        </span>

        <span
          v-if="proposal.decided_at"
          class="text-xs font-medium text-n-slate-11"
        >
          {{
            t('TICKET.DETAIL.PROPOSALS.DECIDED_BY', {
              name: proposal.decided_by_name || '—',
            })
          }}
        </span>

        <div class="flex flex-wrap items-center gap-3 pt-1">
          <label
            class="flex items-center gap-2 text-xs text-n-slate-11"
            :class="{ 'opacity-60': proposal.status !== 'pending' }"
          >
            <Switch
              :model-value="proposal.visible_to_client"
              :disabled="
                proposal.status !== 'pending' || busyId === proposal.id
              "
              @update:model-value="toggleVisibility(proposal, $event)"
            />
            {{ t('TICKET.DETAIL.PROPOSALS.SHOW_TO_CLIENT') }}
          </label>

          <NextButton
            size="xs"
            slate
            faded
            icon="i-lucide-download"
            class="ltr:ml-auto rtl:mr-auto"
            :label="t('TICKET.DETAIL.PROPOSALS.DOWNLOAD_PDF')"
            :is-loading="busyId === proposal.id"
            @click="downloadPdf(proposal)"
          />
          <button
            v-if="proposal.status === 'pending'"
            type="button"
            class="text-n-slate-9 hover:text-n-ruby-11"
            :aria-label="t('TICKET.DETAIL.PROPOSALS.DELETE')"
            @click="removeProposal(proposal)"
          >
            <Icon icon="i-lucide-trash-2" class="size-3.5" />
          </button>
        </div>
      </li>
    </ul>
  </section>
</template>
