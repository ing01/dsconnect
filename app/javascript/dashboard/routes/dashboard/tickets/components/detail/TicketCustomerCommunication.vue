<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import TicketFileInput from 'dashboard/routes/dashboard/tickets/components/create/TicketFileInput.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();

const body = ref('');
const isSending = ref(false);
// Enviar por e-mail e o caso comum, entao ja vem marcado. Desmarcado, a
// mensagem e apenas REGISTRADA: ela continua aparecendo para o cliente na Area
// do Cliente, e serve para quando a equipe ja falou com ele por telefone ou
// WhatsApp e quer deixar isso no chamado.
const notificarCliente = ref(true);
const attachments = ref([]);

// Messages that went TO the customer, kept apart from the internal thread.
const communications = computed(
  () => props.ticket.customer_communications || []
);
const email = computed(() => props.ticket.customer_email);

// O assunto nao aparece em lugar nenhum desta tela. Ele existe para o CLIENTE
// reconhecer a thread na caixa de entrada dele - aqui dentro, quem le ja esta
// no ticket, e repetir "#34 - [EMPRESA] | [Agente] | [titulo]" em cada linha so
// empurra a mensagem para baixo. Quem monta o assunto e o servidor
// (`ticket.display_subject`), e ele continua indo no cabecalho do e-mail.

const canSend = computed(() => !!email.value && !!body.value.trim());

// Modelos de mensagem: os mesmos Respostas Prontas usados no composer padrao
// do Chatwoot (Configuracoes > Respostas Prontas) - o FullEditor deste
// composer nao tem o menu "/" deles (e' o editor de artigos, outro
// schema/plugins), entao aqui entram por um botao dedicado em vez disso.
const isTemplateMenuOpen = ref(false);
const cannedResponses = computed(() => store.getters.getCannedResponses || []);
const templateMenuItems = computed(() =>
  cannedResponses.value.map(response => ({
    label: `/${response.short_code}`,
    description: response.content,
    value: response.id,
    action: 'insert',
    content: response.content,
  }))
);

const insertTemplate = item => {
  isTemplateMenuOpen.value = false;
  const separator = body.value.trim() ? '\n\n' : '';
  body.value = `${body.value}${separator}${item.content}`;
};

onMounted(() => {
  store.dispatch('getCannedResponse');
});

// `skipped` nao e falha nem pendencia - e a mensagem que ninguem mandou por
// e-mail de proposito. Cinza justamente por isso: nada a corrigir.
const STATUS_COLORS = {
  sent: 'teal',
  skipped: 'slate',
  failed: 'ruby',
  pending: 'amber',
};

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '—';

// O corpo vem em HTML: <br> e fim de paragrafo/item viram quebra de linha, o
// resto das tags sai, e as entidades basicas voltam a ser caractere.
const bodyToText = html =>
  String(html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li|h[1-6])>/gi, '\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

const send = async () => {
  if (!canSend.value || isSending.value) return;

  isSending.value = true;
  try {
    // Not a closing message: this is ordinary correspondence. Only the closing
    // flow marks one as such, and only that kind unlocks the close.
    await store.dispatch('tickets/sendCustomerCommunication', {
      ticketId: props.ticket.id,
      body: body.value,
      closing: false,
      notifyCustomer: notificarCliente.value,
      attachments: attachments.value,
    });
    body.value = '';
    attachments.value = [];
  } catch (error) {
    useAlert(error?.response?.data?.error || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSending.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4 min-w-0">
    <!-- Nothing can be sent without an address, so the composer is replaced by
         the reason rather than failing on submit. -->
    <p
      v-if="!email"
      class="flex items-start gap-2 p-3 text-sm rounded-lg text-n-amber-11 bg-n-amber-3"
    >
      <Icon icon="i-lucide-circle-alert" class="flex-shrink-0 size-4 mt-0.5" />
      {{ t('TICKET.CLOSE.NO_CONTACT_EMAIL') }}
    </p>

    <template v-else>
      <div
        class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak min-w-0"
      >
        <p class="text-sm text-n-slate-11">
          {{ t('TICKET.CLOSE.TO') }}:
          <span class="text-n-slate-12">{{ email }}</span>
        </p>

        <OnClickOutside
          class="relative w-fit"
          @trigger="isTemplateMenuOpen = false"
        >
          <Button
            faded
            slate
            size="sm"
            type="button"
            icon="i-lucide-message-square-text"
            :label="t('TICKET.COMMUNICATION.TEMPLATES.BUTTON')"
            @click="isTemplateMenuOpen = !isTemplateMenuOpen"
          />
          <DropdownMenu
            v-if="isTemplateMenuOpen"
            show-search
            :menu-items="templateMenuItems"
            :search-placeholder="t('TICKET.COMMUNICATION.TEMPLATES.SEARCH')"
            empty-state-message="TICKET.COMMUNICATION.TEMPLATES.EMPTY"
            class="mt-1 top-full w-80 max-h-72"
            @action="insertTemplate"
          >
            <template #label="{ item }">
              <span class="flex flex-col min-w-0 text-left">
                <span class="text-sm truncate font-420">{{ item.label }}</span>
                <span class="text-xs truncate text-n-slate-10">
                  {{ item.description }}
                </span>
              </span>
            </template>
          </DropdownMenu>
        </OnClickOutside>

        <FullEditor
          v-model="body"
          class="min-w-0 [&_.ProseMirror]:min-h-[8rem]"
          :placeholder="t('TICKET.CLOSE.MESSAGE_PLACEHOLDER')"
        />

        <TicketFileInput v-model="attachments" />

        <!-- A escolha fica JUNTO do botao, e nao no topo do bloco: e a ultima
             coisa decidida antes de enviar, e o rotulo do botao muda com ela. -->
        <div class="flex flex-wrap items-center justify-between gap-3 min-w-0">
          <label class="flex items-start gap-2 cursor-pointer min-w-0">
            <Checkbox v-model="notificarCliente" class="mt-0.5 flex-shrink-0" />
            <span class="flex flex-col gap-0.5 min-w-0">
              <span class="text-sm text-n-slate-12">
                {{ t('TICKET.COMMUNICATION.NOTIFY') }}
              </span>
              <span v-if="!notificarCliente" class="text-xs text-n-slate-10">
                {{ t('TICKET.COMMUNICATION.NOTIFY_HINT') }}
              </span>
            </span>
          </label>

          <Button
            size="sm"
            class="flex-shrink-0"
            :is-loading="isSending"
            :disabled="!canSend"
            :label="
              notificarCliente
                ? t('TICKET.COMMUNICATION.SEND')
                : t('TICKET.COMMUNICATION.REGISTER')
            "
            @click="send"
          />
        </div>
      </div>
    </template>

    <div class="flex flex-col gap-2 min-w-0">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.COMMUNICATION.HISTORY') }}
      </h3>

      <p v-if="!communications.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.COMMUNICATION.EMPTY') }}
      </p>

      <ul v-else class="flex flex-col gap-2 min-w-0">
        <li
          v-for="communication in communications"
          :key="communication.id"
          class="flex flex-col gap-1 p-3 border rounded-lg border-n-weak min-w-0"
        >
          <div class="flex flex-wrap items-center gap-2 min-w-0">
            <span class="text-xs text-n-slate-10">
              {{
                formatDate(communication.sent_at || communication.created_at)
              }}
            </span>
            <!-- A conversa tem dois sentidos: o que a equipe enviou ao cliente
                 e o que ele respondeu pela Area do Cliente. Sem distinguir, a
                 resposta recebida apareceria como "null → null". -->
            <span class="text-xs truncate text-n-slate-11">
              {{
                communication.direction === 'inbound'
                  ? t('TICKET.COMMUNICATION.FROM_CUSTOMER', {
                      name:
                        communication.author_name || communication.contact_name,
                    })
                  : `${communication.user_name || t('TICKET.COMMUNICATION.AUTOMATED')} → ${communication.to_email}`
              }}
            </span>
            <WootLabel
              v-if="communication.direction !== 'inbound'"
              :label="
                t(
                  `TICKET.COMMUNICATION.STATUS.${communication.status.toUpperCase()}`
                )
              "
              :color="STATUS_COLORS[communication.status] || 'slate'"
              compact
            />
            <WootLabel
              v-if="communication.closing"
              :label="t('TICKET.COMMUNICATION.CLOSING')"
              color="blue"
              compact
            />
          </div>

          <!-- O corpo e o texto do agente, ja higienizado na saida; mostrado
               como texto puro para a lista ficar compacta. Sem o assunto acima:
               ele e igual em todas as linhas e nao distingue uma da outra. Por
               isso o corpo herda o destaque que era do titulo - e ele que diz
               qual comunicacao e qual. Aparece INTEIRO e com as quebras de
               linha que o agente escreveu: cortado em uma linha, nao dava para
               conferir o que foi enviado ao cliente. -->
          <p
            class="m-0 text-sm break-words whitespace-pre-line text-n-slate-12"
          >
            {{ bodyToText(communication.body) }}
          </p>

          <p v-if="communication.error_message" class="text-xs text-n-ruby-11">
            {{ communication.error_message }}
          </p>

          <ul
            v-if="communication.attachments?.length"
            class="flex flex-wrap gap-2 m-0"
          >
            <li v-for="anexo in communication.attachments" :key="anexo.id">
              <a
                :href="anexo.file_url"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1.5 px-2 py-1 text-xs border rounded-md border-n-weak text-n-slate-11 hover:text-n-brand"
              >
                <Icon icon="i-lucide-paperclip" class="size-3" />
                {{ anexo.filename }}
              </a>
            </li>
          </ul>
        </li>
      </ul>
    </div>
  </div>
</template>
