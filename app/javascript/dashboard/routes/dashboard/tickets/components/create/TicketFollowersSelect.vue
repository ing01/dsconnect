<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  // Followers watch a ticket in a Mesa, so the candidates are that Mesa's
  // members - the same list the Responsavel comes from.
  members: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const isOpen = ref(false);

const selected = computed(() =>
  props.members.filter(member => props.modelValue.includes(member.id))
);

const options = computed(() =>
  props.members.map(member => ({
    label: member.name,
    value: member.id,
    action: 'toggle',
    isSelected: props.modelValue.includes(member.id),
    thumbnail: { name: member.name, src: member.thumbnail },
  }))
);

// Multi-select: clicking an entry toggles it and the menu stays open, so
// several people can be added in one go.
const toggle = ({ value }) => {
  const next = props.modelValue.includes(value)
    ? props.modelValue.filter(id => id !== value)
    : [...props.modelValue, value];
  emit('update:modelValue', next);
};

const remove = id =>
  emit(
    'update:modelValue',
    props.modelValue.filter(current => current !== id)
  );

const clearAll = () => emit('update:modelValue', []);

const placeholder = computed(() =>
  selected.value.length
    ? t('TICKET.CREATE.FOLLOWERS.ADD_MORE')
    : t('TICKET.CREATE.FOLLOWERS.PLACEHOLDER')
);
</script>

<template>
  <OnClickOutside class="relative w-full min-w-0" @trigger="isOpen = false">
    <!-- Cada seguidor e' uma etiqueta com "x": remover nao exige reabrir a lista. -->
    <div
      class="flex items-center w-full gap-1 px-2 py-1 border rounded-lg min-h-10 border-n-weak bg-n-alpha-black2 text-n-slate-12"
      :class="{ 'opacity-50': disabled || !members.length }"
      data-testid="followers-box"
    >
      <ul
        class="flex flex-wrap items-center flex-1 min-w-0 gap-1 m-0 list-none"
      >
        <li
          v-for="member in selected"
          :key="member.id"
          class="flex items-center gap-1 py-0.5 pl-2 pr-1 text-sm rounded-md bg-n-alpha-2"
          :data-testid="`follower-chip-${member.id}`"
        >
          <span class="truncate max-w-[10rem]">{{ member.name }}</span>
          <button
            type="button"
            class="flex items-center justify-center rounded size-5 text-n-slate-10 hover:bg-n-alpha-3 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :disabled="disabled"
            :aria-label="
              t('TICKET.CREATE.FOLLOWERS.REMOVE', { name: member.name })
            "
            :data-testid="`follower-remove-${member.id}`"
            @click="remove(member.id)"
          >
            <Icon icon="i-lucide-x" class="size-3.5" />
          </button>
        </li>
        <li class="flex-1 min-w-[6rem]">
          <button
            type="button"
            :disabled="disabled || !members.length"
            class="w-full h-8 text-sm text-left text-n-slate-10 disabled:cursor-not-allowed"
            data-testid="followers-toggle"
            @click="isOpen = !isOpen"
          >
            {{ placeholder }}
          </button>
        </li>
      </ul>

      <button
        v-if="selected.length > 1"
        type="button"
        class="flex-shrink-0 px-1 text-xs rounded text-n-slate-10 hover:text-n-slate-12"
        :disabled="disabled"
        data-testid="followers-clear"
        @click="clearAll"
      >
        {{ t('TICKET.CREATE.FOLLOWERS.CLEAR') }}
      </button>
      <button
        type="button"
        :disabled="disabled || !members.length"
        class="flex items-center justify-center flex-shrink-0 size-7 text-n-slate-10"
        :aria-label="t('TICKET.CREATE.FOLLOWERS.ADD_MORE')"
        @click="isOpen = !isOpen"
      >
        <Icon icon="i-lucide-chevron-down" class="size-4" />
      </button>
    </div>

    <DropdownMenu
      v-if="isOpen"
      show-search
      :menu-items="options"
      :search-placeholder="t('TICKET.CREATE.FOLLOWERS.SEARCH')"
      empty-state-message="TICKET.CREATE.FOLLOWERS.EMPTY"
      class="mt-1 top-full w-full max-h-64"
      @action="toggle"
    />
  </OnClickOutside>
</template>
