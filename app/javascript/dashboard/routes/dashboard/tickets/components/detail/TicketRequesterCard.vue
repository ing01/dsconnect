<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
});

// Each value is edited where it is shown, rather than through one generic
// ticket form.
const emit = defineEmits(['editCompany', 'editContact']);

const { t } = useI18n();
const route = useRoute();

const contact = computed(() => props.ticket.contact);

// Company and Contact stay separate concepts: the organization and the person
// who asked. A ticket can carry both, either, or neither.
const companyRoute = computed(() =>
  frontendURL(
    `accounts/${route.params.accountId}/companies/${props.ticket.company_id}`
  )
);
</script>

<template>
  <section class="rounded-xl border border-n-weak p-4 flex flex-col gap-4">
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.REQUESTER.TITLE') }}
    </h2>

    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-2 min-w-0">
        <span class="text-xs uppercase tracking-wide text-n-slate-10 truncate">
          {{ t('TICKET.DETAIL.REQUESTER.CONTACT') }}
        </span>
        <Button
          v-if="canUpdate"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-pencil"
          class="flex-shrink-0"
          :aria-label="t('TICKET.ACTIONS.CONTACT_DIALOG.TITLE')"
          @click="emit('editContact')"
        />
      </div>

      <div v-if="contact" class="flex items-start gap-3 min-w-0">
        <Avatar
          :name="contact.name || '?'"
          :src="contact.thumbnail"
          :size="36"
          rounded-full
          hide-offline-status
          class="flex-shrink-0"
        />
        <div class="flex flex-col gap-0.5 min-w-0">
          <span
            class="text-sm font-medium text-n-slate-12 truncate"
            :title="contact.name"
          >
            {{ contact.name }}
          </span>
          <a
            v-if="contact.email"
            :href="`mailto:${contact.email}`"
            class="flex items-center gap-1 text-xs text-n-slate-11 hover:text-n-blue-11 truncate"
            :title="contact.email"
          >
            <Icon icon="i-lucide-mail" class="size-3 flex-shrink-0" />
            {{ contact.email }}
          </a>
          <a
            v-if="contact.phone_number"
            :href="`tel:${contact.phone_number}`"
            class="flex items-center gap-1 text-xs text-n-slate-11 hover:text-n-blue-11 truncate"
          >
            <Icon icon="i-lucide-phone" class="size-3 flex-shrink-0" />
            {{ contact.phone_number }}
          </a>
        </div>
      </div>
      <p v-else class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.REQUESTER.NO_CONTACT') }}
      </p>
    </div>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-2 min-w-0">
        <span class="text-xs uppercase tracking-wide text-n-slate-10 truncate">
          {{ t('TICKET.COMPANY.LABEL') }}
        </span>
        <Button
          v-if="canUpdate"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-pencil"
          class="flex-shrink-0"
          :aria-label="t('TICKET.ACTIONS.COMPANY_DIALOG.TITLE')"
          @click="emit('editCompany')"
        />
      </div>
      <router-link
        v-if="ticket.company_id"
        :to="companyRoute"
        class="text-sm text-n-blue-11 hover:underline truncate"
        :title="ticket.company_name"
      >
        {{ ticket.company_name }}
      </router-link>
      <p v-else class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.REQUESTER.NO_COMPANY') }}
      </p>
    </div>
  </section>
</template>
