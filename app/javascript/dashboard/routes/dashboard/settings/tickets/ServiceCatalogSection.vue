<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const store = useStore();

const catalogs = useMapGetter('serviceCatalogs/getCatalogs');

const formDialog = ref(null);
const expanded = ref({});
// What is being edited: the level, the record itself, and where it hangs.
const editing = ref({ level: 'catalog', record: null, catalogId: null, areaId: null });
const name = ref('');
const isSaving = ref(false);

const isExpanded = id => !!expanded.value[id];
const toggle = id => {
  expanded.value = { ...expanded.value, [id]: !expanded.value[id] };
};

const dialogTitle = computed(() => {
  const level = t(`TICKET.SETTINGS.CATALOG.LEVEL.${editing.value.level.toUpperCase()}`);
  return editing.value.record
    ? t('TICKET.SETTINGS.CATALOG.EDIT_LEVEL', { level })
    : t('TICKET.SETTINGS.CATALOG.ADD_LEVEL', { level });
});

const openForm = (level, { record = null, catalogId = null, areaId = null } = {}) => {
  editing.value = { level, record, catalogId, areaId };
  name.value = record?.name || '';
  formDialog.value?.open();
};

const ACTIONS = {
  catalog: {
    create: data => store.dispatch('serviceCatalogs/createCatalog', data),
    update: (data, ctx) =>
      store.dispatch('serviceCatalogs/updateCatalog', { id: ctx.record.id, ...data }),
  },
  area: {
    create: (data, ctx) =>
      store.dispatch('serviceCatalogs/createArea', { catalogId: ctx.catalogId, ...data }),
    update: (data, ctx) =>
      store.dispatch('serviceCatalogs/updateArea', {
        catalogId: ctx.catalogId,
        areaId: ctx.record.id,
        ...data,
      }),
  },
  item: {
    create: (data, ctx) =>
      store.dispatch('serviceCatalogs/createItem', {
        catalogId: ctx.catalogId,
        areaId: ctx.areaId,
        ...data,
      }),
    update: (data, ctx) =>
      store.dispatch('serviceCatalogs/updateItem', {
        catalogId: ctx.catalogId,
        areaId: ctx.areaId,
        itemId: ctx.record.id,
        ...data,
      }),
  },
};

const save = async () => {
  const trimmed = name.value.trim();
  if (!trimmed || isSaving.value) return;

  const ctx = editing.value;
  const handler = ACTIONS[ctx.level];
  isSaving.value = true;
  try {
    await (ctx.record ? handler.update({ name: trimmed }, ctx) : handler.create({ name: trimmed }, ctx));
    formDialog.value?.close();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};

// Deactivating is the ordinary path: a record a ticket was classified with is
// never deleted, so it keeps every closed ticket readable while leaving the
// pickers.
const toggleActive = async (level, record, ctx = {}) => {
  try {
    await ACTIONS[level].update({ active: !record.active }, { ...ctx, record });
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  }
};

onBeforeMount(() => store.dispatch('serviceCatalogs/fetch'));
</script>

<template>
  <section class="flex flex-col gap-3 min-w-0">
    <div class="flex justify-end min-w-0">
      <Button
        size="sm"
        class="flex-shrink-0"
        :label="t('TICKET.SETTINGS.CATALOG.ADD_CATALOG')"
        @click="openForm('catalog')"
      />
    </div>

    <p v-if="!catalogs.length" class="py-4 text-sm text-n-slate-10">
      {{ t('TICKET.SETTINGS.CATALOG.EMPTY') }}
    </p>

    <!-- The tree stacks naturally on a narrow screen: indentation is the only
         thing that changes with depth, so nothing overflows sideways. -->
    <ul v-else class="flex flex-col gap-1 min-w-0">
      <li
        v-for="catalog in catalogs"
        :key="catalog.id"
        class="flex flex-col border rounded-lg border-n-weak min-w-0"
      >
        <div class="flex items-center gap-2 p-2 min-w-0">
          <button
            type="button"
            class="flex items-center flex-1 min-w-0 gap-2 text-left"
            @click="toggle(catalog.id)"
          >
            <Icon
              :icon="isExpanded(catalog.id) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
              class="flex-shrink-0 size-4 text-n-slate-11"
            />
            <span
              class="text-sm font-medium truncate"
              :class="catalog.active ? 'text-n-slate-12' : 'text-n-slate-10 line-through'"
            >
              {{ catalog.name }}
            </span>
          </button>
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-plus"
            :aria-label="t('TICKET.SETTINGS.CATALOG.ADD_AREA')"
            @click="openForm('area', { catalogId: catalog.id })"
          />
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-pencil"
            :aria-label="t('TICKET.SETTINGS.CATALOG.EDIT')"
            @click="openForm('catalog', { record: catalog })"
          />
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            :icon="catalog.active ? 'i-lucide-eye-off' : 'i-lucide-eye'"
            :aria-label="t('TICKET.SETTINGS.CATALOG.TOGGLE_ACTIVE')"
            @click="toggleActive('catalog', catalog)"
          />
        </div>

        <ul v-if="isExpanded(catalog.id)" class="flex flex-col gap-1 pb-2 ltr:pl-6 rtl:pr-6 min-w-0">
          <li v-for="area in catalog.areas" :key="area.id" class="flex flex-col min-w-0">
            <div class="flex items-center gap-2 p-1 min-w-0">
              <button
                type="button"
                class="flex items-center flex-1 min-w-0 gap-2 text-left"
                @click="toggle(`area-${area.id}`)"
              >
                <Icon
                  :icon="isExpanded(`area-${area.id}`) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
                  class="flex-shrink-0 size-3.5 text-n-slate-11"
                />
                <span
                  class="text-sm truncate"
                  :class="area.active ? 'text-n-slate-12' : 'text-n-slate-10 line-through'"
                >
                  {{ area.name }}
                </span>
              </button>
              <Button
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-plus"
                :aria-label="t('TICKET.SETTINGS.CATALOG.ADD_ITEM')"
                @click="openForm('item', { catalogId: catalog.id, areaId: area.id })"
              />
              <Button
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-pencil"
                :aria-label="t('TICKET.SETTINGS.CATALOG.EDIT')"
                @click="openForm('area', { record: area, catalogId: catalog.id })"
              />
              <Button
                variant="ghost"
                color="slate"
                size="xs"
                :icon="area.active ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                :aria-label="t('TICKET.SETTINGS.CATALOG.TOGGLE_ACTIVE')"
                @click="toggleActive('area', area, { catalogId: catalog.id })"
              />
            </div>

            <ul
              v-if="isExpanded(`area-${area.id}`)"
              class="flex flex-col ltr:pl-6 rtl:pr-6 min-w-0"
            >
              <li
                v-for="item in area.items"
                :key="item.id"
                class="flex items-center gap-2 p-1 min-w-0"
              >
                <span
                  class="flex-1 text-sm truncate min-w-0"
                  :class="item.active ? 'text-n-slate-11' : 'text-n-slate-10 line-through'"
                >
                  {{ item.name }}
                </span>
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-pencil"
                  :aria-label="t('TICKET.SETTINGS.CATALOG.EDIT')"
                  @click="openForm('item', { record: item, catalogId: catalog.id, areaId: area.id })"
                />
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  :icon="item.active ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                  :aria-label="t('TICKET.SETTINGS.CATALOG.TOGGLE_ACTIVE')"
                  @click="toggleActive('item', item, { catalogId: catalog.id, areaId: area.id })"
                />
              </li>
              <li v-if="!area.items?.length" class="p-1 text-xs text-n-slate-10">
                {{ t('TICKET.SETTINGS.CATALOG.NO_ITEMS') }}
              </li>
            </ul>
          </li>
          <li v-if="!catalog.areas?.length" class="p-1 text-xs text-n-slate-10">
            {{ t('TICKET.SETTINGS.CATALOG.NO_AREAS') }}
          </li>
        </ul>
      </li>
    </ul>

    <Dialog
      ref="formDialog"
      width="md"
      :title="dialogTitle"
      :confirm-button-label="t('TICKET.SETTINGS.CATALOG.SAVE')"
      :disable-confirm-button="!name.trim()"
      :is-loading="isSaving"
      @confirm="save"
    >
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CATALOG.NAME') }}
        </span>
        <input v-model="name" type="text" class="w-full mb-0" @keyup.enter="save" />
      </label>
    </Dialog>
  </section>
</template>
