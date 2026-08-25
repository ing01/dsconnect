<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const input = ref(null);

// The files are held here and uploaded once the ticket exists: a
// TicketAttachment needs a ticket to belong to, so there is nothing to attach
// them to before the ticket is saved.
const add = event => {
  const chosen = Array.from(event.target.files || []);
  if (chosen.length)
    emit('update:modelValue', [...props.modelValue, ...chosen]);
  // Cleared so picking the same file again still fires `change`.
  event.target.value = '';
};

const remove = index => {
  emit(
    'update:modelValue',
    props.modelValue.filter((_file, position) => position !== index)
  );
};

const formatSize = bytes => `${Math.max(1, Math.round(bytes / 1024))} KB`;
</script>

<template>
  <div class="flex flex-col gap-2 min-w-0">
    <input ref="input" type="file" multiple class="hidden" @change="add" />
    <Button
      variant="faded"
      color="slate"
      size="sm"
      type="button"
      icon="i-lucide-paperclip"
      class="w-fit"
      :label="t('TICKET.CREATE.FILES.ADD')"
      @click="input?.click()"
    />

    <ul v-if="modelValue.length" class="flex flex-col gap-1 min-w-0">
      <li
        v-for="(file, index) in modelValue"
        :key="`${file.name}-${index}`"
        class="flex items-center gap-2 min-w-0 text-xs text-n-slate-11"
      >
        <Icon icon="i-lucide-file" class="flex-shrink-0 size-3.5" />
        <span class="truncate min-w-0" :title="file.name">{{ file.name }}</span>
        <span class="flex-shrink-0 text-n-slate-10">
          {{ formatSize(file.size) }}
        </span>
        <button
          type="button"
          class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
          :aria-label="t('TICKET.CREATE.FILES.REMOVE')"
          @click="remove(index)"
        >
          <Icon icon="i-lucide-x" class="size-3.5" />
        </button>
      </li>
    </ul>
  </div>
</template>
