<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import QueueInactivityFields from './QueueInactivityFields.vue';

export default {
  components: {
    NextButton,
    QueueInactivityFields,
  },
  emits: ['close'],
  data() {
    return {
      name: '',
      description: '',
      teamId: null,
      distributionStrategy: 'manual',
      priorityBoost: null,
      defaultSlaPolicyId: null,
      active: true,
      inactivity: {
        nudgeAfter: null,
        nudgeMessage: '',
        closeAfter: null,
        closeMessage: '',
      },
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'queues/getUIFlags',
      teams: 'teams/getTeams',
      slaPolicies: 'sla/getSLA',
    }),
    isInactivityInvalid() {
      const { nudgeAfter, nudgeMessage, closeAfter, closeMessage } =
        this.inactivity;
      return (
        (nudgeAfter !== null && !nudgeMessage.trim()) ||
        (closeAfter !== null && !closeMessage.trim())
      );
    },
    isNameEmpty() {
      return !this.name.trim();
    },
  },
  mounted() {
    this.$store.dispatch('teams/get');
    this.$store.dispatch('sla/get');
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    async addQueue() {
      if (this.isNameEmpty || !this.teamId) return;
      try {
        await this.$store.dispatch('queues/create', {
          name: this.name,
          description: this.description,
          team_id: this.teamId,
          distribution_strategy: this.distributionStrategy,
          priority_boost: this.priorityBoost,
          default_sla_policy_id: this.defaultSlaPolicyId,
          active: this.active,
          inactivity_nudge_after: this.inactivity.nudgeAfter,
          inactivity_nudge_message:
            this.inactivity.nudgeAfter === null
              ? null
              : this.inactivity.nudgeMessage,
          inactivity_close_after: this.inactivity.closeAfter,
          inactivity_close_message:
            this.inactivity.closeAfter === null
              ? null
              : this.inactivity.closeMessage,
        });
        useAlert(this.$t('QUEUES_SETTINGS.ADD.API.SUCCESS_MESSAGE'));
        this.onClose();
      } catch (error) {
        const errorMessage =
          error.message || this.$t('QUEUES_SETTINGS.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('QUEUES_SETTINGS.ADD.TITLE')"
      :header-content="$t('QUEUES_SETTINGS.ADD.DESC')"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="addQueue">
      <woot-input
        v-model="name"
        class="w-full"
        :label="$t('QUEUES_SETTINGS.FORM.NAME.LABEL')"
        :placeholder="$t('QUEUES_SETTINGS.FORM.NAME.PLACEHOLDER')"
      />

      <woot-input
        v-model="description"
        class="w-full"
        :label="$t('QUEUES_SETTINGS.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('QUEUES_SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
      />

      <div class="w-full">
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.TEAM.LABEL') }}
          <select v-model="teamId">
            <option :value="null" disabled>
              {{ $t('QUEUES_SETTINGS.FORM.TEAM.PLACEHOLDER') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.DISTRIBUTION.LABEL') }}
          <select v-model="distributionStrategy">
            <option value="manual">
              {{ $t('QUEUES_SETTINGS.FORM.DISTRIBUTION.OPTIONS.MANUAL') }}
            </option>
            <option value="round_robin">
              {{ $t('QUEUES_SETTINGS.FORM.DISTRIBUTION.OPTIONS.ROUND_ROBIN') }}
            </option>
            <option value="least_busy">
              {{ $t('QUEUES_SETTINGS.FORM.DISTRIBUTION.OPTIONS.LEAST_BUSY') }}
            </option>
          </select>
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.SLA.LABEL') }}
          <select v-model="defaultSlaPolicyId">
            <option :value="null">
              {{ $t('QUEUES_SETTINGS.FORM.SLA.NONE') }}
            </option>
            <option v-for="sla in slaPolicies" :key="sla.id" :value="sla.id">
              {{ sla.name }}
            </option>
          </select>
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.PRIORITY_BOOST.LABEL') }}
          <select v-model="priorityBoost">
            <option :value="null">
              {{ $t('QUEUES_SETTINGS.FORM.PRIORITY_BOOST.NONE') }}
            </option>
            <option :value="0">
              {{ $t('QUEUES_SETTINGS.FORM.PRIORITY_BOOST.LOW') }}
            </option>
            <option :value="1">
              {{ $t('QUEUES_SETTINGS.FORM.PRIORITY_BOOST.MEDIUM') }}
            </option>
            <option :value="2">
              {{ $t('QUEUES_SETTINGS.FORM.PRIORITY_BOOST.HIGH') }}
            </option>
            <option :value="3">
              {{ $t('QUEUES_SETTINGS.FORM.PRIORITY_BOOST.URGENT') }}
            </option>
          </select>
        </label>
      </div>

      <QueueInactivityFields v-model="inactivity" />

      <div class="flex items-center w-full gap-2">
        <input v-model="active" type="checkbox" :value="true" />
        <label for="queue_active">
          {{ $t('QUEUES_SETTINGS.FORM.ACTIVE.LABEL') }}
        </label>
      </div>

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('QUEUES_SETTINGS.FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :label="$t('QUEUES_SETTINGS.FORM.CREATE')"
          :disabled="
            isNameEmpty || isInactivityInvalid || !teamId || uiFlags.isCreating
          "
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
