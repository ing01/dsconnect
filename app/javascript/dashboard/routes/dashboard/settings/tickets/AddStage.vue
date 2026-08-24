<script>
import { useAlert } from 'dashboard/composables';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
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
  },
  emits: ['close'],
  data() {
    return {
      name: '',
      selectedTeamId: this.teamId,
      // Zero-based index; defaults to the end of the Mesa.
      position: this.stageCount,
      isSubmitting: false,
    };
  },
  computed: {
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
      if (this.isNameInvalid) return;

      this.isSubmitting = true;
      try {
        await this.$store.dispatch('ticketColumns/createColumn', {
          teamId: this.selectedTeamId,
          name: this.name.trim(),
          position: this.position,
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
          :disabled="isNameInvalid"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
