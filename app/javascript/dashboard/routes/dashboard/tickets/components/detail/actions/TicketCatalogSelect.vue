<script setup>
import TicketSelect from '../../TicketSelect.vue';
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  // The whole Catalogo > Area > Item tree, already filtered to what is active.
  catalogs: { type: Array, default: () => [] },
  catalogId: { type: [Number, String], default: null },
  areaId: { type: [Number, String], default: null },
  itemId: { type: [Number, String], default: null },
});

const emit = defineEmits([
  'update:catalogId',
  'update:areaId',
  'update:itemId',
]);

const { t } = useI18n();

const selectedCatalog = computed(() =>
  props.catalogs.find(catalog => String(catalog.id) === String(props.catalogId))
);

const areas = computed(() => selectedCatalog.value?.areas || []);

const selectedArea = computed(() =>
  areas.value.find(area => String(area.id) === String(props.areaId))
);

const items = computed(() => selectedArea.value?.items || []);

// As tres listas no formato do TicketSelect, o seletor padrao do modulo.
const toOptions = records =>
  records.map(record => ({ value: record.id, label: record.name }));

const catalogOptions = computed(() => toOptions(props.catalogs));
const areaOptions = computed(() => toOptions(areas.value));
const itemOptions = computed(() => toOptions(items.value));

// Each level only offers what belongs to the one above it, and changing a level
// drops what depended on it. The backend walks the same hierarchy, so an
// incompatible trio is refused there too - this only keeps the agent from
// building one.
watch(
  () => props.catalogId,
  (value, previous) => {
    if (previous === undefined || value === previous) return;
    emit('update:areaId', null);
    emit('update:itemId', null);
  }
);

watch(
  () => props.areaId,
  (value, previous) => {
    if (previous === undefined || value === previous) return;
    emit('update:itemId', null);
  }
);
</script>

<template>
  <div class="grid grid-cols-1 gap-4 md:grid-cols-3 min-w-0">
    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.CATALOG.CATALOG') }}<span class="text-n-ruby-11">*</span>
      </span>
      <TicketSelect
        :model-value="catalogId"
        :options="catalogOptions"
        :placeholder="t('TICKET.CATALOG.SELECT')"
        :aria-label="t('TICKET.CATALOG.SELECT')"
        @update:model-value="value => emit('update:catalogId', value)"
      />
    </label>

    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.CATALOG.AREA') }}<span class="text-n-ruby-11">*</span>
      </span>
      <TicketSelect
        :model-value="areaId"
        :options="areaOptions"
        :disabled="!areas.length"
        :placeholder="
          catalogId
            ? t('TICKET.CATALOG.SELECT')
            : t('TICKET.CATALOG.NEEDS_CATALOG')
        "
        :aria-label="t('TICKET.CATALOG.AREA')"
        @update:model-value="value => emit('update:areaId', value)"
      />
    </label>

    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.CATALOG.ITEM') }}<span class="text-n-ruby-11">*</span>
      </span>
      <TicketSelect
        :model-value="itemId"
        :options="itemOptions"
        :disabled="!items.length"
        :placeholder="
          areaId ? t('TICKET.CATALOG.SELECT') : t('TICKET.CATALOG.NEEDS_AREA')
        "
        :aria-label="t('TICKET.CATALOG.ITEM')"
        @update:model-value="value => emit('update:itemId', value)"
      />
    </label>
  </div>
</template>
