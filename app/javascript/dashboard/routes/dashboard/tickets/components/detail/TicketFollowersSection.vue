<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
});

const { t } = useI18n();
const store = useStore();

const isOpen = ref(false);
const isSaving = ref(false);

const followers = computed(() => props.ticket.followers || []);
const agents = useMapGetter('agents/getAgents');

// Following twice is meaningless, so whoever already follows is left out of the
// list rather than shown and silently ignored.
const options = computed(() => {
  const following = new Set(followers.value.map(follower => follower.user_id));
  return agents.value
    .filter(agent => !following.has(agent.id))
    .map(agent => ({
      label: agent.name,
      value: agent.id,
      action: 'add',
      thumbnail: { name: agent.name, src: agent.thumbnail },
    }));
});

const run = async operation => {
  if (isSaving.value) return;
  isSaving.value = true;
  try {
    await operation();
  } finally {
    isSaving.value = false;
  }
};

const addFollower = ({ value }) => {
  isOpen.value = false;
  run(() =>
    store.dispatch('tickets/addTicketFollower', {
      ticketId: props.ticket.id,
      userId: value,
    })
  );
};

const removeFollower = follower =>
  run(() =>
    store.dispatch('tickets/removeTicketFollower', {
      ticketId: props.ticket.id,
      followerId: follower.id,
    })
  );
</script>

<template>
  <!-- Followers watch the ticket; the Responsavel above owns it. One ticket has
       many of the first and exactly one of the second. -->
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <div class="flex items-center justify-between gap-2 min-w-0">
      <h2 class="text-sm font-medium truncate text-n-slate-12">
        {{ t('TICKET.DETAIL.FOLLOWERS.TITLE') }}
      </h2>

      <OnClickOutside class="relative flex-shrink-0" @trigger="isOpen = false">
        <Button
          v-if="canUpdate"
          variant="faded"
          color="slate"
          size="xs"
          icon="i-lucide-plus"
          :aria-label="t('TICKET.DETAIL.FOLLOWERS.ADD')"
          :disabled="isSaving"
          @click="isOpen = !isOpen"
        />
        <DropdownMenu
          v-if="isOpen"
          show-search
          :menu-items="options"
          :search-placeholder="t('TICKET.DETAIL.FOLLOWERS.SEARCH')"
          empty-state-message="TICKET.DETAIL.FOLLOWERS.NO_AGENTS"
          class="mt-1 top-full ltr:right-0 rtl:left-0 w-56 max-h-64"
          @action="addFollower"
        />
      </OnClickOutside>
    </div>

    <p
      v-if="!followers.length"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-users" class="flex-shrink-0 size-4" />
      {{ t('TICKET.DETAIL.FOLLOWERS.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-2 min-w-0">
      <li
        v-for="follower in followers"
        :key="follower.id"
        class="flex items-center gap-2 min-w-0"
      >
        <Avatar
          :name="follower.name"
          :src="follower.thumbnail"
          :size="24"
          rounded-full
        />
        <span class="flex-1 text-sm truncate min-w-0 text-n-slate-12">
          {{ follower.name }}
        </span>
        <Button
          v-if="canUpdate"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-x"
          class="flex-shrink-0"
          :aria-label="t('TICKET.DETAIL.FOLLOWERS.REMOVE')"
          :disabled="isSaving"
          @click="removeFollower(follower)"
        />
      </li>
    </ul>
  </section>
</template>
