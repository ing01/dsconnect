<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketSelect from '../../TicketSelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const hours = ref('');
const reason = ref('');
// Qual dos tres prazos estender. Sem valor padrao de proposito: horas nunca sao
// aplicadas indiscriminadamente aos tres relogios, entao a escolha e explicita.
const slaKind = ref('');

// Filled from the session and read-only: an extension is attributed to whoever
// granted it, and the server ignores any attendant sent by the client anyway.
const currentUser = useMapGetter('getCurrentUser');

// Decimals are accepted because half-hour extensions are ordinary; the model
// caps the value and rejects anything at or below zero.
const parsedHours = computed(() => Number.parseFloat(hours.value));
// So os relogios que o ticket realmente tem entram no seletor: uma Mesa que nao
// promete atendimento nao tem prazo de atendimento para esticar.
const kindOptions = computed(() =>
  (props.ticket.slas || []).map(sla => ({
    value: sla.kind,
    label: t(`TICKET.ACTIONS.SLA_DIALOG.KINDS.${sla.kind.toUpperCase()}`),
  }))
);

const selectedSla = computed(() =>
  (props.ticket.slas || []).find(sla => sla.kind === slaKind.value)
);

const isValid = computed(
  () =>
    Number.isFinite(parsedHours.value) &&
    parsedHours.value > 0 &&
    reason.value.trim().length > 0 &&
    !!selectedSla.value
);

const extensions = computed(() => props.ticket.sla_extensions || []);

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '-';

// O prazo mostrado e o do relogio escolhido: cada um tem o seu.
const dueAt = computed(() => formatDate(selectedSla.value?.due_at));

const open = () => {
  hours.value = '';
  reason.value = '';
  // Um unico relogio disponivel dispensa a escolha; com mais de um, ela e
  // obrigatoria.
  slaKind.value =
    kindOptions.value.length === 1 ? kindOptions.value[0].value : '';
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!isValid.value) return;
  emit('submit', {
    hours: parsedHours.value,
    reason: reason.value.trim(),
    slaKind: slaKind.value,
  });
  hours.value = '';
  reason.value = '';
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('TICKET.ACTIONS.SLA_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.SLA_DIALOG.CONFIRM')"
    :disable-confirm-button="!isValid"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.SLA_DIALOG.KIND') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <TicketSelect
          v-model="slaKind"
          :options="kindOptions"
          :disabled="!kindOptions.length"
          :placeholder="t('TICKET.ACTIONS.SLA_DIALOG.KIND_PLACEHOLDER')"
          :aria-label="t('TICKET.ACTIONS.SLA_DIALOG.KIND')"
        />
        <span v-if="!kindOptions.length" class="text-sm text-n-slate-10">
          {{ t('TICKET.ACTIONS.SLA_DIALOG.NO_CLOCK') }}
        </span>
      </label>

      <p class="flex items-center gap-2 text-sm text-n-slate-11">
        <Icon icon="i-lucide-clock" class="flex-shrink-0 size-4" />
        {{ t('TICKET.ACTIONS.SLA_DIALOG.CURRENT_DUE') }}:
        <span class="font-medium text-n-slate-12">
          {{ selectedSla ? dueAt : t('TICKET.ACTIONS.SLA_DIALOG.NO_DUE') }}
        </span>
      </p>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 min-w-0">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.ACTIONS.SLA_DIALOG.HOURS') }}
            <span class="text-n-ruby-11">*</span>
          </span>
          <input
            v-model="hours"
            type="number"
            min="0.25"
            step="0.25"
            class="w-full mb-0"
            :placeholder="t('TICKET.ACTIONS.SLA_DIALOG.HOURS')"
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.ACTIONS.SLA_DIALOG.AGENT') }}
          </span>
          <input
            :value="currentUser.name"
            type="text"
            disabled
            class="w-full mb-0"
          />
        </label>
      </div>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.SLA_DIALOG.REASON') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <textarea
          v-model="reason"
          rows="3"
          class="w-full mb-0"
          :placeholder="t('TICKET.ACTIONS.SLA_DIALOG.REASON_PLACEHOLDER')"
        />
      </label>

      <div class="flex flex-col gap-2 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.SLA_DIALOG.HISTORY') }}
        </span>

        <p v-if="!extensions.length" class="text-sm text-n-slate-10">
          {{ t('TICKET.ACTIONS.SLA_DIALOG.NO_HISTORY') }}
        </p>

        <!-- Scrolls inside its own container so a long history never makes the
             page itself scroll sideways on a phone. -->
        <div v-else class="overflow-x-auto max-h-56 overflow-y-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-n-slate-10">
                <th class="py-1 pr-3 font-medium">
                  {{ t('TICKET.ACTIONS.SLA_DIALOG.HOURS') }}
                </th>
                <th class="py-1 pr-3 font-medium">
                  {{ t('TICKET.ACTIONS.SLA_DIALOG.REASON') }}
                </th>
                <th class="py-1 pr-3 font-medium">
                  {{ t('TICKET.ACTIONS.SLA_DIALOG.AGENT') }}
                </th>
                <th class="py-1 font-medium">
                  {{ t('TICKET.ACTIONS.SLA_DIALOG.NEW_DUE') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="extension in extensions"
                :key="extension.id"
                class="border-t border-n-weak align-top"
              >
                <td class="py-1.5 pr-3 whitespace-nowrap text-n-slate-12">
                  {{
                    t('TICKET.DETAIL.SLA.HOURS_COUNT', {
                      hours: extension.hours,
                    })
                  }}
                </td>
                <td class="py-1.5 pr-3 text-n-slate-11">
                  {{ extension.reason }}
                </td>
                <td class="py-1.5 pr-3 whitespace-nowrap text-n-slate-11">
                  {{ extension.user_name || '-' }}
                </td>
                <td class="py-1.5 whitespace-nowrap text-n-slate-11">
                  {{ formatDate(extension.new_due_at) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </Dialog>
</template>
