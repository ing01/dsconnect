<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  // The whole Catalogo > Area > Item tree, already filtered to what is active.
  catalogs: { type: Array, default: () => [] },
  catalogId: { type: [Number, String], default: null },
  areaId: { type: [Number, String], default: null },
  itemId: { type: [Number, String], default: null },
});

const emit = defineEmits(['update:catalogId', 'update:areaId', 'update:itemId']);

const { t } = useI18n();

const selectedCatalog = computed(() =>
  props.catalogs.find(catalog => String(catalog.id) === String(props.catalogId))
);

const areas = computed(() => selectedCatalog.value?.areas || []);

const selectedArea = computed(() =>
  areas.value.find(area => String(area.id) === String(props.areaId))
);

const items = computed(() => selectedArea.value?.items || []);

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
      <select
        :value="catalogId"
        class="w-full mb-0"
        @change="emit('update:catalogId', Number($event.target.value) || null)"
      >
        <option :value="null" disabled>{{ t('TICKET.CATALOG.SELECT') }}</option>
        <option v-for="catalog in catalogs" :key="catalog.id" :value="catalog.id">
          {{ catalog.name }}
        </option>
      </select>
    </label>

    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.CATALOG.AREA') }}<span class="text-n-ruby-11">*</span>
      </span>
      <select
        :value="areaId"
        :disabled="!areas.length"
        class="w-full mb-0"
        @change="emit('update:areaId', Number($event.target.value) || null)"
      >
        <option :value="null" disabled>
          {{ catalogId ? t('TICKET.CATALOG.SELECT') : t('TICKET.CATALOG.NEEDS_CATALOG') }}
        </option>
        <option v-for="area in areas" :key="area.id" :value="area.id">
          {{ area.name }}
        </option>
      </select>
    </label>

    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.CATALOG.ITEM') }}<span class="text-n-ruby-11">*</span>
      </span>
      <select
        :value="itemId"
        :disabled="!items.length"
        class="w-full mb-0"
        @change="emit('update:itemId', Number($event.target.value) || null)"
      >
        <option :value="null" disabled>
          {{ areaId ? t('TICKET.CATALOG.SELECT') : t('TICKET.CATALOG.NEEDS_AREA') }}
        </option>
        <option v-for="item in items" :key="item.id" :value="item.id">
          {{ item.name }}
        </option>
      </select>
    </label>
  </div>
</template>
