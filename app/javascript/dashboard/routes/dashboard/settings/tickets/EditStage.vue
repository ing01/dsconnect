<script>
import { useAlert } from 'dashboard/composables';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from './DurationInput.vue';
import {
  hoursMinutesToSeconds,
  secondsToHoursMinutes,
} from 'dashboard/helper/ticketSlaHelper';

export default {
  components: {
    NextButton,
    DurationInput,
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
  },
  emits: ['close'],
  data() {
    return {
      name: this.stage.name || '',
      selectedTeamId: this.stage.team_id,
      position: this.stage.position ?? 0,
      stageThreshold: secondsToHoursMinutes(this.stage.stage_threshold),
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
