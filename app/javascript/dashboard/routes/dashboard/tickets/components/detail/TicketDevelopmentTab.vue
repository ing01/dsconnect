<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TicketDevelopmentDialog from './actions/TicketDevelopmentDialog.vue';
import TicketsAPI from 'dashboard/api/tickets';

const props = defineProps({
  ticket: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['refresh']);

const { t } = useI18n();
const route = useRoute();

const dialogRef = ref(null);

const jiraKey = computed(() => props.ticket?.jira_key);

// Children of this ticket that belong to the "Desenvolvimento" team.
// The team check is intentionally loose: if the team name check inside the
// dialog found a team, the children will carry that team_id. We show ALL
// children here and let the dialog decide which team qualifies, since the
// dev-team id is not known at this level. In practice, children created or
// linked through this dialog always belong to the correct team.
const devChildren = computed(() => props.ticket?.children || []);

const STATUS_ICON = {
  open: 'i-lucide-circle-dot',
  resolved: 'i-lucide-check-circle-2',
  closed: 'i-lucide-x-circle',
  cancelled: 'i-lucide-ban',
};

const statusIcon = status => STATUS_ICON[status] || 'i-lucide-circle-dot';

const openInNewTab = child => {
  const path = frontendURL(
    `accounts/${route.params.accountId}/tickets/${child.id}`
  );
  window.open(window.location.origin + path, '_blank');
};

// Per-child confirmation state for destructive actions.
const confirmingId = ref(null);
const confirmingAction = ref(null); // 'delete' | 'unlink'
const isActing = ref(false);

const startConfirm = (childId, action, event) => {
  event.stopPropagation();
  confirmingId.value = childId;
  confirmingAction.value = action;
};

const cancelConfirm = event => {
  event?.stopPropagation();
  confirmingId.value = null;
  confirmingAction.value = null;
};

const executeConfirm = async event => {
  event.stopPropagation();
  if (isActing.value) return;
  isActing.value = true;
  try {
    if (confirmingAction.value === 'delete') {
      await TicketsAPI.delete(confirmingId.value);
    } else {
      await TicketsAPI.setParent(confirmingId.value, null);
    }
    cancelConfirm();
    emit('refresh');
  } catch {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isActing.value = false;
  }
};

const onCreated = () => emit('refresh');
const onLinked = () => emit('refresh');
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-4 min-w-0"
  >
    <div class="flex items-center justify-between gap-2">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.DEVELOPMENT.TITLE') }}
      </h2>
      <Button
        xs
        slate
        faded
        :label="t('TICKET.DETAIL.DEVELOPMENT.ADD_BUTTON')"
        icon="i-lucide-plus"
        @click="dialogRef?.open()"
      />
    </div>

    <!-- Jira key from import -->
    <p v-if="jiraKey" class="flex items-center gap-2 text-sm text-n-slate-12">
      <Icon icon="i-lucide-git-branch" class="size-4 flex-shrink-0 text-n-slate-11" />
      <span class="font-medium">
        {{ t('TICKET.DETAIL.DEVELOPMENT.JIRA_KEY_IMPORTED') }}
      </span>
      {{ jiraKey }}
    </p>

    <!-- Linked development children -->
    <div v-if="devChildren.length" class="flex flex-col gap-1">
      <p class="text-xs font-medium text-n-slate-10 uppercase tracking-wide">
        {{ t('TICKET.DETAIL.DEVELOPMENT.LINKED_TITLE') }}
      </p>
      <div
        v-for="child in devChildren"
        :key="child.id"
        class="group flex items-center gap-2 py-1.5 px-2 rounded-lg bg-n-slate-2 hover:bg-n-slate-3 transition-colors cursor-pointer"
        :title="t('TICKET.DETAIL.DEVELOPMENT.CHILD_OPEN')"
        @click="openInNewTab(child)"
      >
        <Icon
          :icon="statusIcon(child.status)"
          class="size-3.5 flex-shrink-0"
          :class="child.status === 'open' ? 'text-n-brand' : 'text-n-slate-9'"
        />
        <span class="text-xs text-n-slate-10 flex-shrink-0">
          #{{ child.display_id }}
        </span>
        <span class="text-sm text-n-slate-12 truncate min-w-0 flex-1">
          {{ child.title }}
        </span>

        <!-- Confirm state replaces action buttons -->
        <template v-if="confirmingId === child.id">
          <span class="text-xs text-n-slate-11 flex-shrink-0">
            {{
              confirmingAction === 'delete'
                ? t('TICKET.DETAIL.DEVELOPMENT.CHILD_CONFIRM_DELETE')
                : t('TICKET.DETAIL.DEVELOPMENT.CHILD_CONFIRM_UNLINK')
            }}
          </span>
          <Button
            xs
            slate
            :is-loading="isActing"
            :label="t('TICKET.DETAIL.DEVELOPMENT.CHILD_CONFIRM_YES')"
            @click="executeConfirm($event)"
          />
          <Button
            xs
            slate
            faded
            :label="t('TICKET.DETAIL.DEVELOPMENT.CHILD_CONFIRM_NO')"
            @click="cancelConfirm($event)"
          />
        </template>

        <!-- Normal action buttons, shown on hover -->
        <template v-else>
          <div class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
            <Button
              xs
              slate
              faded
              icon="i-lucide-link-2-off"
              :title="t('TICKET.DETAIL.DEVELOPMENT.CHILD_UNLINK')"
              @click="startConfirm(child.id, 'unlink', $event)"
            />
            <Button
              xs
              slate
              faded
              icon="i-lucide-trash-2"
              :title="t('TICKET.DETAIL.DEVELOPMENT.CHILD_DELETE')"
              class="text-n-ruby-11 hover:text-n-ruby-11"
              @click="startConfirm(child.id, 'delete', $event)"
            />
          </div>
        </template>
      </div>
    </div>

    <!-- Empty state when no jira key and no children -->
    <p
      v-else-if="!jiraKey"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-info" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.DEVELOPMENT.EMPTY') }}
    </p>

    <TicketDevelopmentDialog
      ref="dialogRef"
      :ticket="ticket"
      @created="onCreated"
      @linked="onLinked"
    />
  </section>
</template>
