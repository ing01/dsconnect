<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import ContactDetailsItem from './ContactDetailsItem.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ConversationLabels from './labels/LabelBox.vue';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    ContactDetailsItem,
    MultiselectDropdown,
    ConversationLabels,
    NextButton,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList(true, { includeAgentBots: true });
    return {
      agentsList,
    };
  },
  data() {
    return {
      priorityOptions: [
        {
          id: null,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
          icon: 'i-woot-priority-empty',
        },
        {
          id: CONVERSATION_PRIORITY.URGENT,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
          icon: 'i-woot-priority-urgent',
        },
        {
          id: CONVERSATION_PRIORITY.HIGH,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
          icon: 'i-woot-priority-high',
        },
        {
          id: CONVERSATION_PRIORITY.MEDIUM,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
          icon: 'i-woot-priority-medium',
        },
        {
          id: CONVERSATION_PRIORITY.LOW,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
          icon: 'i-woot-priority-low',
        },
      ],
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      currentUserRole: 'getCurrentRole',
      currentUserEnforceQueueOrder: 'getCurrentUserEnforceQueueOrder',
      teams: 'teams/getTeams',
      queues: 'queues/getQueues',
    }),
    hasAnAssignedTeam() {
      return !!this.currentChat?.meta?.team;
    },
    teamsList() {
      if (this.hasAnAssignedTeam) {
        return [
          { id: 0, name: this.$t('TEAMS_SETTINGS.LIST.NONE') },
          ...this.teams,
        ];
      }
      return this.teams;
    },
    hasAnAssignedQueue() {
      return !!this.currentChat?.meta?.queue;
    },
    queuesForCurrentTeam() {
      const teamId = this.currentChat?.meta?.team?.id;
      const activeQueues = this.queues.filter(queue => queue.active);
      return teamId
        ? activeQueues.filter(queue => queue.team_id === teamId)
        : activeQueues;
    },
    queuesList() {
      if (this.hasAnAssignedQueue) {
        return [
          { id: 0, name: this.$t('CONVERSATION_SIDEBAR.QUEUE_NONE') },
          ...this.queuesForCurrentTeam,
        ];
      }
      return this.queuesForCurrentTeam;
    },
    assignedAgent: {
      get() {
        const assignee = this.currentChat.meta.assignee;
        return (
          assignee && {
            ...assignee,
            assignee_type: this.currentChat.meta.assignee_type || 'User',
          }
        );
      },
      set(agent) {
        const agentId = agent ? agent.id : null;
        const assigneeType = agent ? agent.assignee_type || 'User' : null;
        this.$store.dispatch('setCurrentChatAssignee', {
          conversationId: this.currentChat.id,
          assignee: agent,
          assigneeType,
        });
        this.$store
          .dispatch('assignAgent', {
            conversationId: this.currentChat.id,
            agentId,
            assigneeType,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_AGENT'));
          });
      },
    },
    assignedTeam: {
      get() {
        return this.currentChat.meta.team;
      },
      set(team) {
        const conversationId = this.currentChat.id;
        const teamId = team ? team.id : 0;
        this.$store.dispatch('setCurrentChatTeam', { team, conversationId });
        this.$store
          .dispatch('assignTeam', { conversationId, teamId })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_TEAM'));
          });
      },
    },
    assignedQueue: {
      get() {
        return this.currentChat.meta.queue;
      },
      set(queue) {
        const conversationId = this.currentChat.id;
        const queueId = queue ? queue.id : 0;
        this.$store.dispatch('setCurrentChatQueue', { queue, conversationId });
        this.$store
          .dispatch('assignQueue', { conversationId, queueId })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_QUEUE'));
          });
      },
    },
    assignedPriority: {
      get() {
        const selectedOption = this.priorityOptions.find(
          opt => opt.id === this.currentChat.priority
        );

        return selectedOption || this.priorityOptions[0];
      },
      set(priorityItem) {
        const conversationId = this.currentChat.id;
        const oldValue = this.currentChat?.priority;
        const priority = priorityItem.id;

        this.$store.dispatch('setCurrentChatPriority', {
          priority,
          conversationId,
        });
        this.$store
          .dispatch('assignPriority', { conversationId, priority })
          .then(() => {
            useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
              oldValue,
              newValue: priority,
              from: 'Conversation Sidebar',
            });
            useAlert(
              this.$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
                priority: priorityItem.name,
                conversationId,
              })
            );
          });
      },
    },
    // Atendente com a trava de fila ligada nao escolhe livremente - so pega
    // a proxima em ordem (botao "Pegar próximo da fila" na lista "Na fila").
    // Administrador nunca e afetado.
    isQueueOrderLocked() {
      return (
        this.hasAnAssignedQueue &&
        this.currentUserRole !== 'administrator' &&
        !!this.currentUserEnforceQueueOrder
      );
    },
    showSelfAssign() {
      if (this.isQueueOrderLocked) {
        return false;
      }
      if (!this.assignedAgent) {
        return true;
      }
      if (
        this.assignedAgent.id !== this.currentUser.id ||
        (this.assignedAgent.assignee_type || 'User') !== 'User'
      ) {
        return true;
      }
      return false;
    },
  },
  methods: {
    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      this.assignedAgent = selfAssign;
    },
    onClickAssignAgent(selectedItem) {
      if (
        this.assignedAgent?.id === selectedItem.id &&
        (this.assignedAgent?.assignee_type || 'User') ===
          (selectedItem.assignee_type || 'User')
      ) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },

    onClickAssignTeam(selectedItemTeam) {
      if (this.assignedTeam && this.assignedTeam.id === selectedItemTeam.id) {
        this.assignedTeam = null;
      } else {
        this.assignedTeam = selectedItemTeam;
      }
    },

    onClickAssignQueue(selectedItemQueue) {
      if (this.assignedQueue && this.assignedQueue.id === selectedItemQueue.id) {
        this.assignedQueue = null;
      } else {
        this.assignedQueue = selectedItemQueue;
      }
    },

    onClickAssignPriority(selectedPriorityItem) {
      const isSamePriority =
        this.assignedPriority &&
        this.assignedPriority.id === selectedPriorityItem.id;

      this.assignedPriority = isSamePriority
        ? this.priorityOptions[0]
        : selectedPriorityItem;
    },
  },
};
</script>

<template>
  <div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')"
      >
        <template #button>
          <NextButton
            v-if="showSelfAssign"
            link
            xs
            icon="i-lucide-arrow-right"
            class="!gap-1"
            :label="$t('CONVERSATION_SIDEBAR.SELF_ASSIGN')"
            @click="onSelfAssign"
          />
        </template>
      </ContactDetailsItem>
      <MultiselectDropdown
        v-if="!isQueueOrderLocked"
        :options="agentsList"
        :selected-item="assignedAgent"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onClickAssignAgent"
      />
      <div v-else class="px-2 pb-2">
        <p class="mb-0 text-sm text-n-slate-12">
          {{ assignedAgent ? assignedAgent.name : $t('CONVERSATION_SIDEBAR.QUEUE_NONE') }}
        </p>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.QUEUE_ORDER_LOCKED') }}
        </p>
      </div>
    </div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')"
      />
      <MultiselectDropdown
        :options="teamsList"
        :selected-item="assignedTeam"
        show-emoji-icon
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')
        "
        @select="onClickAssignTeam"
      />
    </div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.QUEUE_LABEL')"
      />
      <MultiselectDropdown
        :options="queuesList"
        :selected-item="assignedQueue"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.QUEUE')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.QUEUE')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.QUEUE')
        "
        @select="onClickAssignQueue"
      />
    </div>
    <div>
      <ContactDetailsItem compact :title="$t('CONVERSATION.PRIORITY.TITLE')" />
      <MultiselectDropdown
        :options="priorityOptions"
        :selected-item="assignedPriority"
        :multiselector-title="$t('CONVERSATION.PRIORITY.TITLE')"
        :multiselector-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')
        "
        :no-search-result="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')
        "
        :input-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')
        "
        @select="onClickAssignPriority"
      />
    </div>
    <ContactDetailsItem
      compact
      :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
    />
    <ConversationLabels :conversation-id="conversationId" />
  </div>
</template>
