<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import TicketProposalsAPI from 'dashboard/api/ticketProposals';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketPicker from './actions/TicketPicker.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
});

const emit = defineEmits(['saved', 'cancel']);

const { t } = useI18n();

const INPUT_CLASS =
  'h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none';
const TEXTAREA_CLASS =
  'px-2.5 py-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none';

const form = reactive({
  company_name: '',
  company_cnpj: '',
  company_address: '',
  summary: '',
  proposal_date: '',
  valid_until: '',
  location: '',
  payment_terms: '',
  deadline_days: '',
  signer_name: '',
});
const items = ref([{ title: '', description: '', amount: '' }]);
const isSubmitting = ref(false);

// Outros tickets a que a proposta tambem vale. So' os da mesma empresa sao
// oferecidos: a proposta aparece no portal de quem enxerga qualquer um deles.
const companyId = ref(null);
const linkedTickets = ref([]);
const pickerValue = ref(null);

const itemTitleFor = ticket => `${ticket.display_id} - ${ticket.title}`;

// Vincular um ticket ja' abre o item dele, como no modelo comercial (um item
// por ticket); o agente so' completa descricao e valor.
const linkTicket = ticket => {
  // No proximo ciclo: o seletor so' esvazia o rotulo quando ve o valor mudar, e
  // no mesmo ciclo ele nunca chega a ver o ticket escolhido.
  nextTick(() => {
    pickerValue.value = null;
  });
  if (linkedTickets.value.some(linked => linked.id === ticket.id)) return;

  linkedTickets.value.push(ticket);
  items.value.push({
    title: itemTitleFor(ticket),
    description: '',
    amount: '',
  });
};

// Desvincular tira o item que ele abriu, mas so' se ninguem mexeu nele - um
// item ja preenchido nao some por um clique.
const unlinkTicket = ticket => {
  linkedTickets.value = linkedTickets.value.filter(
    linked => linked.id !== ticket.id
  );
  items.value = items.value.filter(
    item =>
      item.title !== itemTitleFor(ticket) || item.description || item.amount
  );
};

const total = computed(() =>
  items.value.reduce((sum, item) => sum + (Number(item.amount) || 0), 0)
);

const currency = value =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    value
  );

const addItem = () =>
  items.value.push({ title: '', description: '', amount: '' });

const removeItem = index => items.value.splice(index, 1);

onMounted(async () => {
  try {
    const { data } = await TicketProposalsAPI.getDefaults(props.ticketId);
    Object.keys(form).forEach(key => {
      if (data[key] !== undefined && data[key] !== null) form[key] = data[key];
    });
    if (data.items?.length) items.value = data.items;
    companyId.value = data.company_id;
  } catch (error) {
    useAlert(t('TICKET.DETAIL.PROPOSALS.DEFAULTS_ERROR'));
  }
});

const submit = async () => {
  if (isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await TicketProposalsAPI.createProposal(props.ticketId, {
      ...form,
      items: items.value,
      linked_ticket_ids: linkedTickets.value.map(ticket => ticket.id),
    });
    emit('saved');
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.DETAIL.PROPOSALS.SAVE_ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <form
    class="grid grid-cols-1 gap-3 p-4 border rounded-xl sm:grid-cols-2 border-n-weak"
    @submit.prevent="submit"
  >
    <h3 class="text-sm font-medium sm:col-span-2 text-n-slate-12">
      {{ t('TICKET.DETAIL.PROPOSALS.FORM_TITLE') }}
    </h3>

    <label class="flex flex-col gap-1 text-xs text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.COMPANY_NAME') }}
      <input v-model="form.company_name" required :class="INPUT_CLASS" />
    </label>
    <label class="flex flex-col gap-1 text-xs text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.COMPANY_CNPJ') }}
      <input v-model="form.company_cnpj" :class="INPUT_CLASS" />
    </label>
    <label class="flex flex-col gap-1 text-xs sm:col-span-2 text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.COMPANY_ADDRESS') }}
      <input v-model="form.company_address" :class="INPUT_CLASS" />
    </label>

    <!-- A mesma proposta para mais de um ticket: ela aparece na aba Valorizacao
         de todos os vinculados. -->
    <div class="flex flex-col gap-2 sm:col-span-2">
      <span class="text-xs text-n-slate-11">
        {{ t('TICKET.DETAIL.PROPOSALS.LINK_TICKETS') }}
      </span>
      <TicketPicker
        v-model="pickerValue"
        :placeholder="t('TICKET.DETAIL.PROPOSALS.LINK_PLACEHOLDER')"
        :exclude-id="ticketId"
        :exclude-ids="linkedTickets.map(ticket => ticket.id)"
        :company-id="companyId"
        @select="linkTicket"
      />
      <ul v-if="linkedTickets.length" class="flex flex-wrap gap-1.5 m-0">
        <li
          v-for="linked in linkedTickets"
          :key="linked.id"
          class="flex items-center gap-1.5 px-2 py-1 text-xs list-none rounded-md bg-n-alpha-2 text-n-slate-12"
        >
          <span class="truncate max-w-64">
            #{{ linked.display_id }} - {{ linked.title }}
          </span>
          <button
            type="button"
            class="text-n-slate-10 hover:text-n-ruby-11"
            :aria-label="t('TICKET.DETAIL.PROPOSALS.UNLINK_TICKET')"
            @click="unlinkTicket(linked)"
          >
            <Icon icon="i-lucide-x" class="size-3" />
          </button>
        </li>
      </ul>
    </div>

    <label class="flex flex-col gap-1 text-xs sm:col-span-2 text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.SUMMARY') }}
      <input v-model="form.summary" required :class="INPUT_CLASS" />
    </label>

    <!-- Os itens da proposta (REQUISITOS no PDF): cada um com titulo, descricao
         e valor. O total e' a soma, e o servidor o recalcula. -->
    <div class="flex flex-col gap-2 sm:col-span-2">
      <span class="text-xs font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.PROPOSALS.ITEMS_TITLE') }}
      </span>
      <div
        v-for="(item, index) in items"
        :key="index"
        class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET.DETAIL.PROPOSALS.ITEM_LABEL', { number: index + 1 }) }}
          </span>
          <button
            v-if="items.length > 1"
            type="button"
            class="text-xs text-n-slate-10 hover:text-n-ruby-11"
            @click="removeItem(index)"
          >
            {{ t('TICKET.DETAIL.PROPOSALS.REMOVE_ITEM') }}
          </button>
        </div>
        <input
          v-model="item.title"
          required
          :class="INPUT_CLASS"
          :placeholder="t('TICKET.DETAIL.PROPOSALS.FIELDS.ITEM_TITLE')"
        />
        <textarea
          v-model="item.description"
          rows="4"
          :class="TEXTAREA_CLASS"
          :placeholder="t('TICKET.DETAIL.PROPOSALS.FIELDS.ITEM_DESCRIPTION')"
        />
        <input
          v-model="item.amount"
          required
          type="number"
          min="0.01"
          step="0.01"
          :class="INPUT_CLASS"
          :placeholder="t('TICKET.DETAIL.PROPOSALS.FIELDS.ITEM_AMOUNT')"
        />
      </div>
      <div class="flex items-center justify-between gap-2">
        <NextButton
          size="xs"
          slate
          faded
          type="button"
          icon="i-lucide-plus"
          :label="t('TICKET.DETAIL.PROPOSALS.ADD_ITEM')"
          @click="addItem"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.DETAIL.PROPOSALS.TOTAL') }}: {{ currency(total) }}
        </span>
      </div>
    </div>

    <label class="flex flex-col gap-1 text-xs text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.DEADLINE_DAYS') }}
      <input
        v-model="form.deadline_days"
        required
        type="number"
        min="1"
        step="1"
        :class="INPUT_CLASS"
      />
    </label>
    <label class="flex flex-col gap-1 text-xs text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.LOCATION') }}
      <input v-model="form.location" required :class="INPUT_CLASS" />
    </label>

    <label class="flex flex-col gap-1 text-xs text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.PROPOSAL_DATE') }}
      <input
        v-model="form.proposal_date"
        required
        type="date"
        :class="INPUT_CLASS"
      />
    </label>
    <label class="flex flex-col gap-1 text-xs text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.VALID_UNTIL') }}
      <input
        v-model="form.valid_until"
        required
        type="date"
        :min="form.proposal_date"
        :class="INPUT_CLASS"
      />
    </label>

    <label class="flex flex-col gap-1 text-xs sm:col-span-2 text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.SIGNER_NAME') }}
      <input v-model="form.signer_name" :class="INPUT_CLASS" />
    </label>

    <label class="flex flex-col gap-1 text-xs sm:col-span-2 text-n-slate-11">
      {{ t('TICKET.DETAIL.PROPOSALS.FIELDS.PAYMENT_TERMS') }}
      <textarea
        v-model="form.payment_terms"
        required
        rows="2"
        :class="TEXTAREA_CLASS"
      />
    </label>

    <div class="flex justify-end gap-2 sm:col-span-2">
      <NextButton
        size="sm"
        slate
        faded
        type="button"
        :label="t('TICKET.DETAIL.PROPOSALS.CANCEL')"
        @click="emit('cancel')"
      />
      <NextButton
        size="sm"
        type="submit"
        icon="i-lucide-file-text"
        :label="t('TICKET.DETAIL.PROPOSALS.SAVE')"
        :is-loading="isSubmitting"
      />
    </div>
  </form>
</template>
