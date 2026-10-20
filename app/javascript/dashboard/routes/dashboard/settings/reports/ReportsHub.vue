<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import ReportHubCard from './components/ReportHubCard.vue';

const { t } = useI18n();
const { accountScopedRoute } = useAccount();

// Um card por relatorio - cada um so' linka pra rota que ja existia (nada
// foi duplicado), so' deixou de aparecer como uma lista longa dentro do
// menu lateral.
const cards = computed(() => [
  {
    key: 'overview',
    icon: 'i-lucide-layout-dashboard',
    title: t('SIDEBAR.REPORTS_OVERVIEW'),
    description: t('REPORT.HUB.CARDS.OVERVIEW'),
    to: accountScopedRoute('account_overview_reports'),
  },
  {
    key: 'helpdesk_overview',
    icon: 'i-lucide-life-buoy',
    title: t('SIDEBAR.HELPDESK_OVERVIEW'),
    description: t('REPORT.HUB.CARDS.HELPDESK_OVERVIEW'),
    to: accountScopedRoute('helpdesk_overview_reports'),
  },
  {
    key: 'conversation',
    icon: 'i-lucide-message-square',
    title: t('SIDEBAR.REPORTS_CONVERSATION'),
    description: t('REPORT.HUB.CARDS.CONVERSATION'),
    to: accountScopedRoute('conversation_reports'),
  },
  {
    key: 'agent',
    icon: 'i-lucide-user',
    title: t('SIDEBAR.REPORTS_AGENT'),
    description: t('REPORT.HUB.CARDS.AGENT'),
    to: accountScopedRoute('agent_reports_index'),
  },
  {
    key: 'label',
    icon: 'i-lucide-tag',
    title: t('SIDEBAR.REPORTS_LABEL'),
    description: t('REPORT.HUB.CARDS.LABEL'),
    to: accountScopedRoute('label_reports_index'),
  },
  {
    key: 'inbox',
    icon: 'i-lucide-inbox',
    title: t('SIDEBAR.REPORTS_INBOX'),
    description: t('REPORT.HUB.CARDS.INBOX'),
    to: accountScopedRoute('inbox_reports_index'),
  },
  {
    key: 'team',
    icon: 'i-lucide-users',
    title: t('SIDEBAR.REPORTS_TEAM'),
    description: t('REPORT.HUB.CARDS.TEAM'),
    to: accountScopedRoute('team_reports_index'),
  },
  {
    key: 'ticket',
    icon: 'i-lucide-ticket',
    title: t('SIDEBAR.REPORTS_TICKET'),
    description: t('REPORT.HUB.CARDS.TICKET'),
    to: accountScopedRoute('ticket_reports'),
  },
  {
    key: 'ticket_time',
    icon: 'i-lucide-clock-3',
    title: t('SIDEBAR.REPORTS_TICKET_TIME'),
    description: t('REPORT.HUB.CARDS.TICKET_TIME'),
    to: accountScopedRoute('ticket_time_reports'),
  },
  {
    key: 'ticket_sla',
    icon: 'i-lucide-gauge',
    title: t('SIDEBAR.REPORTS_TICKET_SLA'),
    description: t('REPORT.HUB.CARDS.TICKET_SLA'),
    to: accountScopedRoute('ticket_sla_reports'),
  },
  {
    key: 'csat',
    icon: 'i-lucide-star',
    title: t('SIDEBAR.CSAT'),
    description: t('REPORT.HUB.CARDS.CSAT'),
    to: accountScopedRoute('csat_reports'),
  },
  {
    key: 'sla',
    icon: 'i-lucide-timer',
    title: t('SIDEBAR.REPORTS_SLA'),
    description: t('REPORT.HUB.CARDS.SLA'),
    to: accountScopedRoute('sla_reports'),
  },
  {
    key: 'bot',
    icon: 'i-lucide-bot',
    title: t('SIDEBAR.REPORTS_BOT'),
    description: t('REPORT.HUB.CARDS.BOT'),
    to: accountScopedRoute('bot_reports'),
  },
  {
    key: 'mood_checkins',
    icon: 'i-lucide-smile',
    title: t('SIDEBAR.MOOD_CHECKINS'),
    description: t('REPORT.HUB.CARDS.MOOD_CHECKINS'),
    to: accountScopedRoute('mood_checkins_index'),
  },
  {
    key: 'monthly_satisfaction_surveys',
    icon: 'i-lucide-calendar-check',
    title: t('SIDEBAR.MONTHLY_SATISFACTION_SURVEYS'),
    description: t('REPORT.HUB.CARDS.MONTHLY_SATISFACTION_SURVEYS'),
    to: accountScopedRoute('monthly_satisfaction_surveys_index'),
  },
]);
</script>

<template>
  <div class="py-6">
    <div class="mb-6">
      <h1 class="text-xl font-medium text-n-slate-12 mb-1">
        {{ $t('REPORT.HUB.TITLE') }}
      </h1>
      <p class="text-n-slate-11 text-sm">
        {{ $t('REPORT.HUB.DESCRIPTION') }}
      </p>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      <ReportHubCard
        v-for="card in cards"
        :key="card.key"
        :icon="card.icon"
        :title="card.title"
        :description="card.description"
        :to="card.to"
      />
    </div>
  </div>
</template>
