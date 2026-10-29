<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const route = useRoute();

const conversationsByContact = useMapGetter(
  'contactConversations/getAllConversationsByContactId'
);
const notesByContact = useMapGetter('contactNotes/getAllNotesByContactId');

const conversations = computed(
  () => conversationsByContact.value(route.params.contactId) || []
);
const notes = computed(
  () => notesByContact.value(route.params.contactId) || []
);

const tiles = computed(() => [
  {
    key: 'CONVERSATIONS',
    icon: 'i-lucide-messages-square',
    value: conversations.value.length,
  },
  {
    key: 'OPEN_CONVERSATIONS',
    icon: 'i-lucide-message-circle-more',
    value: conversations.value.filter(({ status }) => status === 'open').length,
  },
  { key: 'NOTES', icon: 'i-lucide-notebook-pen', value: notes.value.length },
  {
    key: 'COMPANIES',
    icon: 'i-lucide-building-2',
    value: (props.selectedContact?.companies || []).length,
  },
]);

const details = computed(() => [
  {
    key: 'EMAIL',
    icon: 'i-lucide-mail',
    value: props.selectedContact?.email,
  },
  {
    key: 'PHONE',
    icon: 'i-lucide-phone',
    value: props.selectedContact?.phoneNumber,
  },
  {
    key: 'IDENTIFIER',
    icon: 'i-lucide-fingerprint',
    value: props.selectedContact?.identifier,
  },
]);
</script>

<template>
  <div class="flex flex-col w-full gap-4">
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div
        v-for="tile in tiles"
        :key="tile.key"
        class="flex flex-col gap-1 p-3 border rounded-xl border-n-weak bg-n-solid-2"
      >
        <span class="flex items-center gap-1.5 text-xs text-n-slate-11">
          <span :class="tile.icon" class="size-3.5 text-n-slate-10" />
          {{ t(`CONTACTS_LAYOUT.SIDEBAR.SUMMARY.${tile.key}`) }}
        </span>
        <span class="text-xl font-semibold text-n-slate-12">
          {{ tile.value }}
        </span>
      </div>
    </div>

    <div class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.SIDEBAR.SUMMARY.SECTIONS_CONTACT') }}
      </span>
      <dl class="grid gap-x-6 gap-y-2 sm:grid-cols-2">
        <div v-for="item in details" :key="item.key" class="flex flex-col">
          <dt class="flex items-center gap-1.5 text-xs text-n-slate-11">
            <span :class="item.icon" class="size-3.5 text-n-slate-10" />
            {{ t(`CONTACTS_LAYOUT.SIDEBAR.SUMMARY.${item.key}`) }}
          </dt>
          <dd class="text-sm break-all text-n-slate-12">
            {{ item.value || t('CONTACTS_LAYOUT.SIDEBAR.SUMMARY.NONE') }}
          </dd>
        </div>
      </dl>
    </div>
  </div>
</template>
