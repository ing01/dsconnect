<script setup>
/* eslint-disable vue/no-bare-strings-in-template */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';

const props = defineProps({
  briefing: { type: Object, required: true },
});

const emit = defineEmits(['selectCompany', 'navigate']);

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');

const company = computed(() => props.briefing.company);

const formatDate = value => {
  if (!value) return '';
  // Epoch em segundos (API) ou data "AAAA-MM-DD", que sem a hora voltaria um dia
  // no fuso do Brasil.
  const date =
    typeof value === 'number'
      ? new Date(value * 1000)
      : new Date(`${value}T00:00:00`);
  return date.toLocaleDateString('pt-BR');
};

const joined = values => values.filter(Boolean).join(' · ');

const companyFacts = computed(() => {
  const data = company.value;
  if (!data) return [];

  return [
    ['LEVEL', data.classification_level],
    ['CATEGORY', data.category],
    ['SPECIALIST', data.specialist],
    ['SINCE', formatDate(data.system_started_on)],
    ['MODULES', data.system_modules.join(', ')],
  ].filter(([, value]) => value);
});

const conversationGroups = computed(() =>
  [
    ['CONTACT_CONVERSATIONS', props.briefing.contact_conversations],
    ['COMPANY_CONVERSATIONS', props.briefing.company_conversations],
  ].filter(([key, list]) => key === 'CONTACT_CONVERSATIONS' || list.length > 0)
);

const ticketLink = ticket =>
  frontendURL(`accounts/${accountId.value}/tickets/${ticket.id}`);
const conversationLink = item =>
  frontendURL(
    conversationUrl({ accountId: accountId.value, id: item.display_id })
  );
</script>

<template>
  <div class="flex flex-col gap-5 max-h-[70vh] overflow-y-auto">
    <section v-if="company" class="flex flex-col gap-2">
      <div class="flex flex-wrap items-center gap-2">
        <select
          v-if="briefing.companies.length > 1"
          :value="company.id"
          class="w-auto mb-0 text-sm"
          :aria-label="t('CUSTOMER_BRIEFING.COMPANY')"
          data-testid="briefing-company"
          @change="emit('selectCompany', Number($event.target.value))"
        >
          <option
            v-for="item in briefing.companies"
            :key="item.id"
            :value="item.id"
          >
            {{ item.name }}
          </option>
        </select>
        <span v-else class="text-sm font-semibold text-n-slate-12">
          {{ company.name }}
        </span>
        <span
          class="px-2 py-0.5 text-xs rounded-full"
          :class="
            company.status === 'active'
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-amber-3 text-n-amber-11'
          "
        >
          {{ t(`CUSTOMER_BRIEFING.STATUS.${company.status.toUpperCase()}`) }}
        </span>
        <span
          v-if="company.blocked"
          class="px-2 py-0.5 text-xs rounded-full bg-n-ruby-3 text-n-ruby-11"
        >
          {{ t('CUSTOMER_BRIEFING.BLOCKED') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{
            t('CUSTOMER_BRIEFING.TICKET_TOTALS', {
              open: company.open_tickets_count,
              total: company.tickets_count,
            })
          }}
        </span>
      </div>
      <dl class="grid gap-x-4 gap-y-1 m-0 text-sm sm:grid-cols-2">
        <div v-for="[key, value] in companyFacts" :key="key" class="flex gap-1">
          <dt class="text-n-slate-10">
            {{ t(`CUSTOMER_BRIEFING.FACTS.${key}`) }}:
          </dt>
          <dd class="m-0 text-n-slate-12">{{ value }}</dd>
        </div>
      </dl>
    </section>
    <p v-else class="m-0 text-sm text-n-slate-11">
      {{ t('CUSTOMER_BRIEFING.NO_COMPANY') }}
    </p>

    <section class="flex flex-col gap-1">
      <h4 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('CUSTOMER_BRIEFING.CONTACT') }}
      </h4>
      <p class="m-0 text-sm text-n-slate-12">
        {{
          joined([
            briefing.contact.name,
            briefing.contact.phone_number,
            briefing.contact.email,
          ])
        }}
      </p>
      <p class="m-0 text-xs text-n-slate-10">
        {{
          t('CUSTOMER_BRIEFING.PREVIOUS_COUNT', {
            count: briefing.contact.previous_conversations_count,
          })
        }}
      </p>
      <p
        v-for="(note, index) in briefing.contact.notes"
        :key="index"
        class="m-0 text-sm break-words whitespace-pre-wrap border-s-2 ps-2 border-n-amber-8 text-n-slate-11"
      >
        {{ note.content }}
        <span class="text-xs text-n-slate-10">
          {{ joined([note.author, formatDate(note.created_at)]) }}
        </span>
      </p>
    </section>

    <slot name="summary" />

    <section class="flex flex-col gap-1">
      <h4 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('CUSTOMER_BRIEFING.TICKETS') }}
      </h4>
      <p v-if="!briefing.tickets.length" class="m-0 text-sm text-n-slate-10">
        {{ t('CUSTOMER_BRIEFING.NO_TICKETS') }}
      </p>
      <router-link
        v-for="ticket in briefing.tickets"
        :key="ticket.id"
        :to="ticketLink(ticket)"
        class="flex flex-col px-2 py-1.5 rounded-md hover:bg-n-alpha-2"
        data-testid="briefing-ticket"
        @click="emit('navigate')"
      >
        <span class="text-sm text-n-slate-12">
          #{{ ticket.display_id }} — {{ ticket.title }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{
            joined([
              t(`TICKET.STATUS.${ticket.status.toUpperCase()}`),
              ticket.priority &&
                t(`TICKET.FORM.PRIORITY.${ticket.priority.toUpperCase()}`),
              ticket.team,
              ticket.assignee,
              ticket.contact,
              formatDate(ticket.created_at),
            ])
          }}
        </span>
      </router-link>
    </section>

    <section
      v-for="[key, list] in conversationGroups"
      :key="key"
      class="flex flex-col gap-1"
    >
      <h4 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t(`CUSTOMER_BRIEFING.${key}`) }}
      </h4>
      <p v-if="!list.length" class="m-0 text-sm text-n-slate-10">
        {{ t('CUSTOMER_BRIEFING.NO_CONVERSATIONS') }}
      </p>
      <router-link
        v-for="item in list"
        :key="item.display_id"
        :to="conversationLink(item)"
        class="flex flex-col px-2 py-1.5 rounded-md hover:bg-n-alpha-2"
        data-testid="briefing-conversation"
        @click="emit('navigate')"
      >
        <span class="text-xs text-n-slate-10">
          {{
            joined([
              `#${item.display_id}`,
              formatDate(item.last_activity_at),
              t(
                `CUSTOMER_BRIEFING.CONVERSATION_STATUS.${item.status.toUpperCase()}`
              ),
              item.contact,
              item.assignee,
              item.inbox,
            ])
          }}
        </span>
        <span class="text-sm break-words line-clamp-2 text-n-slate-12">
          {{ item.last_message || t('CUSTOMER_BRIEFING.NO_MESSAGE') }}
        </span>
      </router-link>
    </section>
  </div>
</template>
