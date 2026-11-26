<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useStore,
  useMapGetter,
  useStoreGetters,
} from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketsAPI from 'dashboard/api/tickets';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import TicketCatalogSelect from './TicketCatalogSelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  // So' quando o fechamento vem pela CONVERSA (Resolver): deixa ajustar o
  // assunto e a descricao ali mesmo, sem entrar no ticket. Na tela do proprio
  // ticket isso ja se edita no detalhe.
  allowEditDetails: { type: Boolean, default: false },
});

// `cancel` forwards the inner Dialog's own `close` (backdrop click, Escape, or
// the Cancelar button below) - it also fires on the `closed`/`left-open` paths,
// since both call the same Dialog's `close()`. Callers that care about a real
// cancellation (nothing was decided) must only act on it when neither of those
// has already fired for that same attempt.
const emit = defineEmits(['closed', 'leftOpen', 'cancel']);

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const dialogRef = ref(null);
const isWorking = ref(false);

// Categoria/Mesa/Estagio para onde o ticket vai ser encaminhado ao fechar -
// parte confirmando/trocando a Categoria, escolher uma de outra Mesa
// preenche Mesa e Estagio automaticamente (o padrao configurado em
// Configuracoes > Tickets > Categorias), mas os tres continuam editaveis
// de forma independente antes de confirmar. Pedido da Ingrid, 2026-11-16.
const categoryId = ref(null);
const teamId = ref(null);
const columnId = ref(null);

const teams = useMapGetter('teams/getTeams');

// Categorias de TODAS as Mesas, agrupadas por Mesa no select - precisa ser
// assim (e nao so' as da Mesa atual) porque escolher uma categoria de outra
// Mesa e' o jeito de encaminhar o ticket pra ela nesta tela.
const categoriesByTeam = computed(() =>
  teams.value.map(team => ({
    team,
    categories: getters['ticketColumns/getCategories'].value(team.id) || [],
  }))
);
const allCategories = computed(() =>
  categoriesByTeam.value.flatMap(group => group.categories)
);
const stageOptions = computed(
  () => getters['ticketColumns/getColumns'].value(teamId.value) || []
);

const onCategorySelect = () => {
  const category = allCategories.value.find(
    candidate => candidate.id === Number(categoryId.value)
  );
  if (!category) return;

  teamId.value = category.team_id;
  if (category.default_ticket_column_id) {
    columnId.value = category.default_ticket_column_id;
  }
};

// Trocar a Mesa a mao leva junto Categoria e Estagio que sejam dela: sem isso o
// pedido saia com a combinacao de duas Mesas e o servidor recusava o fechamento.
// A Categoria de mesmo nome e' mantida; sem ela, a pessoa escolhe.
const onTeamSelect = () => {
  const target = Number(teamId.value);
  const current = allCategories.value.find(
    candidate => candidate.id === Number(categoryId.value)
  );
  const categories =
    categoriesByTeam.value.find(group => group.team.id === target)
      ?.categories || [];
  if (current && current.team_id !== target) {
    categoryId.value =
      categories.find(candidate => candidate.name === current.name)?.id || null;
  }
  if (!stageOptions.value.some(stage => stage.id === columnId.value)) {
    const chosen = categories.find(
      candidate => candidate.id === categoryId.value
    );
    columnId.value =
      chosen?.default_ticket_column_id || stageOptions.value[0]?.id || null;
  }
};

// So' usa o caminho de transferencia (Mesa/Estagio/Categoria + fechar numa
// chamada so') quando algo realmente mudou - o fechamento comum (sem mexer
// em nada disso) continua exatamente como sempre foi.
const routingChanged = computed(
  () =>
    (categoryId.value ? Number(categoryId.value) : null) !==
      (props.ticket.ticket_category_id ?? null) ||
    (teamId.value ? Number(teamId.value) : null) !==
      (props.ticket.team_id ?? null) ||
    (columnId.value ? Number(columnId.value) : null) !==
      (props.ticket.ticket_column_id ?? null)
);

// Os filhos ainda abertos podem ser finalizados junto, com os dados deste ticket. E'
// uma escolha de quem fecha: vem desmarcada.
const finalizarFilhos = ref(false);
const openChildren = computed(() =>
  (props.ticket.children || []).filter(
    child => !['closed', 'cancelled'].includes(child.status)
  )
);

const catalogId = ref(null);
const areaId = ref(null);
const itemId = ref(null);
const body = ref('');
// O que foi feito para resolver. Alimenta o DueRules e a documentacao - por isso
// e' obrigatoria, e nao um campo opcional de observacao.
const resolution = ref('');
// Mesma escolha da aba Comunicacao: desmarcado, a mensagem de encerramento e
// REGISTRADA sem e-mail. Ela continua valendo para fechar o ticket - o cliente
// ve o texto na Area do Cliente -, e serve para quando a equipe ja avisou por
// telefone ou WhatsApp.
const notificarCliente = ref(true);
// Assunto e descricao editaveis (so' com `allowEditDetails`); partem do que o
// ticket ja tem e so' sao gravados se mudaram.
const title = ref('');
const description = ref('');
// "Resumir conversa com IA": o mesmo resumo da tela do ticket. `summaryRun` marca
// a abertura atual do dialogo, para uma resposta que chega depois de fechar (ou de
// abrir outro ticket) nao escrever no formulario errado.
const isSummarizing = ref(false);
let summaryRun = 0;

// Os motivos do servidor; um que nao esteja na lista aparece como veio.
const MISSING_KEYS = [
  'ticket_category',
  'service_catalog',
  'resolution',
  'customer_communication',
  'checklist',
  'permission',
];
const missingLabel = reason =>
  MISSING_KEYS.includes(reason)
    ? t(`TICKET.CLOSE.CHILDREN_MISSING.${reason.toUpperCase()}`)
    : reason;

const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');

// The server is the authority on what is still missing; the dialog reads its
// verdict rather than re-deriving the rules here.
const missing = computed(() => props.ticket.missing_close_requirements || []);
// Categoria sempre foi exigencia do servidor pra fechar (`missing_close_requirements`
// ja incluia `ticket_category` antes desta tela ganhar o seletor proprio) - sem
// isto aqui, o botao ficava liberado mesmo com a Categoria vazia, e o fechamento
// so' falhava DEPOIS, la no servidor. Achado ao investigar "Erro ao salvar" no
// fechamento quando a Categoria do ticket estava vazia (2026-11-18).
const needsCategory = computed(() => missing.value.includes('ticket_category'));
const needsCatalog = computed(() => missing.value.includes('service_catalog'));
const needsResolution = computed(() => missing.value.includes('resolution'));
const needsCommunication = computed(() =>
  missing.value.includes('customer_communication')
);
// Pending checklist items with no Apontamento linked yet - the server bypasses
// this the moment one exists (Ticket#ensure_checklist_completed!), so this is
// informational: the agent fixes it from the Checklist/Apontamentos tabs, not
// from this dialog.
const needsChecklist = computed(() => missing.value.includes('checklist'));
// Solicitante sem e-mail NAO impede o fechamento: nao ha a quem escrever, entao
// nenhuma mensagem e' enviada e o ticket fecha normalmente (o servidor tambem nao
// exige a comunicacao nesse caso).
const noEmail = computed(() => !props.ticket.customer_email);

const classification = computed(() => props.ticket.service_catalog_item);

const categoryReady = computed(
  () => !needsCategory.value || !!categoryId.value
);
const catalogReady = computed(() => !needsCatalog.value || !!itemId.value);
const resolutionReady = computed(
  () => !needsResolution.value || !!resolution.value.trim()
);
// The subject is not the agent's to write: the server titles every customer
// message with the ticket header, the closing notice included. Shown here so
// what will be sent is visible.
const subject = computed(() => props.ticket.display_subject);

const communicationReady = computed(
  () => !needsCommunication.value || !!body.value.trim()
);
const detailsReady = computed(
  () => !props.allowEditDetails || !!title.value.trim()
);
const detailsChanged = computed(
  () =>
    props.allowEditDetails &&
    (title.value.trim() !== (props.ticket.title || '') ||
      description.value !== (props.ticket.description || ''))
);
const canSubmit = computed(
  () =>
    detailsReady.value &&
    categoryReady.value &&
    catalogReady.value &&
    resolutionReady.value &&
    communicationReady.value &&
    !needsChecklist.value
);

const open = () => {
  catalogId.value = null;
  areaId.value = null;
  itemId.value = null;
  body.value = '';
  resolution.value = '';
  notificarCliente.value = true;
  finalizarFilhos.value = false;
  title.value = props.ticket.title || '';
  description.value = props.ticket.description || '';
  categoryId.value = props.ticket.ticket_category_id || null;
  teamId.value = props.ticket.team_id || null;
  columnId.value = props.ticket.ticket_column_id || null;
  summaryRun += 1;
  isSummarizing.value = false;
  store.dispatch('serviceCatalogs/fetch');
  store.dispatch('teams/get').then(() => {
    teams.value.forEach(team => {
      store.dispatch('ticketColumns/fetchCategories', team.id);
      store.dispatch('ticketColumns/fetchColumns', team.id);
    });
  });
  dialogRef.value?.open();
};

// O servidor resume as conversas ligadas ao ticket e devolve descricao e titulo
// sugeridos, como na tela do ticket. Aqui eles so' PREENCHEM os campos: continuam
// editaveis e so' sao gravados junto com o fechamento.
const summarizeConversation = async () => {
  if (isSummarizing.value || isWorking.value) return;

  const run = summaryRun;
  isSummarizing.value = true;
  try {
    const { data } = await TicketsAPI.summarizeConversation(props.ticket.id);
    if (run !== summaryRun) return;
    if (!data?.message) {
      useAlert(t('TICKET.DETAIL.DESCRIPTION.SUMMARIZE_EMPTY'));
      return;
    }
    description.value = data.message;
    if (data.title?.trim()) title.value = data.title.trim();
  } catch (error) {
    if (run !== summaryRun) return;
    useAlert(
      error?.response?.data?.error ||
        t('TICKET.DETAIL.DESCRIPTION.SUMMARIZE_ERROR')
    );
  } finally {
    if (run === summaryRun) isSummarizing.value = false;
  }
};

// Roda DEPOIS do pai fechado: uma falha aqui nao desfaz o fechamento, so' e' avisada.
const closeChildren = async () => {
  try {
    const { closed = [], pending = [] } = await store.dispatch(
      'tickets/closeChildren',
      props.ticket.id
    );
    const messages = [];
    if (closed.length) {
      const list = closed.map(number => `#${number}`).join(', ');
      messages.push(t('TICKET.CLOSE.CHILDREN_DONE', { list }));
    }
    if (pending.length) {
      const list = pending
        .map(({ display_id: number, missing: reasons }) => {
          const labels = reasons.map(missingLabel).join(', ');
          return `#${number} (${labels})`;
        })
        .join('; ');
      messages.push(t('TICKET.CLOSE.CHILDREN_PENDING', { list }));
    }
    if (messages.length) useAlert(messages.join(' '));
  } catch (error) {
    useAlert(error?.response?.data?.error || t('TICKET.CLOSE.CHILDREN_ERROR'));
  }
};

// The classification comes first, then the message, then the close - and each
// step only runs once the one before it succeeded. A failed send leaves the
// ticket open with whatever was already saved, so retrying costs nothing.
const submit = async () => {
  if (!canSubmit.value || isWorking.value) return;

  isWorking.value = true;
  try {
    // Primeiro o assunto/descricao: a mensagem de encerramento ao cliente usa o
    // titulo do ticket, entao ele precisa estar gravado antes do envio.
    if (detailsChanged.value) {
      await store.dispatch('tickets/updateTicket', {
        id: props.ticket.id,
        title: title.value.trim(),
        description: description.value,
      });
    }

    if (needsCatalog.value) {
      await store.dispatch('tickets/classifyTicket', {
        id: props.ticket.id,
        serviceCatalogId: catalogId.value,
        serviceCatalogAreaId: areaId.value,
        serviceCatalogItemId: itemId.value,
      });
    }

    if (needsCommunication.value) {
      await store.dispatch('tickets/sendCustomerCommunication', {
        ticketId: props.ticket.id,
        body: body.value,
        closing: true,
        notifyCustomer: notificarCliente.value,
      });
    }

    // A Resolucao vai no proprio fechamento: o servidor so' a grava se o ticket
    // fechar, entao uma recusa nao deixa texto solto no ticket.
    //
    // Mesa/Estagio/Categoria mudaram? Vai tudo numa unica chamada de
    // transferencia com o fechamento embutido (Tickets::TransferService ja
    // aplica a mudanca ANTES de fechar, na ordem certa) - sem mexer em nada
    // disso, o fechamento continua exatamente como sempre foi.
    if (routingChanged.value) {
      await store.dispatch('tickets/transferTicket', {
        id: props.ticket.id,
        team_id: teamId.value,
        ticket_column_id: columnId.value || undefined,
        ticket_category_id: categoryId.value || null,
        status: 'closed',
        resolution: needsResolution.value ? resolution.value.trim() : undefined,
      });
    } else {
      await store.dispatch('tickets/closeTicket', {
        id: props.ticket.id,
        resolution: needsResolution.value ? resolution.value.trim() : undefined,
      });
    }
    if (finalizarFilhos.value && openChildren.value.length) {
      await closeChildren();
    }
    // Avisa a decisao ANTES de fechar o dialogo: fechar dispara `cancel`, e quem
    // escuta (ResolveAction) so' ignora esse `cancel` se ja' soube da decisao.
    emit('closed');
    dialogRef.value?.close();
  } catch (error) {
    // The server explains what went wrong - a refused delivery, a missing
    // address - and the ticket stays exactly as it was.
    // Recusa de validacao vem em `message` (qual campo e por que).
    const { error: reason, message } = error?.response?.data || {};
    useAlert(reason || message || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isWorking.value = false;
  }
};

// So' resolve a conversa, sem passar pelo fechamento do ticket - a Mesa decide
// depois, com calma, se aquilo realmente acabou. Nao exige nenhum dos
// requisitos de fechamento (Catalogo, Resolucao, Comunicacao): o ticket
// continua aberto exatamente como estava.
const leaveOpen = () => {
  if (isWorking.value) return;

  // Decisao primeiro, fechamento depois: fechar o dialogo dispara `cancel`, que
  // a conversa trataria como "desisti" e NAO resolveria.
  emit('leftOpen');
  dialogRef.value?.close();
};

watch(
  () => props.ticket.id,
  () => {
    catalogId.value = null;
    areaId.value = null;
    itemId.value = null;
    resolution.value = '';
    finalizarFilhos.value = false;
    categoryId.value = props.ticket.ticket_category_id || null;
    teamId.value = props.ticket.team_id || null;
    columnId.value = props.ticket.ticket_column_id || null;
  }
);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    overflow-y-auto
    :title="t('TICKET.CLOSE.TITLE', { number: ticket.display_id })"
    :is-loading="isWorking"
    @confirm="submit"
    @close="emit('cancel')"
  >
    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          variant="faded"
          color="slate"
          :label="t('DIALOG.BUTTONS.CANCEL')"
          class="w-full"
          type="button"
          :disabled="isWorking"
          @click="dialogRef?.close()"
        />
        <Button
          variant="faded"
          color="amber"
          :label="t('TICKET.CLOSE.LEAVE_OPEN')"
          class="w-full"
          type="button"
          :disabled="isWorking"
          @click="leaveOpen"
        />
        <Button
          color="blue"
          :label="t('TICKET.CLOSE.CONFIRM')"
          class="w-full"
          :is-loading="isWorking"
          :disabled="!canSubmit || isWorking"
          type="submit"
        />
      </div>
    </template>

    <div class="flex flex-col gap-5 min-w-0">
      <!-- Assunto e descricao: so' no fechamento feito pela conversa. -->
      <template v-if="allowEditDetails">
        <section class="flex flex-col gap-3 min-w-0">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.CLOSE.STEP_DETAILS') }}
          </h3>
          <p class="text-xs text-n-slate-10">
            {{ t('TICKET.CLOSE.DETAILS_HINT') }}
          </p>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.DETAILS_TITLE')
              }}<span class="text-n-ruby-11">*</span>
            </span>
            <input v-model="title" type="text" class="w-full mb-0 text-sm" />
          </label>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.DETAILS_DESCRIPTION') }}
            </span>
            <textarea
              v-model="description"
              rows="4"
              class="w-full mb-0 text-sm resize-y min-h-[6rem]"
            />
          </label>
          <div class="flex justify-end">
            <Button
              variant="faded"
              color="slate"
              size="sm"
              type="button"
              class="resumir"
              icon="i-fluent-text-bullet-list-square-sparkle-32-regular"
              :is-loading="isSummarizing"
              :disabled="isSummarizing || isWorking"
              :label="t('TICKET.CLOSE.SUMMARIZE')"
              @click="summarizeConversation"
            />
          </div>
        </section>

        <div class="h-px bg-n-weak" />
      </template>

      <!-- Categoria, Mesa e Estagio para onde o ticket vai ser encaminhado -
           confirma ou troca a Categoria; trocar pra uma de outra Mesa ja'
           preenche Mesa e Estagio com o padrao configurado nela, mas os tres
           continuam editaveis de forma independente. Pedido da Ingrid,
           2026-11-16. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsCategory ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'
            "
            class="flex-shrink-0 size-4"
            :class="needsCategory ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_ROUTING') }}
        </h3>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.ROUTING_CATEGORY')
              }}<span v-if="needsCategory" class="text-n-ruby-11">*</span>
            </span>
            <select
              v-model="categoryId"
              class="w-full mb-0 text-sm"
              @change="onCategorySelect"
            >
              <option :value="null">
                {{ t('TICKET.CLOSE.ROUTING_CATEGORY_NONE') }}
              </option>
              <optgroup
                v-for="group in categoriesByTeam"
                :key="group.team.id"
                :label="group.team.name"
              >
                <option
                  v-for="category in group.categories"
                  :key="category.id"
                  :value="category.id"
                >
                  {{ category.name }}
                </option>
              </optgroup>
            </select>
          </label>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.ROUTING_TEAM') }}
            </span>
            <select
              v-model="teamId"
              class="routing-team w-full mb-0 text-sm"
              @change="onTeamSelect"
            >
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.ROUTING_STAGE') }}
            </span>
            <select v-model="columnId" class="w-full mb-0 text-sm">
              <option :value="null">
                {{ t('TICKET.CLOSE.ROUTING_STAGE_NONE') }}
              </option>
              <option
                v-for="stage in stageOptions"
                :key="stage.id"
                :value="stage.id"
              >
                {{ stage.name }}
              </option>
            </select>
          </label>
        </div>
      </section>

      <div class="h-px bg-n-weak" />

      <!-- Step 1: classification. Already done shows as done rather than
           asking again. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsCatalog ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'
            "
            class="flex-shrink-0 size-4"
            :class="needsCatalog ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_CLASSIFICATION') }}
        </h3>

        <p v-if="!needsCatalog" class="text-sm text-n-slate-11">
          {{ classification?.full_path?.join(' → ') }}
        </p>

        <TicketCatalogSelect
          v-else
          v-model:catalog-id="catalogId"
          v-model:area-id="areaId"
          v-model:item-id="itemId"
          :catalogs="catalogs"
        />
      </section>

      <div class="h-px bg-n-weak" />

      <!-- Step 2: a Resolucao. Obrigatoria: e' o que a equipe realmente fez, e e'
           a partir dela que o DueRules e a documentacao aprendem. Ja registrada,
           aparece como feita em vez de pedir de novo. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsResolution
                ? 'i-lucide-circle-alert'
                : 'i-lucide-circle-check'
            "
            class="flex-shrink-0 size-4"
            :class="needsResolution ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_RESOLUTION') }}
        </h3>

        <p
          v-if="!needsResolution"
          class="text-sm whitespace-pre-line text-n-slate-11"
        >
          {{ ticket.resolution }}
        </p>

        <label v-else class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.CLOSE.RESOLUTION')
            }}<span class="text-n-ruby-11">*</span>
          </span>
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET.CLOSE.RESOLUTION_HINT') }}
          </span>
          <textarea
            v-model="resolution"
            rows="5"
            class="resolucao w-full mb-0 text-sm resize-y min-h-[8rem]"
            :placeholder="t('TICKET.CLOSE.RESOLUTION_PLACEHOLDER')"
          />
        </label>
      </section>

      <div class="h-px bg-n-weak" />

      <!-- Checklist: informational only. The server is the authority (a linked
           Apontamento bypasses this), so this section just points the agent at
           where to fix it instead of re-deriving the rule client-side. -->
      <section v-if="needsChecklist" class="flex flex-col gap-2 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            icon="i-lucide-circle-alert"
            class="flex-shrink-0 size-4 text-n-amber-11"
          />
          {{ t('TICKET.CLOSE.STEP_CHECKLIST') }}
        </h3>
        <p class="p-3 text-sm rounded-lg text-n-amber-11 bg-n-amber-3">
          {{ t('TICKET.CLOSE.CHECKLIST_PENDING') }}
        </p>
      </section>

      <div v-if="needsChecklist" class="h-px bg-n-weak" />

      <!-- Step 2: the closing message. -->
      <section class="flex flex-col gap-3 min-w-0">
        <h3 class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
          <Icon
            :icon="
              needsCommunication
                ? 'i-lucide-circle-alert'
                : 'i-lucide-circle-check'
            "
            class="flex-shrink-0 size-4"
            :class="needsCommunication ? 'text-n-amber-11' : 'text-n-teal-11'"
          />
          {{ t('TICKET.CLOSE.STEP_COMMUNICATION') }}
        </h3>

        <!-- Sem e-mail do solicitante: so' avisa que nada sera enviado. Nao
             bloqueia - o ticket fecha do mesmo jeito. -->
        <p
          v-if="noEmail && !needsCommunication"
          class="p-3 text-sm rounded-lg text-n-slate-11 bg-n-alpha-2"
        >
          {{ t('TICKET.CLOSE.NO_EMAIL_CAN_CLOSE') }}
        </p>

        <p v-else-if="!needsCommunication" class="text-sm text-n-slate-11">
          {{ t('TICKET.CLOSE.COMMUNICATION_DONE') }}
        </p>

        <template v-else>
          <!-- Destinatario e assunto so existem se houver e-mail. Sem envio nao
               ha para quem nem com que titulo, e mostra-los seria descrever uma
               mensagem que nao vai sair. -->
          <template v-if="notificarCliente">
            <p class="text-sm text-n-slate-11">
              {{ t('TICKET.CLOSE.TO') }}:
              <span class="text-n-slate-12">{{ ticket.customer_email }}</span>
            </p>

            <p class="text-sm truncate text-n-slate-11" :title="subject">
              {{ t('TICKET.CLOSE.SUBJECT') }}:
              <span class="text-n-slate-12">{{ subject }}</span>
            </p>
          </template>

          <!-- Uma `div`, e nao um `label`: o `FullEditor` carrega dentro dele um
               `<input type="file" hidden>` (o envio de imagem do editor de
               artigos). Envolto num `label`, qualquer clique na area da
               mensagem ativava esse input e abria a tela de enviar arquivo do
               sistema - ninguem pediu anexo aqui. O editor nao e um campo
               nativo, entao o `label` tambem nao dava foco a nada. -->
          <div class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.CLOSE.MESSAGE')
              }}<span class="text-n-ruby-11">*</span>
            </span>
            <FullEditor
              v-model="body"
              class="min-w-0 [&_.ProseMirror]:min-h-[10rem]"
              :placeholder="t('TICKET.CLOSE.MESSAGE_PLACEHOLDER')"
            />
          </div>

          <!-- Fora da `div` do campo de proposito: e uma decisao sobre o envio,
               nao parte do texto. -->
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
        </template>
      </section>

      <!-- Filhos abertos: finalizar junto, com os dados deste ticket. -->
      <template v-if="openChildren.length">
        <div class="h-px bg-n-weak" />
        <section
          class="flex flex-col gap-2 min-w-0 p-3 rounded-lg bg-n-alpha-2"
          data-testid="close-children"
        >
          <label class="flex items-start gap-2 cursor-pointer min-w-0">
            <Checkbox v-model="finalizarFilhos" class="mt-0.5 flex-shrink-0" />
            <span class="flex flex-col gap-0.5 min-w-0">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  t('TICKET.CLOSE.CHILDREN_LABEL', {
                    count: openChildren.length,
                  })
                }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{ t('TICKET.CLOSE.CHILDREN_HINT') }}
              </span>
            </span>
          </label>
          <ul class="flex flex-col gap-1 m-0 list-none ps-6">
            <li
              v-for="child in openChildren"
              :key="child.id"
              class="text-xs truncate text-n-slate-11"
              :title="child.title"
            >
              #{{ child.display_id }} · {{ child.title }}
            </li>
          </ul>
        </section>
      </template>
    </div>
  </Dialog>
</template>
