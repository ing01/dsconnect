<script>
import { useAlert } from 'dashboard/composables';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from './DurationInput.vue';
import StageAutomationEditor from './StageAutomationEditor.vue';
import { hoursMinutesToSeconds } from 'dashboard/helper/ticketSlaHelper';

export default {
  components: {
    NextButton,
    DurationInput,
    StageAutomationEditor,
  },
  props: {
    teams: {
      type: Array,
      default: () => [],
    },
    teamId: {
      type: [Number, String],
      default: null,
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
      name: '',
      selectedTeamId: this.teamId,
      // Zero-based index; defaults to the end of the Mesa.
      position: this.stageCount,
      stageThreshold: '',
      kind: 'normal',
      hidden: false,
      automationsEnabled: true,
      automationActions: [],
      requireDueDate: false,
      requireScheduledAt: false,
      requireAppointment: false,
      requireAssignee: false,
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
    positionOptions() {
      return Array.from({ length: this.stageCount + 1 }, (_, index) => index);
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
        await this.$store.dispatch('ticketColumns/createColumn', {
          teamId: this.selectedTeamId,
          name: this.name.trim(),
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
    <woot-modal-header :header-title="$t('TICKET.COLUMN_FORM.ADD_TITLE')" />
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
        <select v-model="selectedTeamId">
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ formatMesaName(team.name) }}
          </option>
        </select>
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
        <select v-model="kind">
          <option value="normal">
            {{ $t('TICKET.SETTINGS.FORM.KIND.NORMAL') }}
          </option>
          <option value="pending">
            {{ $t('TICKET.SETTINGS.FORM.KIND.PENDING') }}
          </option>
          <option value="completed">
            {{ $t('TICKET.SETTINGS.FORM.KIND.COMPLETED') }}
          </option>
          <option value="in_progress">
            {{ $t('TICKET.SETTINGS.FORM.KIND.IN_PROGRESS') }}
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
          :teams="teams"
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
