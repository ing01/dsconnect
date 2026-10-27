<script setup>
/**
 * O chamado aberto, do lado do cliente.
 *
 * Quatro abas: Informações gerais, Comunicação, Compromissos e Checklist.
 * Compromissos e Checklist são de leitura - não é que os botões estejam
 * escondidos, é que não existem, e o servidor também não expõe rota para eles.
 *
 * A aba Comunicação é a conversa COM a equipe, nos dois sentidos: o que foi
 * enviado ao cliente e o que ele responde daqui. Os comentários internos
 * (`ticket_comments`) são a conversa da equipe SOBRE o atendimento e não saem
 * do servidor em hipótese alguma.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import { downloadBlob } from 'dashboard/helper/downloadHelper';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import TicketFileInput from 'dashboard/routes/dashboard/tickets/components/create/TicketFileInput.vue';
import {
  statusColor,
  priorityColor,
} from 'dashboard/routes/dashboard/tickets/helpers/ticketLabels';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const ticket = ref(null);
const isLoading = ref(true);
const activeTab = ref('overview');
// A resposta que o cliente está escrevendo, e os arquivos que vão com ela.
const resposta = ref('');
const arquivos = ref([]);
const isSending = ref(false);

const TABS = [
  'overview',
  'communication',
  'valuation',
  'appointments',
  'checklist',
];

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '—';

const data = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleDateString() : '—';

const communications = computed(() => ticket.value?.communications || []);
const proposals = computed(() => ticket.value?.proposals || []);
const appointments = computed(() => ticket.value?.appointments || []);
const checklistItems = computed(() => ticket.value?.checklist_items || []);

// A contagem ao lado do nome da aba evita o clique só para descobrir que está
// vazia.
const tabCount = tab => {
  if (tab === 'communication') return communications.value.length;
  if (tab === 'valuation') return proposals.value.length;
  if (tab === 'appointments') return appointments.value.length;
  if (tab === 'checklist') return checklistItems.value.length;
  return null;
};

const concluidos = computed(
  () => checklistItems.value.filter(item => item.completed).length
);

const infoRows = computed(() => {
  if (!ticket.value) return [];
  return [
    { label: t('CLIENT_AREA.DETAIL.FIELDS.STATUS'), value: null, status: true },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.STAGE'),
      value: ticket.value.ticket_column_name,
    },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.TEAM'),
      value: ticket.value.team_name,
    },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.CATEGORY'),
      value: ticket.value.category_name || '—',
    },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.REQUESTED_BY'),
      value: ticket.value.requested_by || '—',
    },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.CREATED_AT'),
      value: dataHora(ticket.value.created_at),
    },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.DUE_DATE'),
      value: data(ticket.value.due_date),
    },
    {
      label: t('CLIENT_AREA.DETAIL.FIELDS.CLOSED_AT'),
      value: dataHora(ticket.value.closed_at),
    },
  ];
});

const carregar = async () => {
  isLoading.value = true;
  try {
    const { data: payload } = await ClientAreaAPI.ticket(route.params.ticketId);
    ticket.value = payload;
  } catch {
    // Um id que não é dele responde 404 no servidor; aqui isso vira "não
    // encontrado" e a volta para o quadro.
    useAlert(t('CLIENT_AREA.DETAIL.NOT_FOUND'));
    router.replace({ name: 'client_tickets' });
  } finally {
    isLoading.value = false;
  }
};

const podeEnviar = computed(
  () => resposta.value.trim().length > 0 && !isSending.value
);

// A mensagem entra na MESMA conversa que a equipe usa; não há thread separada
// para o cliente.
const enviar = async () => {
  if (!podeEnviar.value) return;

  isSending.value = true;
  try {
    await ClientAreaAPI.sendCommunication(
      route.params.ticketId,
      resposta.value.trim(),
      arquivos.value
    );
    resposta.value = '';
    arquivos.value = [];
    useAlert(t('CLIENT_AREA.DETAIL.COMMUNICATION.SENT'));
    // Relê o chamado: a mensagem recém-enviada precisa aparecer no histórico
    // vinda do servidor, e não montada aqui.
    await carregar();
    activeTab.value = 'communication';
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('CLIENT_AREA.DETAIL.COMMUNICATION.SEND_ERROR')
    );
  } finally {
    isSending.value = false;
  }
};

const dinheiro = valor =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    Number(valor)
  );

// "2026-10-27" vira "27/10/2026" sem passar por Date, que deslocaria o dia pelo
// fuso do navegador.
const diaSimples = valor => valor.split('-').reverse().join('/');

const PROPOSAL_STATUS_COLOR = {
  pending: 'amber',
  approved: 'teal',
  refused: 'ruby',
};

// O "Certeza?": o primeiro clique só pede confirmação, e é o segundo que
// decide. `confirmando` guarda qual proposta e qual decisão aguardam.
const confirmando = ref(null);
const decidindo = ref(false);

const pedirConfirmacao = (proposal, decision) => {
  confirmando.value = { id: proposal.id, decision };
};

const baixarProposta = async proposal => {
  try {
    const pdf = await ClientAreaAPI.proposalPdf(
      route.params.ticketId,
      proposal.id
    );
    downloadBlob(
      pdf.data,
      `proposta-${proposal.id}.pdf`,
      pdf.headers?.['content-disposition']
    );
  } catch {
    useAlert(t('CLIENT_AREA.DETAIL.PROPOSALS.PDF_ERROR'));
  }
};

// A decisão vale uma única vez: o servidor recusa a segunda (409) e a tela
// relê o chamado em qualquer caso, para mostrar o que ficou gravado.
const decidir = async () => {
  if (!confirmando.value || decidindo.value) return;

  decidindo.value = true;
  const { id, decision } = confirmando.value;
  try {
    await ClientAreaAPI.decideProposal(route.params.ticketId, id, decision);
    useAlert(t(`CLIENT_AREA.DETAIL.PROPOSALS.DONE_${decision.toUpperCase()}`));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('CLIENT_AREA.DETAIL.PROPOSALS.DECIDE_ERROR')
    );
  } finally {
    confirmando.value = null;
    decidindo.value = false;
    await carregar();
  }
};

const voltar = () => router.push({ name: 'client_tickets' });

onMounted(carregar);
</script>

<template>
  <div class="flex flex-col flex-1 h-full min-h-0 gap-4 p-4 min-w-0 sm:p-6">
    <div v-if="isLoading" class="flex justify-center py-16 text-n-slate-10">
      <Spinner />
    </div>

    <template v-else-if="ticket">
      <div class="flex flex-wrap items-start flex-shrink-0 gap-3">
        <Button
          faded
          slate
          size="sm"
          icon="i-lucide-arrow-left"
          :label="t('CLIENT_AREA.DETAIL.BACK')"
          @click="voltar"
        />
        <div class="flex flex-col min-w-0">
          <span class="text-xs text-n-slate-10">#{{ ticket.display_id }}</span>
          <h1 class="m-0 text-lg font-medium text-n-slate-12">
            {{ ticket.title }}
          </h1>
        </div>
        <div
          class="flex flex-wrap items-center gap-1.5 ltr:ml-auto rtl:mr-auto"
        >
          <!-- Aguardando triagem: o Estágio mostrado é provisório até a equipe
               aceitar o chamado. -->
          <Label
            v-if="ticket.pending_triage"
            :label="t('CLIENT_AREA.DETAIL.PENDING_TRIAGE')"
            color="amber"
            size="small"
          />
          <Label
            :label="t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
            :color="statusColor(ticket.status)"
            size="small"
          />
          <Label
            v-if="ticket.priority"
            :label="t(`TICKET.FORM.PRIORITY.${ticket.priority.toUpperCase()}`)"
            :color="priorityColor(ticket.priority)"
            size="small"
          />
        </div>
      </div>

      <!-- `flex-shrink-0` aqui é o que mantém as abas visíveis: num flex em
           coluna o encolhimento age na altura, e uma descrição longa espremia
           esta faixa até sobrar apenas a barra de rolagem.
           No celular as abas não cabem lado a lado - daí rolarem na horizontal,
           com cada uma mantendo o próprio tamanho. -->
      <div
        class="flex flex-shrink-0 gap-1 p-1 overflow-x-auto rounded-lg bg-n-alpha-2 w-fit max-w-full no-scrollbar"
      >
        <button
          v-for="tab in TABS"
          :key="tab"
          type="button"
          class="px-3 py-1.5 text-sm rounded-md whitespace-nowrap transition-colors flex-shrink-0"
          :class="
            activeTab === tab
              ? 'bg-n-solid-1 text-n-slate-12 font-medium'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeTab = tab"
        >
          {{ t(`CLIENT_AREA.DETAIL.TABS.${tab.toUpperCase()}`) }}
          <span v-if="tabCount(tab) !== null" class="text-n-slate-10">
            ({{ tabCount(tab) }})
          </span>
        </button>
      </div>

      <!-- INFORMAÇÕES GERAIS -->
      <section
        v-if="activeTab === 'overview'"
        class="flex flex-col flex-1 min-h-0 gap-4 overflow-y-auto"
      >
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div
            v-for="row in infoRows"
            :key="row.label"
            class="flex flex-col gap-1 p-3 border rounded-lg border-n-weak"
          >
            <span class="text-xs text-n-slate-10">{{ row.label }}</span>
            <Label
              v-if="row.status"
              :label="t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
              :color="statusColor(ticket.status)"
              size="small"
              class="self-start"
            />
            <span v-else class="text-sm break-words text-n-slate-12">
              {{ row.value }}
            </span>
          </div>
        </div>

        <div class="flex flex-col gap-2 p-4 border rounded-lg border-n-weak">
          <h2 class="m-0 text-sm font-medium text-n-slate-12">
            {{ t('CLIENT_AREA.DETAIL.DESCRIPTION') }}
          </h2>
          <p class="m-0 text-sm whitespace-pre-line text-n-slate-11">
            {{ ticket.description || t('CLIENT_AREA.DETAIL.NO_DESCRIPTION') }}
          </p>
        </div>
      </section>

      <!-- COMUNICAÇÃO: apenas o que foi enviado ao cliente -->
      <section
        v-else-if="activeTab === 'communication'"
        class="flex flex-col flex-1 min-h-0 gap-4 overflow-y-auto"
      >
        <!-- Responder fica ANTES do histórico: é a ação, e o histórico é a
             leitura. -->
        <div class="flex flex-col gap-2 p-4 border rounded-lg border-n-weak">
          <h3 class="m-0 text-sm font-medium text-n-slate-12">
            {{ t('CLIENT_AREA.DETAIL.COMMUNICATION.SEND_TITLE') }}
          </h3>
          <TextArea
            v-model="resposta"
            :placeholder="t('CLIENT_AREA.DETAIL.COMMUNICATION.PLACEHOLDER')"
            :max-length="5000"
            min-height="6rem"
            max-height="14rem"
            resize
            class="w-full"
          />
          <TicketFileInput v-model="arquivos" />
          <div class="flex justify-end">
            <Button
              size="sm"
              icon="i-lucide-send"
              :label="t('CLIENT_AREA.DETAIL.COMMUNICATION.SEND')"
              :disabled="!podeEnviar"
              :is-loading="isSending"
              @click="enviar"
            />
          </div>
        </div>

        <p
          v-if="!communications.length"
          class="py-8 m-0 text-sm text-center text-n-slate-11"
        >
          {{ t('CLIENT_AREA.DETAIL.NO_COMMUNICATION') }}
        </p>

        <!-- O que o cliente escreveu fica visualmente do lado dele; o que a
             equipe enviou, do outro. Sem isso a conversa vira uma pilha de
             textos sem autor. -->
        <article
          v-for="com in communications"
          :key="com.id"
          class="flex flex-col gap-2 p-4 border rounded-lg"
          :class="
            com.direction === 'inbound'
              ? 'border-n-brand/40 bg-n-alpha-1'
              : 'border-n-weak'
          "
        >
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-xs font-medium text-n-slate-12">
              {{
                com.direction === 'inbound'
                  ? t('CLIENT_AREA.DETAIL.COMMUNICATION.FROM_YOU')
                  : com.author_name ||
                    t('CLIENT_AREA.DETAIL.COMMUNICATION.FROM_TEAM')
              }}
            </span>
            <Label
              v-if="com.closing"
              :label="t('CLIENT_AREA.DETAIL.CLOSING_NOTICE')"
              color="teal"
              size="small"
            />
            <span class="text-xs ltr:ml-auto rtl:mr-auto text-n-slate-10">
              {{ dataHora(com.sent_at || com.created_at) }}
            </span>
          </div>
          <p class="m-0 text-sm whitespace-pre-line text-n-slate-11">
            {{ com.body }}
          </p>
          <ul v-if="com.attachments?.length" class="flex flex-wrap gap-2 m-0">
            <li v-for="anexo in com.attachments" :key="anexo.id">
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
        </article>
      </section>

      <!-- VALORIZAÇÃO: as propostas que a equipe liberou. O cliente lê o PDF e
           decide uma única vez - aprovada ou recusada, não há como voltar. -->
      <section
        v-else-if="activeTab === 'valuation'"
        class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto"
      >
        <p
          v-if="!proposals.length"
          class="py-8 m-0 text-sm text-center text-n-slate-11"
        >
          {{ t('CLIENT_AREA.DETAIL.PROPOSALS.EMPTY') }}
        </p>
        <article
          v-for="proposal in proposals"
          :key="proposal.id"
          class="flex flex-col gap-3 p-4 border rounded-lg border-n-weak"
        >
          <div class="flex flex-wrap items-center gap-2">
            <Icon icon="i-lucide-file-text" class="size-4 text-n-slate-10" />
            <h3 class="flex-1 m-0 text-sm font-medium text-n-slate-12">
              {{ dinheiro(proposal.amount) }}
            </h3>
            <Label
              :label="
                t(
                  `CLIENT_AREA.DETAIL.PROPOSALS.STATUS.${proposal.status.toUpperCase()}`
                )
              "
              :color="PROPOSAL_STATUS_COLOR[proposal.status]"
              size="small"
            />
            <Label
              v-if="proposal.expired && proposal.status === 'pending'"
              :label="t('CLIENT_AREA.DETAIL.PROPOSALS.EXPIRED')"
              color="ruby"
              size="small"
            />
          </div>

          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ proposal.summary }}
          </p>

          <ul class="flex flex-col gap-2 m-0">
            <li
              v-for="(item, index) in proposal.items"
              :key="index"
              class="flex items-start justify-between gap-3 p-3 list-none rounded-lg bg-n-alpha-1"
            >
              <div class="flex flex-col min-w-0 gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ item.title }}
                </span>
                <p
                  v-if="item.description"
                  class="m-0 text-xs whitespace-pre-line text-n-slate-11"
                >
                  {{ item.description }}
                </p>
              </div>
              <span class="flex-shrink-0 text-sm text-n-slate-12">
                {{ dinheiro(item.amount) }}
              </span>
            </li>
          </ul>

          <dl class="grid grid-cols-1 gap-2 m-0 sm:grid-cols-2">
            <div class="flex flex-col gap-0.5">
              <dt class="text-xs text-n-slate-10">
                {{ t('CLIENT_AREA.DETAIL.PROPOSALS.DEADLINE') }}
              </dt>
              <dd class="m-0 text-sm text-n-slate-12">
                {{
                  t('CLIENT_AREA.DETAIL.PROPOSALS.DEADLINE_VALUE', {
                    days: proposal.deadline_days,
                  })
                }}
              </dd>
            </div>
            <div class="flex flex-col gap-0.5">
              <dt class="text-xs text-n-slate-10">
                {{ t('CLIENT_AREA.DETAIL.PROPOSALS.VALID_UNTIL') }}
              </dt>
              <dd class="m-0 text-sm text-n-slate-12">
                {{ diaSimples(proposal.valid_until) }}
              </dd>
            </div>
            <div class="flex flex-col gap-0.5 sm:col-span-2">
              <dt class="text-xs text-n-slate-10">
                {{ t('CLIENT_AREA.DETAIL.PROPOSALS.PAYMENT_TERMS') }}
              </dt>
              <dd class="m-0 text-sm text-n-slate-12">
                {{ proposal.payment_terms }}
              </dd>
            </div>
          </dl>

          <div class="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              slate
              faded
              icon="i-lucide-download"
              :label="t('CLIENT_AREA.DETAIL.PROPOSALS.DOWNLOAD_PDF')"
              @click="baixarProposta(proposal)"
            />

            <!-- Só quem ainda pode decidir vê os botões. Depois da resposta
                 (ou do vencimento) eles deixam de existir, e o servidor
                 também recusa uma segunda tentativa. -->
            <template v-if="proposal.status === 'pending' && !proposal.expired">
              <template v-if="confirmando?.id !== proposal.id">
                <Button
                  size="sm"
                  teal
                  icon="i-lucide-check"
                  class="ltr:ml-auto rtl:mr-auto"
                  :label="t('CLIENT_AREA.DETAIL.PROPOSALS.APPROVE')"
                  @click="pedirConfirmacao(proposal, 'approve')"
                />
                <Button
                  size="sm"
                  ruby
                  icon="i-lucide-x"
                  :label="t('CLIENT_AREA.DETAIL.PROPOSALS.REFUSE')"
                  @click="pedirConfirmacao(proposal, 'refuse')"
                />
              </template>
              <div
                v-else
                class="flex flex-wrap items-center gap-2 ltr:ml-auto rtl:mr-auto"
              >
                <span class="text-sm font-medium text-n-slate-12">
                  {{
                    t(
                      `CLIENT_AREA.DETAIL.PROPOSALS.SURE_${confirmando.decision.toUpperCase()}`
                    )
                  }}
                </span>
                <Button
                  size="sm"
                  :teal="confirmando.decision === 'approve'"
                  :ruby="confirmando.decision === 'refuse'"
                  :label="t('CLIENT_AREA.DETAIL.PROPOSALS.CONFIRM')"
                  :is-loading="decidindo"
                  @click="decidir"
                />
                <Button
                  size="sm"
                  slate
                  faded
                  :label="t('CLIENT_AREA.DETAIL.PROPOSALS.CANCEL')"
                  :disabled="decidindo"
                  @click="confirmando = null"
                />
              </div>
            </template>
          </div>
        </article>
      </section>

      <!-- COMPROMISSOS: somente leitura -->
      <section
        v-else-if="activeTab === 'appointments'"
        class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto"
      >
        <p
          v-if="!appointments.length"
          class="py-8 m-0 text-sm text-center text-n-slate-11"
        >
          {{ t('CLIENT_AREA.DETAIL.NO_APPOINTMENTS') }}
        </p>
        <article
          v-for="evento in appointments"
          :key="evento.id"
          class="flex flex-col gap-1 p-4 border rounded-lg border-n-weak"
        >
          <div class="flex flex-wrap items-center gap-2">
            <Icon
              icon="i-lucide-calendar-clock"
              class="size-4 text-n-slate-10"
            />
            <h3 class="flex-1 m-0 text-sm font-medium text-n-slate-12">
              {{ evento.title }}
            </h3>
          </div>
          <span class="text-sm text-n-slate-11">
            {{ dataHora(evento.start_at) }} — {{ dataHora(evento.end_at) }}
          </span>
          <span v-if="evento.location" class="text-xs text-n-slate-10">
            {{ evento.location }}
          </span>
          <p
            v-if="evento.description"
            class="m-0 text-sm whitespace-pre-line text-n-slate-11"
          >
            {{ evento.description }}
          </p>
        </article>
      </section>

      <!-- CHECKLIST: somente leitura, sem caixa clicável -->
      <section
        v-else
        class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto"
      >
        <p
          v-if="!checklistItems.length"
          class="py-8 m-0 text-sm text-center text-n-slate-11"
        >
          {{ t('CLIENT_AREA.DETAIL.NO_CHECKLIST') }}
        </p>
        <template v-else>
          <span class="text-sm text-n-slate-11">
            {{
              t('CLIENT_AREA.DETAIL.CHECKLIST_PROGRESS', {
                done: concluidos,
                total: checklistItems.length,
              })
            }}
          </span>
          <ul class="flex flex-col gap-2 m-0">
            <li
              v-for="item in checklistItems"
              :key="item.id"
              class="flex items-start gap-2 p-3 border rounded-lg list-none border-n-weak"
            >
              <Icon
                :icon="
                  item.completed ? 'i-lucide-check-circle-2' : 'i-lucide-circle'
                "
                class="mt-0.5 size-4 flex-shrink-0"
                :class="item.completed ? 'text-n-teal-11' : 'text-n-slate-10'"
              />
              <div class="flex flex-col min-w-0 gap-0.5">
                <span
                  class="text-sm text-n-slate-12"
                  :class="item.completed ? 'line-through text-n-slate-10' : ''"
                >
                  {{ item.title }}
                </span>
                <span v-if="item.value" class="text-xs text-n-slate-11">
                  {{ item.value }}
                </span>
              </div>
              <span
                v-if="item.required"
                class="text-xs ltr:ml-auto rtl:mr-auto text-n-amber-11 flex-shrink-0"
              >
                {{ t('CLIENT_AREA.DETAIL.REQUIRED') }}
              </span>
            </li>
          </ul>
        </template>
      </section>
    </template>
  </div>
</template>
