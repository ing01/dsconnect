<script>
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { format, parseISO, isPast } from 'date-fns';
import { statusColor, priorityColor } from '../helpers/ticketLabels';

export default {
  components: {
    WootLabel,
    Icon,
    NextButton,
    DropdownMenu,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
    agents: {
      type: Array,
      default: () => [],
    },
  },
  // The menu now carries its intent in one event: the card names the action,
  // the page decides how to run it.
  emits: ['click', 'menuAction'],
  data() {
    return {
      showMenu: false,
      // Posicao do menu na janela. Ele e desenhado fora do card (vide o
      // Teleport no template), entao precisa saber onde o botao esta.
      menuStyle: {},
    };
  },
  computed: {
    priorityColor() {
      return priorityColor(this.ticket.priority);
    },
    priorityLabel() {
      return this.ticket.priority
        ? this.$t(`TICKET.FORM.PRIORITY.${this.ticket.priority.toUpperCase()}`)
        : '';
    },
    statusColor() {
      return statusColor(this.ticket.status);
    },
    statusLabel() {
      return this.ticket.status
        ? this.$t(`TICKET.STATUS.${this.ticket.status.toUpperCase()}`)
        : '';
    },
    assigneeName() {
      const agent = this.agents.find(a => a.id === this.ticket.assignee_id);
      return agent?.name || '';
    },
    conversationCount() {
      return this.ticket.conversation_ids?.length || 0;
    },
    dueDateLabel() {
      return this.ticket.due_date
        ? format(parseISO(this.ticket.due_date), 'dd/MM HH:mm')
        : '';
    },
    isOverdue() {
      return (
        this.ticket.status === 'open' &&
        !!this.ticket.due_date &&
        isPast(parseISO(this.ticket.due_date))
      );
    },
    scheduledAtLabel() {
      return this.ticket.scheduled_at
        ? format(parseISO(this.ticket.scheduled_at), 'dd/MM HH:mm')
        : '';
    },
    menuItems() {
      // The operational actions, all of them already implemented elsewhere in
      // the module - the card only names them and the page wires them up.
      // `open` is gone on purpose: clicking the card already opens the ticket.
      // So are `edit` and `resolve`: editing happens inside the ticket, and
      // closing is what represents the end of an attendance.
      const items = [];

      if (this.ticket.status === 'open') {
        items.push(
          {
            label: this.$t('TICKET.CARD.MENU.ASSIGN_TO_ME'),
            action: 'assignToMe',
            value: 'assignToMe',
            icon: 'i-lucide-user-check',
          },
          {
            label: this.$t('TICKET.CARD.MENU.SEND_COMMUNICATION'),
            action: 'sendCommunication',
            value: 'sendCommunication',
            icon: 'i-lucide-mail',
          },
          {
            label: this.$t('TICKET.CARD.MENU.MERGE'),
            action: 'merge',
            value: 'merge',
            icon: 'i-lucide-combine',
          },
          {
            label: this.$t('TICKET.CARD.MENU.CREATE_CHILD'),
            action: 'createChild',
            value: 'createChild',
            icon: 'i-lucide-git-branch-plus',
          },
          {
            label: this.$t('TICKET.CARD.MENU.TRANSFER'),
            action: 'transfer',
            value: 'transfer',
            icon: 'i-lucide-arrow-right-left',
          },
          // `action: 'delete'` is what DropdownMenu paints in ruby, which is how
          // the closing entry reads as the end of the attendance.
          {
            label: this.$t('TICKET.CARD.MENU.CLOSE'),
            action: 'delete',
            value: 'close',
            icon: 'i-lucide-circle-x',
          }
        );
      } else {
        // A terminal ticket is off the operational board; reopening is all that
        // is left to do with it.
        items.push({
          label: this.$t('TICKET.CARD.MENU.REOPEN'),
          action: 'reopen',
          value: 'reopen',
          icon: 'i-lucide-rotate-ccw',
        });
      }

      return items;
    },
  },
  beforeUnmount() {
    // O card some quando o ticket muda de coluna; os ouvintes da janela nao
    // podem sobreviver a ele.
    this.closeMenu();
  },
  methods: {
    toggleMenu() {
      if (this.showMenu) return this.closeMenu();

      this.positionMenu();
      this.showMenu = true;
      // A posicao e tirada uma vez, na abertura: rolar a coluna ou a pagina a
      // deixaria errada, e reposicionar a cada quadro custaria mais do que
      // simplesmente fechar.
      window.addEventListener('scroll', this.closeMenu, true);
      window.addEventListener('resize', this.closeMenu);
      return undefined;
    },
    // Ancorado pela janela, e nao pelo card: a coluna do Kanban rola e recorta
    // o que passa das bordas dela, entao um menu preso ao card fica cortado
    // quando a coluna tem poucos cartoes.
    positionMenu() {
      const trigger = this.$refs.menuTrigger?.$el || this.$refs.menuTrigger;
      if (!trigger?.getBoundingClientRect) return;

      const rect = trigger.getBoundingClientRect();
      const MENU_WIDTH = 192;
      const ESTIMATED_HEIGHT = 260;
      // Abre para cima quando nao ha espaco abaixo, para o menu nunca ficar
      // dependendo de rolagem para ser lido inteiro.
      const opensUpward =
        rect.bottom + ESTIMATED_HEIGHT > window.innerHeight &&
        rect.top > ESTIMATED_HEIGHT;

      this.menuStyle = {
        position: 'fixed',
        // Alinhado pela direita do botao, e preso na janela quando o card esta
        // proximo da borda esquerda.
        left: `${Math.max(8, rect.right - MENU_WIDTH)}px`,
        [opensUpward ? 'bottom' : 'top']: opensUpward
          ? `${window.innerHeight - rect.top + 4}px`
          : `${rect.bottom + 4}px`,
        zIndex: 50,
      };
    },
    closeMenu() {
      this.showMenu = false;
      window.removeEventListener('scroll', this.closeMenu, true);
      window.removeEventListener('resize', this.closeMenu);
    },
    onMenuAction({ value }) {
      this.closeMenu();
      this.$emit('menuAction', { action: value, ticket: this.ticket });
    },
  },
};
</script>

<template>
  <div
    class="drag-handle group relative flex flex-col gap-2 rounded-xl border border-n-weak bg-n-solid-1 p-3 cursor-pointer hover:border-n-slate-6 hover:shadow-sm transition-shadow"
    @click="$emit('click', ticket)"
  >
    <div class="flex items-start justify-between gap-2">
      <p class="text-sm font-medium text-n-slate-12 line-clamp-2">
        <span v-if="ticket.display_id" class="text-n-slate-10 font-normal">
          #{{ ticket.display_id }}
        </span>
        {{ ticket.title }}
      </p>
      <div class="flex-shrink-0">
        <NextButton
          ref="menuTrigger"
          icon="i-lucide-ellipsis-vertical"
          color="slate"
          variant="ghost"
          size="xs"
          class="opacity-0 group-hover:opacity-100"
          :class="showMenu ? 'opacity-100' : ''"
          @click.stop="toggleMenu"
        />
        <!-- Fora do card de proposito: dentro dele o menu e recortado pela
             rolagem da coluna. -->
        <Teleport to="body">
          <DropdownMenu
            v-if="showMenu"
            v-on-clickaway="closeMenu"
            :menu-items="menuItems"
            :style="menuStyle"
            class="w-48"
            @click.stop
            @action="onMenuAction"
          />
        </Teleport>
      </div>
    </div>

    <p
      v-if="ticket.company_name"
      class="text-xs text-n-slate-11 truncate"
      :title="ticket.company_name"
    >
      {{ ticket.company_name }}
    </p>

    <div class="flex items-center flex-wrap gap-1.5">
      <!-- Impedido vem primeiro entre os selos: e a informacao que muda o
             que a pessoa faz com o cartao. Status e prioridade continuam ali,
             porque o ticket segue aberto. -->
      <WootLabel
        v-if="ticket.blocked"
        :label="$t('TICKET.IMPEDIMENT.LABEL')"
        color="amber"
        compact
      />
      <WootLabel
        v-if="ticket.status"
        :label="statusLabel"
        :color="statusColor"
        compact
      />
      <WootLabel
        v-if="ticket.priority"
        :label="priorityLabel"
        :color="priorityColor"
        compact
      />
      <span v-if="!ticket.priority" class="text-xs text-n-slate-10">
        {{ $t('TICKET.FORM.PRIORITY.NONE') }}
      </span>
    </div>

    <div
      v-if="dueDateLabel || scheduledAtLabel"
      class="flex items-center flex-wrap gap-x-3 gap-y-1"
    >
      <span
        v-if="dueDateLabel"
        class="flex items-center gap-1 text-xs"
        :class="isOverdue ? 'text-n-ruby-11 font-medium' : 'text-n-slate-11'"
      >
        <Icon icon="i-lucide-calendar-clock" class="size-3.5" />
        {{ $t('TICKET.CARD.DUE_DATE') }}: {{ dueDateLabel }}
        <span v-if="isOverdue">({{ $t('TICKET.CARD.OVERDUE') }})</span>
      </span>
      <span
        v-if="scheduledAtLabel"
        class="flex items-center gap-1 text-xs text-n-slate-11"
      >
        <Icon icon="i-lucide-calendar" class="size-3.5" />
        {{ $t('TICKET.CARD.SCHEDULED_AT') }}: {{ scheduledAtLabel }}
      </span>
    </div>

    <div class="flex items-center justify-between gap-2">
      <div v-if="assigneeName" class="flex items-center gap-1.5 min-w-0">
        <span
          class="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-slate-4 text-[10px] font-medium text-n-slate-12"
        >
          {{ assigneeName.charAt(0).toUpperCase() }}
        </span>
        <span class="text-xs text-n-slate-11 truncate">{{ assigneeName }}</span>
      </div>
      <div v-else />

      <div
        v-if="conversationCount"
        class="flex items-center gap-1 text-xs text-n-slate-11 flex-shrink-0"
      >
        <Icon icon="i-lucide-message-circle" class="size-3.5" />
        {{ conversationCount }}
      </div>
    </div>
  </div>
</template>
