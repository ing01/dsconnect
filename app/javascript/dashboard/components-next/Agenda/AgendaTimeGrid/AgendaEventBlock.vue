<script setup>
import { computed, ref } from 'vue';
import { format, parseISO, addMinutes } from 'date-fns';
import { colorForEvent, eventSurfaceStyle } from '../helpers/agentColorHelper';
import { isPastDayEvent, isTimeOffEvent } from '../helpers/agendaDateHelper';
import {
  HOUR_HEIGHT_PX,
  MIN_EVENT_DURATION_MINUTES,
  DRAG_SNAP_MINUTES,
} from '../constants';

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

const emit = defineEmits(['click', 'dragEnd']);

const color = computed(() => colorForEvent(props.event));
const isTimeOff = computed(() => isTimeOffEvent(props.event));
const isPast = computed(() => isPastDayEvent(props.event));
const pxPerMinute = HOUR_HEIGHT_PX / 60;

const timeRangeLabel = () =>
  `${format(parseISO(props.event.start_at), 'HH:mm')}–${format(parseISO(props.event.end_at), 'HH:mm')}`;

// Dia cheio (varios eventos dividindo a coluna) deixa cada bloco estreito
// demais para ler. Ao passar o mouse, o bloco cresce para o LADO (ate
// EXPANDED_MIN_WIDTH) e para BAIXO (ate caber o texto), por cima dos vizinhos.
// Quem esta na metade direita da coluna cresce para a esquerda, para nao sair
// da tela no ultimo dia da semana.
const EXPANDED_MIN_WIDTH = '13rem';
const isHovered = ref(false);
const anchorRight = computed(() => props.left + props.width / 2 > 50);

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

const isExpanded = computed(() => isHovered.value && !isDragging.value);

const blockStyle = computed(() => {
  const heightPx = `${dragHeightOverride.value ?? props.height}px`;
  const baseWidth = `calc(${props.width}% - 4px)`;
  const expandRight = isExpanded.value && anchorRight.value;
  return {
    ...eventSurfaceStyle(color.value),
    top: `${props.top}px`,
    height: isExpanded.value ? 'auto' : heightPx,
    minHeight: heightPx,
    left: expandRight ? 'auto' : `${props.left}%`,
    right: expandRight
      ? `calc(${100 - props.left - props.width}% + 4px)`
      : undefined,
    width: isExpanded.value
      ? `max(${baseWidth}, ${EXPANDED_MIN_WIDTH})`
      : baseWidth,
    transform: dragOffsetY.value
      ? `translateY(${dragOffsetY.value}px)`
      : undefined,
  };
});

const snapMinutes = minutes =>
  Math.round(minutes / DRAG_SNAP_MINUTES) * DRAG_SNAP_MINUTES;

const handlePointerMove = e => {
  const deltaY = e.clientY - startClientY;
  if (Math.abs(deltaY) > 3) hasMoved = true;
  const deltaMinutes = snapMinutes(deltaY / pxPerMinute);

  if (dragMode === 'resize') {
    const minHeightPx = MIN_EVENT_DURATION_MINUTES * pxPerMinute;
    dragHeightOverride.value = Math.max(
      props.height + deltaMinutes * pxPerMinute,
      minHeightPx
    );
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
      const newEnd = addMinutes(
        originStart,
        Math.max(minutesHeld, MIN_EVENT_DURATION_MINUTES)
      );
      emit('dragEnd', { startAt: originStart, endAt: newEnd });
    } else {
      emit('dragEnd', {
        startAt: addMinutes(originStart, deltaMinutes),
        endAt: addMinutes(originEnd, deltaMinutes),
      });
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
    class="absolute flex flex-col items-start gap-0.5 overflow-hidden rounded-md border-l-4 pl-2 pr-1.5 py-1 text-left text-white shadow-sm transition-[opacity,box-shadow] select-none"
    :class="{
      'rounded-t-none': clippedAtStart,
      'rounded-b-none': clippedAtEnd,
      'cursor-grab': draggable && !isDragging,
      'cursor-grabbing': isDragging,
      'ring-2 ring-white/70 z-10': isDragging,
      'z-20 shadow-lg ring-1 ring-white/40 !opacity-100': isExpanded,
      'opacity-50': isPast,
      'outline-dashed outline-1 -outline-offset-1 outline-white/50': isTimeOff,
    }"
    :style="blockStyle"
    :title="`${event.title} (${timeRangeLabel()})`"
    @pointerenter="isHovered = true"
    @pointerleave="isHovered = false"
    @pointerdown="handleBlockPointerDown"
    @click="handleClick"
  >
    <!-- Estilo Outlook: titulo primeiro, quebrando linha (nunca cortado com
         reticencias), horario pequeno embaixo, numa linha so'. Se nao couber,
         o bloco cresce ao passar o mouse (ver blockStyle). -->
    <span
      class="flex items-start gap-1 w-full text-xs font-semibold leading-tight whitespace-normal break-words"
    >
      <span v-if="isTimeOff" class="shrink-0 mt-px i-lucide-palmtree size-3" />
      <span class="min-w-0">{{ event.title }}</span>
    </span>
    <span class="block w-full text-[10px] opacity-80 truncate">
      {{ timeRangeLabel() }}
    </span>

    <div
      v-if="draggable"
      class="absolute inset-x-0 bottom-0 h-1.5 cursor-ns-resize"
      @pointerdown="e => startDrag('resize', e)"
    />
  </button>
</template>
