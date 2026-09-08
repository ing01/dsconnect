<script setup>
import { computed, ref, watch } from 'vue';
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
// O prazo tambem pode ser dito por extenso, e nao so por quantas horas somar.
// Sao duas formas de dizer a mesma coisa, entao uma exclui a outra.
const MODE_HOURS = 'hours';
const MODE_DUE_AT = 'due_at';
const mode = ref(MODE_HOURS);
const dueAtInput = ref('');
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

// A data escolhida pode ser anterior a atual: corrigir um prazo lancado errado
// e tao legitimo quanto conceder folga. O que nao vale e nao mexer em nada.
const isFilled = computed(() =>
  mode.value === MODE_HOURS
    ? Number.isFinite(parsedHours.value) && parsedHours.value > 0
    : !!dueAtInput.value && !Number.isNaN(Date.parse(dueAtInput.value))
);

const isValid = computed(
  () => isFilled.value && reason.value.trim().length > 0 && !!selectedSla.value
);

const extensions = computed(() => props.ticket.sla_extensions || []);

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '-';

// O input datetime-local fala no fuso de quem esta olhando, sem sufixo. A ida e
// a volta ficam aqui para o resto do arquivo so lidar com o que ve na tela.
const toLocalInput = timestamp => {
  if (!timestamp) return '';

  const date = new Date(timestamp * 1000);
  const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return shifted.toISOString().slice(0, 16);
};

// O prazo mostrado e o do relogio escolhido: cada um tem o seu.
const dueAt = computed(() => formatDate(selectedSla.value?.due_at));

const open = () => {
  hours.value = '';
  mode.value = MODE_HOURS;
  dueAtInput.value = '';
  reason.value = '';
  // Um unico relogio disponivel dispensa a escolha; com mais de um, ela e
  // obrigatoria.
  slaKind.value =
    kindOptions.value.length === 1 ? kindOptions.value[0].value : '';
  dialogRef.value?.open();
};

// Trocar para o modo data parte do prazo que o relogio tem hoje: quase todo
// ajuste e um deslocamento pequeno, e digitar a data inteira do zero seria
// trabalho a toa.
watch([mode, slaKind], () => {
  if (mode.value !== MODE_DUE_AT) return;
  dueAtInput.value = toLocalInput(selectedSla.value?.due_at);
});

const handleConfirm = () => {
  if (!isValid.value) return;

  emit('submit', {
    // Uma das duas, nunca as duas: o servidor decide pelo que chegar preenchido.
    hours: mode.value === MODE_HOURS ? parsedHours.value : undefined,
    dueAt:
      mode.value === MODE_DUE_AT
        ? new Date(dueAtInput.value).toISOString()
        : undefined,
    reason: reason.value.trim(),
    slaKind: slaKind.value,
  });
  hours.value = '';
  dueAtInput.value = '';
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

      <fieldset class="flex flex-col gap-1.5 p-0 m-0 border-0 min-w-0">
        <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.SLA_DIALOG.MODE') }}
        </legend>
        <div class="flex flex-wrap gap-4">
          <label class="flex items-center gap-2 text-sm text-n-slate-11">
            <input
              v-model="mode"
              type="radio"
              :value="MODE_HOURS"
              class="m-0"
            />
            {{ t('TICKET.ACTIONS.SLA_DIALOG.MODE_HOURS') }}
          </label>
          <label class="flex items-center gap-2 text-sm text-n-slate-11">
            <input
              v-model="mode"
              type="radio"
              :value="MODE_DUE_AT"
              class="m-0"
            />
            {{ t('TICKET.ACTIONS.SLA_DIALOG.MODE_DUE_AT') }}
          </label>
        </div>
      </fieldset>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 min-w-0">
        <label v-if="mode === MODE_HOURS" class="flex flex-col gap-1 min-w-0">
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

        <!-- Sem `min`: uma data anterior a atual e um ajuste valido, e nao um
             engano a impedir. -->
        <label v-else class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.ACTIONS.SLA_DIALOG.NEW_DUE') }}
            <span class="text-n-ruby-11">*</span>
          </span>
          <input
            v-model="dueAtInput"
            type="datetime-local"
            class="w-full mb-0"
            :disabled="!selectedSla"
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
