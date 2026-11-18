<script setup>
/**
 * Uma linha da arvore (pasta ou artigo) e, recursivamente, as linhas de dentro dela.
 * Arrastar um artigo e soltar sobre uma pasta ou sobre outro artigo o reorganiza; o menu "..."
 * traz o mesmo por teclado/clique (Mover para..., Subir, Descer).
 */
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { NODE_TYPE, dropAction } from './articleTreeHelper';

const props = defineProps({
  node: { type: Object, required: true },
  depth: { type: Number, default: 0 },
  expandedKeys: { type: Object, required: true },
  selectedArticleId: { type: Number, default: null },
  canManage: { type: Boolean, default: false },
  dragged: { type: Object, default: null },
});

const emit = defineEmits([
  'toggle',
  'select',
  'dragStart',
  'dragEnd',
  'drop',
  'action',
]);

const { t } = useI18n();

const menuOpen = ref(false);
const isDropOver = ref(false);

const isFolder = computed(() => props.node.type === NODE_TYPE.FOLDER);
const hasChildren = computed(() => props.node.children.length > 0);
const isExpanded = computed(() => props.expandedKeys.has(props.node.key));
const isSelected = computed(
  () => !isFolder.value && props.node.id === props.selectedArticleId
);
const canDrag = computed(() => props.canManage && !isFolder.value);
const isDraft = computed(
  () => !isFolder.value && props.node.status !== 'published'
);

// So' destaca como alvo quando soltar aqui faz algo.
const canDropHere = computed(
  () => !!props.dragged && !!dropAction(props.dragged, props.node)
);

const icon = computed(() => {
  if (isFolder.value) {
    return isExpanded.value ? 'i-lucide-folder-open' : 'i-lucide-folder';
  }
  return 'i-lucide-file-text';
});

const menuItems = computed(() => {
  if (isFolder.value) {
    if (props.node.virtual) return [];
    return [
      {
        label: t('HELP_CENTER.KB_TREE.NEW_ARTICLE'),
        value: 'new-article',
        action: 'new-article',
        icon: 'i-lucide-file-plus',
      },
      {
        label: t('HELP_CENTER.KB_TREE.NEW_SUBFOLDER'),
        value: 'new-subfolder',
        action: 'new-subfolder',
        icon: 'i-lucide-folder-plus',
      },
    ];
  }
  return [
    {
      label: t('HELP_CENTER.KB_TREE.NEW_CHILD'),
      value: 'new-child',
      action: 'new-child',
      icon: 'i-lucide-corner-down-right',
    },
    {
      label: t('HELP_CENTER.KB_TREE.MENU.EDIT'),
      value: 'edit',
      action: 'edit',
      icon: 'i-lucide-pencil',
    },
    {
      label: t('HELP_CENTER.KB_TREE.MENU.MOVE'),
      value: 'move',
      action: 'move',
      icon: 'i-lucide-folder-input',
    },
    {
      label: t('HELP_CENTER.KB_TREE.MENU.UP'),
      value: 'up',
      action: 'up',
      icon: 'i-lucide-arrow-up',
    },
    {
      label: t('HELP_CENTER.KB_TREE.MENU.DOWN'),
      value: 'down',
      action: 'down',
      icon: 'i-lucide-arrow-down',
    },
  ];
});

const onClick = () => {
  if (isFolder.value) {
    emit('toggle', props.node.key);
    return;
  }
  emit('select', props.node);
};

const onChevron = event => {
  event.stopPropagation();
  emit('toggle', props.node.key);
};

const onMenuAction = ({ action }) => {
  menuOpen.value = false;
  emit('action', { action, node: props.node });
};

const onDragStart = event => {
  if (!canDrag.value) return;
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', String(props.node.id));
  emit('dragStart', props.node);
};

const onDragOver = event => {
  if (!canDropHere.value) return;
  event.preventDefault();
  isDropOver.value = true;
};

const onDrop = event => {
  isDropOver.value = false;
  if (!canDropHere.value) return;
  event.preventDefault();
  emit('drop', props.node);
};
</script>

<template>
  <li role="none">
    <div
      role="treeitem"
      :aria-expanded="hasChildren ? isExpanded : undefined"
      :aria-selected="isSelected"
      :draggable="canDrag"
      class="group relative flex items-center gap-1.5 py-1.5 pe-1.5 rounded-lg cursor-pointer select-none text-sm"
      :class="[
        isSelected
          ? 'bg-n-blue-3 text-n-blue-11 font-medium'
          : 'text-n-slate-12 hover:bg-n-alpha-2',
        isDropOver && canDropHere ? 'outline outline-2 outline-n-brand' : '',
      ]"
      :style="{ paddingInlineStart: `${depth * 16 + 6}px` }"
      :title="canDrag ? t('HELP_CENTER.KB_TREE.MENU.DRAG') : undefined"
      @click="onClick"
      @dragstart="onDragStart"
      @dragend="emit('dragEnd')"
      @dragover="onDragOver"
      @dragleave="isDropOver = false"
      @drop="onDrop"
    >
      <button
        v-if="hasChildren"
        type="button"
        class="grid flex-shrink-0 rounded size-5 place-items-center text-n-slate-11 hover:bg-n-alpha-2"
        :aria-label="
          isExpanded
            ? t('HELP_CENTER.KB_TREE.MENU.COLLAPSE')
            : t('HELP_CENTER.KB_TREE.MENU.EXPAND')
        "
        @click="onChevron"
      >
        <Icon
          :icon="
            isExpanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'
          "
          class="size-3.5"
        />
      </button>
      <span v-else class="flex-shrink-0 size-5" />
      <Icon
        :icon="icon"
        class="flex-shrink-0 size-4"
        :class="isFolder ? 'text-n-amber-10' : 'text-n-slate-11'"
      />
      <span
        class="min-w-0 truncate"
        :class="[isFolder ? 'font-medium' : '', isDraft ? 'opacity-70' : '']"
      >
        {{ node.title }}
      </span>
      <span
        v-if="isDraft"
        class="flex-shrink-0 px-1.5 text-[10px] rounded bg-n-alpha-2 text-n-slate-11"
      >
        {{ t('HELP_CENTER.KB_TREE.STATUS.DRAFT') }}
      </span>

      <div
        v-if="canManage && menuItems.length"
        class="relative flex-shrink-0 ms-auto"
        @click.stop
      >
        <OnClickOutside @trigger="menuOpen = false">
          <button
            type="button"
            class="grid rounded size-6 place-items-center text-n-slate-11 hover:bg-n-alpha-3 opacity-0 group-hover:opacity-100 focus:opacity-100"
            :class="menuOpen ? '!opacity-100' : ''"
            :aria-label="t('HELP_CENTER.KB_TREE.MENU.MORE')"
            @click="menuOpen = !menuOpen"
          >
            <Icon icon="i-lucide-ellipsis" class="size-4" />
          </button>
          <DropdownMenu
            v-if="menuOpen"
            :menu-items="menuItems"
            class="end-0 z-20 w-48 mt-1 top-full"
            @action="onMenuAction"
          />
        </OnClickOutside>
      </div>
    </div>

    <ul v-if="hasChildren && isExpanded" role="group" class="m-0 list-none">
      <ArticleTreeNode
        v-for="child in node.children"
        :key="child.key"
        :node="child"
        :depth="depth + 1"
        :expanded-keys="expandedKeys"
        :selected-article-id="selectedArticleId"
        :can-manage="canManage"
        :dragged="dragged"
        @toggle="key => emit('toggle', key)"
        @select="selected => emit('select', selected)"
        @drag-start="dragNode => emit('dragStart', dragNode)"
        @drag-end="emit('dragEnd')"
        @drop="target => emit('drop', target)"
        @action="payload => emit('action', payload)"
      />
    </ul>
  </li>
</template>
