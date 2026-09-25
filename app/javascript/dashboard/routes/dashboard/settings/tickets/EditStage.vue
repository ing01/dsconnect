<script>
import { useAlert } from 'dashboard/composables';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from './DurationInput.vue';
import StageAutomationEditor from './StageAutomationEditor.vue';
import {
  hoursMinutesToSeconds,
  secondsToHoursMinutes,
} from 'dashboard/helper/ticketSlaHelper';

export default {
  components: {
    NextButton,
    DurationInput,
    StageAutomationEditor,
  },
  props: {
    stage: {
      type: Object,
      required: true,
    },
    teams: {
      type: Array,
      default: () => [],
    },
    stageCount: {
      type: Number,
      default: 0,
    },
    agents: {
      type: Array,
      default: () => [],
    },
  },
  emits: ['close'],
  data() {
    return {
      name: this.stage.name || '',
      selectedTeamId: this.stage.team_id,
      position: this.stage.position ?? 0,
      stageThreshold: secondsToHoursMinutes(this.stage.stage_threshold),
      kind: this.stage.kind || 'normal',
      hidden: !!this.stage.hidden,
      automationsEnabled: this.stage.automations_enabled ?? true,
      automationActions: this.stage.automation_actions
        ? this.stage.automation_actions.map(action => ({ ...action }))
        : [],
      requireDueDate: !!this.stage.require_due_date,
      requireScheduledAt: !!this.stage.require_scheduled_at,
      requireAppointment: !!this.stage.require_appointment,
      requireAssignee: !!this.stage.require_assignee,
      isSubmitting: false,
    };
  },
  computed: {
    // Vazio e valido: quer dizer que o Estagio nao tem prazo.
    isThresholdInvalid() {
      return (
        !!this.stageThreshold.trim() &&
        hoursMinutesToSeconds(this.stageThreshold) === null
      );
    },
    ticketCount() {
      return this.stage.tickets?.length ?? 0;
    },
    // A ticket must always sit in a column belonging to its own Mesa, so an
    // Estagio holding tickets can't change hands. The backend enforces this too -
    // disabling the field here just avoids a guaranteed round-trip failure.
    isMesaLocked() {
      return this.ticketCount > 0;
    },
    // Pendente/Finalizado are mandatory once assigned (TicketColumn#ensure_not_required_kind
    // blocks deleting them) - the type is fixed here so an admin cannot quietly
    // strip the Mesa of its only Pendente/Finalizado stage by editing it away.
    isKindLocked() {
      return (this.stage.kind || 'normal') !== 'normal';
    },
    positionOptions() {
      return Array.from({ length: this.stageCount }, (_, index) => index);
    },
    isNameInvalid() {
      return !this.name.trim();
    },
  },
  methods: {
    formatMesaName,
    async submit() {
      if (this.isNameInvalid || this.isThresholdInvalid) return;

      this.isSubmitting = true;
      try {
        await this.$store.dispatch('ticketColumns/updateColumn', {
          teamId: this.stage.team_id,
          columnId: this.stage.id,
          name: this.name.trim(),
          team_id: this.selectedTeamId,
          position: this.position,
          stage_threshold: hoursMinutesToSeconds(this.stageThreshold),
          kind: this.kind,
          hidden: this.hidden,
          automations_enabled: this.automationsEnabled,
          automation_actions: this.automationActions,
          require_due_date: this.requireDueDate,
          require_scheduled_at: this.requireScheduledAt,
          require_appointment: this.requireAppointment,
          require_assignee: this.requireAssignee,
        });
        useAlert(this.$t('TICKET.API.COLUMN_SUCCESS'));
        this.$emit('close');
      } catch (error) {
        useAlert(
          parseAPIErrorResponse(error) || this.$t('TICKET.API.COLUMN_ERROR')
        );
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="$t('TICKET.COLUMN_FORM.EDIT_TITLE')" />
    <form class="flex flex-col w-full gap-4 p-8" @submit.prevent="submit">
      <woot-input
        v-model="name"
        :label="$t('TICKET.COLUMN_FORM.NAME.LABEL')"
        :placeholder="$t('TICKET.COLUMN_FORM.NAME.PLACEHOLDER')"
        :class="{ error: isNameInvalid }"
        :error="
          isNameInvalid ? $t('TICKET.COLUMN_FORM.NAME.REQUIRED_ERROR') : ''
        "
      />

      <label>
        {{ $t('TICKET.SETTINGS.FORM.MESA.LABEL') }}
        <select v-model="selectedTeamId" :disabled="isMesaLocked">
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ formatMesaName(team.name) }}
          </option>
        </select>
        <p v-if="isMesaLocked" class="text-sm text-n-slate-11">
          {{
            $t('TICKET.SETTINGS.FORM.MESA.LOCKED_HINT', { count: ticketCount })
          }}
        </p>
      </label>

      <label>
        {{ $t('TICKET.SETTINGS.FORM.ORDER.LABEL') }}
        <select v-model.number="position">
          <option v-for="index in positionOptions" :key="index" :value="index">
            {{ index + 1 }}
          </option>
        </select>
        <p class="text-sm text-n-slate-11">
          {{ $t('TICKET.SETTINGS.FORM.ORDER.HINT') }}
        </p>
      </label>

      <!-- O prazo do Estagio mora junto do Estagio porque varia por coluna, nao
           por prioridade. Vazio significa "esta coluna nao tem prazo". -->
      <label>
        {{ $t('TICKET.SETTINGS.FORM.STAGE_SLA.LABEL') }}
        <DurationInput
          v-model="stageThreshold"
          :invalid="isThresholdInvalid"
          :aria-label="$t('TICKET.SETTINGS.FORM.STAGE_SLA.LABEL')"
        />
        <p
          class="text-sm"
          :class="isThresholdInvalid ? 'text-n-ruby-11' : 'text-n-slate-11'"
        >
          {{
            isThresholdInvalid
              ? $t('TICKET.SETTINGS.FORM.STAGE_SLA.INVALID')
              : $t('TICKET.SETTINGS.FORM.STAGE_SLA.HINT')
          }}
        </p>
      </label>

      <label>
        {{ $t('TICKET.SETTINGS.FORM.KIND.LABEL') }}
        <select v-model="kind" :disabled="isKindLocked">
          <option value="normal">
            {{ $t('TICKET.SETTINGS.FORM.KIND.NORMAL') }}
          </option>
          <option value="pending">
            {{ $t('TICKET.SETTINGS.FORM.KIND.PENDING') }}
          </option>
          <option value="completed">
            {{ $t('TICKET.SETTINGS.FORM.KIND.COMPLETED') }}
          </option>
        </select>
        <p class="text-sm text-n-slate-11">
          {{ $t('TICKET.SETTINGS.FORM.KIND.HINT') }}
        </p>
      </label>

      <label class="flex items-center gap-2">
        <input v-model="hidden" type="checkbox" />
        {{ $t('TICKET.SETTINGS.FORM.HIDDEN.LABEL') }}
      </label>
      <p class="-mt-3 text-sm text-n-slate-11">
        {{ $t('TICKET.SETTINGS.FORM.HIDDEN.HINT') }}
      </p>

      <fieldset class="flex flex-col gap-2">
        <legend class="text-sm">
          {{ $t('TICKET.SETTINGS.FORM.AUTOMATION.LABEL') }}
        </legend>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('TICKET.SETTINGS.FORM.AUTOMATION.HELP') }}
        </p>
        <label class="flex items-center gap-2">
          <input v-model="automationsEnabled" type="checkbox" />
          {{ $t('TICKET.SETTINGS.FORM.AUTOMATION.ENABLED') }}
        </label>
        <StageAutomationEditor
          v-if="automationsEnabled"
          v-model="automationActions"
          :agents="agents"
        />
      </fieldset>

      <fieldset class="flex flex-col gap-2">
        <legend class="text-sm">
          {{ $t('TICKET.SETTINGS.FORM.RULES.LABEL') }}
        </legend>
        <label class="flex items-center gap-2">
          <input v-model="requireDueDate" type="checkbox" />
          {{ $t('TICKET.SETTINGS.FORM.RULES.REQUIRE_DUE_DATE') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="requireScheduledAt" type="checkbox" />
          {{ $t('TICKET.SETTINGS.FORM.RULES.REQUIRE_SCHEDULED_AT') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="requireAppointment" type="checkbox" />
          {{ $t('TICKET.SETTINGS.FORM.RULES.REQUIRE_APPOINTMENT') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="requireAssignee" type="checkbox" />
          {{ $t('TICKET.SETTINGS.FORM.RULES.REQUIRE_ASSIGNEE') }}
        </label>
      </fieldset>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('TICKET.COLUMN_FORM.CANCEL')"
          @click.prevent="$emit('close')"
        />
        <NextButton
          type="submit"
          :label="$t('TICKET.COLUMN_FORM.SUBMIT')"
          :disabled="isNameInvalid || isThresholdInvalid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
