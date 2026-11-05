<script setup>
/**
 * O botão de "+" do menu lateral: antes abria direto "Nova conversa"; agora
 * vira um menu com "Nova conversa" e "Novo ticket", ao lado da busca de
 * chamado (ver SidebarTicketSearch.vue).
 *
 * Fica num componente próprio, e não dentro do Sidebar.vue, pelo mesmo motivo
 * do SidebarTicketSearch: aquele arquivo passa de mil linhas e é mexido com
 * frequência - quanto menor o rastro lá, menos conflito na próxima mesclagem.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { useMapGetter } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import TicketCreateDialog from 'dashboard/routes/dashboard/tickets/components/create/TicketCreateDialog.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const { t } = useI18n();
const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');

const composeConversationRef = ref(null);
const showMenu = ref(false);
const showTicketDialog = ref(false);

const toggleMenu = () => {
  showMenu.value = !showMenu.value;
};
const closeMenu = () => {
  showMenu.value = false;
};

const chooseConversation = () => {
  closeMenu();
  composeConversationRef.value?.show();
};

const chooseTicket = () => {
  closeMenu();
  showTicketDialog.value = true;
};

const closeTicketDialog = () => {
  showTicketDialog.value = false;
};

const onTicketCreated = ({ ticket }) => {
  closeTicketDialog();
  router.push(frontendURL(`accounts/${accountId.value}/tickets/${ticket.id}`));
};
</script>

<template>
  <div class="relative">
    <ComposeConversation ref="composeConversationRef" align="start">
      <template #trigger="{ isOpen }">
        <Button
          icon="i-lucide-pen-line"
          color="slate"
          size="sm"
          class="dark:hover:!bg-n-slate-9/30"
          :class="[
            isCollapsed
              ? '!size-8 !outline-n-weak !text-n-slate-11'
              : '!h-7 !outline-n-weak !text-n-slate-11',
            { '!bg-n-alpha-2 dark:!bg-n-slate-9/30': isOpen || showMenu },
          ]"
          @click.stop="toggleMenu"
        />
      </template>
    </ComposeConversation>

    <div
      v-if="showMenu"
      v-on-clickaway="closeMenu"
      class="border rounded-lg shadow-lg border-n-strong dark:border-n-strong box-content p-2 w-fit z-20 bg-n-alpha-3 backdrop-blur-[100px] absolute block left-auto top-full mt-0.5 end-0 max-w-[12.5rem] min-w-[9.75rem] [&_ul>li]:mb-0"
    >
      <WootDropdownMenu class="mb-0">
        <WootDropdownItem>
          <Button
            :label="t('CHAT_LIST.NEW_CONVERSATION_BUTTON')"
            ghost
            slate
            sm
            start
            icon="i-lucide-message-circle-plus"
            class="w-full"
            @click="chooseConversation"
          />
        </WootDropdownItem>
        <WootDropdownItem>
          <Button
            :label="t('TICKET.BOARD.ADD_TICKET')"
            ghost
            slate
            sm
            start
            icon="i-lucide-ticket-plus"
            class="w-full"
            @click="chooseTicket"
          />
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>

    <woot-modal
      v-model:show="showTicketDialog"
      :on-close="closeTicketDialog"
      size="large"
    >
      <TicketCreateDialog
        :context="{}"
        @close="closeTicketDialog"
        @created="onTicketCreated"
      />
    </woot-modal>
  </div>
</template>
