<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, parseISO } from 'date-fns';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';

// Paleta fixa. O hash do nome garante que o MESMO responsavel sempre
// caia na MESMA cor, e nomes diferentes tendem a cair em cores diferentes.
const ASSIGNEE_COLORS = [
  { bg: 'bg-n-violet-3',  text: 'text-n-violet-11'  },
  { bg: 'bg-n-blue-3',    text: 'text-n-blue-11'    },
  { bg: 'bg-n-teal-3',    text: 'text-n-teal-11'    },
  { bg: 'bg-n-green-3',   text: 'text-n-green-11'   },
  { bg: 'bg-n-amber-3',   text: 'text-n-amber-11'   },
  { bg: 'bg-n-orange-3',  text: 'text-n-orange-11'  },
  { bg: 'bg-n-pink-3',    text: 'text-n-pink-11'    },
  { bg: 'bg-n-ruby-3',    text: 'text-n-ruby-11'    },
  { bg: 'bg-n-indigo-3',  text: 'text-n-indigo-11'  },
  { bg: 'bg-n-purple-3',  text: 'text-n-purple-11'  },
];

const assigneeColor = computed(() => {
  const name = props.suggestion.assignee_name;
  if (!name) return ASSIGNEE_COLORS[0];

  // Hash simples e determinístico (djb2). Mesmo nome -> mesma cor sempre.
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) {
    hash = (hash << 5) - hash + name.charCodeAt(i);
    hash |= 0; // força inteiro 32-bit
  }

  return ASSIGNEE_COLORS[Math.abs(hash) % ASSIGNEE_COLORS.length];
});

const props = defineProps({
  suggestion: { type: Object, required: true },
});

defineEmits(['click']);

const { t } = useI18n();

const dateLabel = computed(() =>
  props.suggestion.created_at
    ? format(parseISO(props.suggestion.created_at), 'dd/MM/yyyy')
    : ''
);

const completedLabel = computed(() =>
  props.suggestion.completed_at
    ? t('SUGGESTIONS.CARD.COMPLETED_ON', {
        date: format(parseISO(props.suggestion.completed_at), 'dd/MM/yyyy'),
      })
    : ''
);
</script>

<template>
  <div
    class="drag-handle flex flex-col gap-2 rounded-xl border p-3 cursor-pointer hover:shadow-sm transition-shadow"
    :class="
      suggestion.completed_at
        ? 'bg-n-teal-4 border-n-teal-7 hover:border-n-teal-8'
        : 'bg-n-solid-1 border-n-weak hover:border-n-slate-6'
    "
    @click="$emit('click', suggestion)"
  >
    <p
      class="text-sm font-medium line-clamp-2 mb-0"
      :class="suggestion.completed_at ? 'text-n-teal-12' : 'text-n-slate-12'"
    >
      {{ suggestion.title }}
    </p>
    <p
      v-if="suggestion.description"
      class="text-xs line-clamp-3 mb-0"
      :class="suggestion.completed_at ? 'text-n-teal-11' : 'text-n-slate-11'"
    >
      {{ suggestion.description }}
    </p>
    <div
      v-if="suggestion.priority_name || suggestion.category_name"
      class="flex flex-wrap gap-1"
    >
      <Label
        v-if="suggestion.priority_name"
        compact
        :label="suggestion.priority_name"
        :color="suggestion.priority_color || 'slate'"
      />
      <Label
        v-if="suggestion.category_name"
        compact
        :label="suggestion.category_name"
        :color="suggestion.category_color || 'slate'"
      />
    </div>
    <div
        v-if="suggestion.assignee_name"
        class="flex items-center gap-1 text-xs font-medium"
        :class="assigneeColor.text"
      >
        <span
          class="flex size-5 flex-shrink-0 items-center justify-center rounded-full text-[10px] font-semibold"
          :class="[assigneeColor.bg, assigneeColor.text]"
        >
          {{ suggestion.assignee_name.charAt(0).toUpperCase() }}
        </span>
        <span class="truncate">{{ suggestion.assignee_name }}</span>
      </div>
    <div class="flex items-center justify-between gap-2">
      <div v-if="suggestion.user_name" class="flex items-center gap-1.5 min-w-0">
        <span
          class="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-slate-4 text-[10px] font-medium text-n-slate-12"
        >
          {{ suggestion.user_name.charAt(0).toUpperCase() }}
        </span>
        <span class="text-xs text-n-slate-11 truncate">
          {{ suggestion.user_name }}
        </span>
      </div>
      <div v-else />
      <div class="flex items-center flex-shrink-0 gap-2">
        <span
          v-if="suggestion.time_spent_hours"
          class="flex items-center gap-0.5 text-xs text-n-slate-10"
        >
          <Icon icon="i-lucide-clock" class="size-3" />
          {{ suggestion.time_spent_hours }}h
        </span>
        <span
          v-if="suggestion.attachments?.length"
          class="flex items-center gap-0.5 text-xs text-n-slate-10"
        >
          <Icon icon="i-lucide-paperclip" class="size-3" />
          {{ suggestion.attachments.length }}
        </span>
        <span
          class="text-xs flex-shrink-0 inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full"
          :class="
            suggestion.completed_at
              ? 'bg-n-teal-9 text-white font-semibold'
              : 'text-n-slate-10'
          "
        >
          <Icon
            v-if="suggestion.completed_at"
            icon="i-lucide-check-circle-2"
            class="size-3"
          />
          {{ suggestion.completed_at ? completedLabel : dateLabel }}
        </span>
      </div>
    </div>
  </div>
</template>
