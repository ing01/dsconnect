<script setup>
import { isVNode, computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import Policy from 'dashboard/components/policy.vue';
import { useSidebarContext } from './provider';
import SidebarUnreadBadge from './SidebarUnreadBadge.vue';

const props = defineProps({
  label: { type: String, required: true },
  to: { type: [String, Object], default: null },
  // Item que abre uma URL fora do painel (ex.: "Atualizador automatico") -
  // sem rota do Vue Router, entao vira um <a> comum em vez de <router-link>.
  href: { type: String, default: null },
  icon: { type: [String, Object], default: null },
  active: { type: Boolean, default: false },
  component: { type: Function, default: null },
  badgeCount: { type: [Number, String], default: 0 },
  hideTreeLine: { type: Boolean, default: false },
  thinTreeLine: { type: Boolean, default: false },
  // Menu recolhido: so o icone, com o nome no `title`. Padrao `false`, entao
  // nenhum uso existente muda.
  collapsed: { type: Boolean, default: false },
});

const { resolvePermissions, resolveFeatureFlag } = useSidebarContext();

const shouldRenderComponent = computed(() => {
  return typeof props.component === 'function' || isVNode(props.component);
});

// Tree-line connector per leaf: vertical line (::before) + rounded elbow on the
// last child (::after). Logical props (start / border-s / rounded-es)
const TREE_CONNECTOR =
  "child-item before:content-[''] before:absolute before:start-0 before:w-0.5 before:h-full before:bg-n-slate-4 first:before:rounded-t last:before:h-1/5 last:after:content-[''] last:after:absolute last:after:start-0 last:after:bottom-[calc(50%_-_2px)] last:after:h-3 last:after:w-2.5 last:after:border-b-2 last:after:border-s-2 last:after:rounded-es last:after:border-n-slate-4";
</script>

<template>
  <Policy
    :permissions="resolvePermissions(to)"
    :feature-flag="resolveFeatureFlag(to)"
    as="li"
    class="py-0.5 ps-2 ms-3 relative text-n-slate-11 min-w-0"
    :class="{
      [TREE_CONNECTOR]: !hideTreeLine,
      'before:!w-px last:after:!border-b last:after:!border-s':
        !hideTreeLine && thinTreeLine,
    }"
  >
    <component
      :is="href ? 'a' : to ? 'router-link' : 'div'"
      :to="href ? undefined : to"
      :href="href || undefined"
      :target="href ? '_blank' : undefined"
      :rel="href ? 'noopener noreferrer' : undefined"
      :title="label"
      class="flex h-9 items-center gap-2 px-2 py-1 rounded-lg ltr:hover:bg-gradient-to-r rtl:hover:bg-gradient-to-l from-transparent via-n-slate-3/70 to-n-slate-3/70 group min-w-0"
      :class="{
        'text-n-slate-12 bg-n-alpha-2 active': active,
        'justify-center': collapsed,
      }"
    >
      <component
        :is="component"
        v-if="shouldRenderComponent"
        v-bind="{ label, icon, active, badgeCount }"
      />
      <template v-else>
        <span v-if="icon" class="size-5 grid place-content-center rounded-full">
          <Icon :icon="icon" class="size-5 inline-block" />
        </span>
        <div v-if="!collapsed" class="flex-1 truncate min-w-0 text-base">
          {{ label }}
        </div>
        <SidebarUnreadBadge v-if="!collapsed" :count="badgeCount" />
      </template>
    </component>
  </Policy>
</template>
