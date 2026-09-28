<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  id: { type: Number, required: true },
  name: { type: String, default: '' },
  domain: { type: String, default: '' },
  contactsCount: { type: Number, default: 0 },
  avatarUrl: { type: String, default: '' },
  lastActivityAt: { type: [String, Number], default: null },
  legalName: { type: String, default: '' },
  cnpj: { type: String, default: '' },
  codigo: { type: String, default: '' },
  clientLevel: { type: Number, default: null },
});

const emit = defineEmits(['showCompany']);

const { t } = useI18n();

const onClickViewDetails = () => emit('showCompany', props.id);

const displayName = computed(() => props.name || t('COMPANIES.UNNAMED'));

const avatarSource = computed(() => props.avatarUrl || null);

const hasContacts = computed(() => Number(props.contactsCount || 0) > 0);

const contactsCountLabel = computed(() =>
  t('COMPANIES.CONTACTS_COUNT', { n: Number(props.contactsCount || 0) })
);

const formattedLastActivityAt = computed(() => {
  if (!props.lastActivityAt) return '';
  return dynamicTime(props.lastActivityAt);
});

// "Razao social" costuma repetir o nome fantasia - mostrar so quando e'
// realmente informacao nova evita a mesma string aparecer duas vezes na linha.
const showLegalName = computed(
  () => props.legalName && props.legalName !== props.name
);

// CNPJ e' guardado so com digitos (normalizado no model) - formata pra
// exibicao, sem alterar o valor de verdade por baixo.
const formattedCnpj = computed(() => {
  const digits = String(props.cnpj || '').replace(/\D/g, '');
  if (digits.length !== 14) return props.cnpj || '';
  return digits.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
});

// Mesma paleta de CompanyProfileCard.vue: 1 Baixa (teal), 2 Media (amber), 3 Alta (ruby).
const CLIENT_LEVEL_COLOR_CLASSES = {
  1: 'bg-n-teal-3 text-n-teal-11',
  2: 'bg-n-amber-3 text-n-amber-11',
  3: 'bg-n-ruby-3 text-n-ruby-11',
};
const clientLevelLabel = computed(() =>
  props.clientLevel
    ? t(`COMPANIES.DETAIL.PROFILE.LEVEL.L${props.clientLevel}`)
    : ''
);
const clientLevelColorClasses = computed(
  () => CLIENT_LEVEL_COLOR_CLASSES[props.clientLevel]
);
</script>

<template>
  <CardLayout layout="row" @click="onClickViewDetails">
    <div class="flex items-center justify-start flex-1 gap-4 cursor-pointer">
      <Avatar
        :username="displayName"
        :src="avatarSource"
        class="shrink-0"
        :name="name"
        :size="42"
        hide-offline-status
      />
      <div class="flex flex-col gap-0.5 flex-1 min-w-0">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1 min-w-0">
          <span class="text-base font-medium truncate text-n-slate-12">
            {{ displayName }}
          </span>
          <span
            v-if="codigo"
            v-tooltip="t('COMPANIES.DETAIL.PROFILE.FIELDS.CODIGO')"
            class="px-1.5 py-0.5 rounded text-xs font-mono leading-none text-n-slate-11 bg-n-slate-3 select-all"
            @click.stop
          >
            {{ codigo }}
          </span>
          <span
            v-if="clientLevelLabel"
            class="inline-flex items-center px-2 py-0.5 text-xs font-semibold rounded-md"
            :class="clientLevelColorClasses"
          >
            {{ clientLevelLabel }}
          </span>
          <span
            v-if="hasContacts"
            class="inline-flex items-center gap-1.5 text-sm text-n-slate-11 truncate"
          >
            <Icon icon="i-lucide-contact" size="size-3.5 text-n-slate-11" />
            {{ contactsCountLabel }}
          </span>
        </div>
        <div
          v-if="showLegalName || formattedCnpj"
          class="flex flex-wrap items-center gap-x-4 gap-y-1 min-w-0"
        >
          <span
            v-if="showLegalName"
            v-tooltip="t('COMPANIES.DETAIL.PROFILE.FIELDS.LEGAL_NAME')"
            class="inline-flex items-center gap-1.5 text-sm text-n-slate-11 truncate"
          >
            <Icon icon="i-lucide-building-2" size="size-3.5 text-n-slate-11" />
            <span class="truncate">{{ legalName }}</span>
          </span>
          <span
            v-if="formattedCnpj"
            v-tooltip="t('COMPANIES.DETAIL.PROFILE.FIELDS.CNPJ')"
            class="inline-flex items-center gap-1.5 text-sm text-n-slate-11 truncate select-all"
            @click.stop
          >
            <Icon icon="i-lucide-file-text" size="size-3.5 text-n-slate-11" />
            {{ formattedCnpj }}
          </span>
        </div>
        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center min-w-0">
            <span
              v-if="domain"
              class="inline-flex items-center gap-1.5 text-sm text-n-slate-11 truncate cursor-text"
              @click.stop
            >
              <Icon icon="i-lucide-globe" size="size-3.5 text-n-slate-11" />
              <span class="truncate">{{ domain }}</span>
            </span>
          </div>
          <span
            v-if="lastActivityAt"
            class="inline-flex items-center gap-1.5 text-sm text-n-slate-11 flex-shrink-0"
          >
            {{ formattedLastActivityAt }}
          </span>
        </div>
      </div>
    </div>
  </CardLayout>
</template>
