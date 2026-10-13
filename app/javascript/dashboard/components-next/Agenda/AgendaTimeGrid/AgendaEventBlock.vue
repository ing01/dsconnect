<script setup>
import { computed, ref } from 'vue';
import { format, parseISO, addMinutes } from 'date-fns';
import { colorForEvent } from '../helpers/agentColorHelper';
import { isTimeOffEvent } from '../helpers/agendaDateHelper';
import { HOUR_HEIGHT_PX, MIN_EVENT_DURATION_MINUTES, DRAG_SNAP_MINUTES } from '../constants';

const props = defineProps({
  event: {
    type: Object,
    required: true,
  },
  top: {
    type: Number,
    required: true,
  },
  height: {
    type: Number,
    required: true,
  },
  left: {
    type: Number,
    default: 0,
  },
  width: {
    type: Number,
    default: 100,
  },
  clippedAtStart: {
    type: Boolean,
    default: false,
  },
  clippedAtEnd: {
    type: Boolean,
    default: false,
  },
  // Uma ocorrencia de serie recorrente nao arrasta/redimensiona por aqui -
  // mudar so' esta ocorrencia ou a serie inteira precisa da mesma escolha de
  // escopo que editar pelo formulario ja pede (ver RecurrenceScopeDialog),
  // que esse gesto rapido nao tem como perguntar.
  draggable: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['click', 'drag-end']);

const color = computed(() => colorForEvent(props.event));
const isTimeOff = computed(() => isTimeOffEvent(props.event));
const pxPerMinute = HOUR_HEIGHT_PX / 60;

const timeRangeLabel = () =>
  `${format(parseISO(props.event.start_at), 'HH:mm')} - ${format(parseISO(props.event.end_at), 'HH:mm')}`;

// Enquanto arrasta, o bloco se desenha deslocado/redimensionado via estas
// duas variaveis (sem recalcular top/height "de verdade" - isso so' acontece
// quando o servidor confirmar a mudanca, depois do pointerup).
const dragOffsetY = ref(0);
const dragHeightOverride = ref(null);
const isDragging = ref(false);
let dragMode = null;
let startClientY = 0;
let hasMoved = false;
let originStart = null;
let originEnd = null;

const snapMinutes = minutes => Math.round(minutes / DRAG_SNAP_MINUTES) * DRAG_SNAP_MINUTES;

const handlePointerMove = e => {
  const deltaY = e.clientY - startClientY;
  if (Math.abs(deltaY) > 3) hasMoved = true;
  const deltaMinutes = snapMinutes(deltaY / pxPerMinute);

  if (dragMode === 'resize') {
    const minHeightPx = MIN_EVENT_DURATION_MINUTES * pxPerMinute;
    dragHeightOverride.value = Math.max(props.height + deltaMinutes * pxPerMinute, minHeightPx);
  } else {
    dragOffsetY.value = deltaMinutes * pxPerMinute;
  }
};

const handlePointerUp = () => {
  window.removeEventListener('pointermove', handlePointerMove);
  window.removeEventListener('pointerup', handlePointerUp);

  if (!hasMoved) {
    emit('click');
  } else {
    const deltaMinutes = snapMinutes(dragOffsetY.value / pxPerMinute);
    if (dragMode === 'resize') {
      const minutesHeld = Math.round(dragHeightOverride.value / pxPerMinute);
      const newEnd = addMinutes(originStart, Math.max(minutesHeld, MIN_EVENT_DURATION_MINUTES));
      emit('drag-end', { startAt: originStart, endAt: newEnd });
    } else {
      emit('drag-end', { startAt: addMinutes(originStart, deltaMinutes), endAt: addMinutes(originEnd, deltaMinutes) });
    }
  }

  isDragging.value = false;
  dragOffsetY.value = 0;
  dragHeightOverride.value = null;
};

const startDrag = (mode, e) => {
  if (!props.draggable) return;
  e.preventDefault();
  e.stopPropagation();

  dragMode = mode;
  startClientY = e.clientY;
  hasMoved = false;
  isDragging.value = true;
  originStart = parseISO(props.event.start_at);
  originEnd = parseISO(props.event.end_at);

  window.addEventListener('pointermove', handlePointerMove);
  window.addEventListener('pointerup', handlePointerUp);
};

const handleBlockPointerDown = e => {
  if (!props.draggable) return;
  startDrag('move', e);
};

// O clique nativo (alem do nosso proprio `emit('click')` sintetico no
// pointerup) sempre precisa ser freado aqui - senao ele continua subindo
// pro fundo da coluna, que trataria como "clicou no vazio" e abriria um
// evento novo por cima do que acabou de ser clicado/arrastado.
const handleClick = e => {
  e.stopPropagation();
  if (!props.draggable) emit('click');
};
</script>

<template>
  <button
    type="button"
    class="absolute overflow-hidden rounded-md px-2 py-1 text-left text-white shadow-sm transition-[opacity] hover:opacity-90 select-none"
    :class="[
      { 'rounded-t-none': clippedAtStart, 'rounded-b-none': clippedAtEnd },
      { 'cursor-grab': draggable && !isDragging, 'cursor-grabbing': isDragging, 'ring-2 ring-white/70 z-10': isDragging },
      { 'opacity-80 border border-dashed border-white/70': isTimeOff },
    ]"
    :style="{
      top: `${top}px`,
      height: `${dragHeightOverride ?? height}px`,
      left: `${left}%`,
      width: `calc(${width}% - 4px)`,
      backgroundColor: color,
      transform: dragOffsetY ? `translateY(${dragOffsetY}px)` : undefined,
    }"
    @pointerdown="handleBlockPointerDown"
    @click="handleClick"
  >
    <span class="flex items-center gap-1 text-xs font-medium truncate">
      <span v-if="isTimeOff" class="shrink-0 i-lucide-palmtree size-3" />
      {{ event.title }}
    </span>
    <span class="block text-[0.6875rem] opacity-90 truncate">{{ timeRangeLabel() }}</span>

    <div
      v-if="draggable"
      class="absolute inset-x-0 bottom-0 h-1.5 cursor-ns-resize"
      @pointerdown="e => startDrag('resize', e)"
    />
  </button>
</template>
