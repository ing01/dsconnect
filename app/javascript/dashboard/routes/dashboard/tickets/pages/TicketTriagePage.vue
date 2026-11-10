<script setup>
/**
 * A triagem dos chamados abertos pelo cliente.
 *
 * O cliente informa o problema; para onde o chamado vai é decisão de quem
 * atende. Esta tela é essa decisão: a fila do que chegou, e o encaminhamento
 * para a Mesa e o Estágio certos.
 *
 * Enquanto o chamado está aqui ele NÃO aparece no Kanban da equipe - aceitar é
 * o que o coloca em andamento.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import TicketsAPI from 'dashboard/api/tickets';
import Button from 'dashboard/components-next/button/Button.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketSelect from '../components/TicketSelect.vue';
import { priorityColor } from '../helpers/ticketLabels';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const currentAccountId = useMapGetter('getCurrentAccountId');
const teams = useMapGetter('teams/getTeams');

const isLoading = ref(true);
const isSaving = ref(false);
const fila = ref([]);
const emTriagem = ref(null);
const destino = ref({ teamId: null, columnId: null, categoryId: null });
const encaminharDialog = ref(null);
const resumoDialog = ref(null);
const ticketResumo = ref(null);

const teamOptions = computed(() =>
  (teams.value || []).map(team => ({ value: team.id, label: team.name }))
);

// Estágios e Categorias são da Mesa escolhida - a mesma regra do formulário
// interno. Trocar de Mesa invalida os dois.
const columnOptions = computed(() =>
  (store.getters['ticketColumns/getColumns'](destino.value.teamId) || []).map(
    c => ({ value: c.id, label: c.name })
  )
);

const categoryOptions = computed(() =>
  (
    store.getters['ticketColumns/getCategories'](destino.value.teamId) || []
  ).map(c => ({ value: c.id, label: c.name }))
);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '—';

const carregar = async () => {
  isLoading.value = true;
  try {
    const { data } = await TicketsAPI.get({
      pending_triage: true,
      per_page: 50,
    });
    fila.value = data.payload || [];
    // O contador do menu lateral e a fila desta tela sao o mesmo numero. Quem
    // acabou de ver a lista nao deve ver um contador que a contradiz.
    store.dispatch('tickets/fetchTriageCount');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isLoading.value = false;
  }
};

// Botao "Abrir" da fila: mostra um resumo primeiro, em vez de navegar direto
// pro ticket completo - pedido da Ingrid, 2026-11-10 (ir e voltar toda hora
// pra so' dar uma olhada ficava inviavel). A navegacao de verdade (e' o que
// o resumo oferece como "Ver ticket completo") continua a mesma de antes.
const abrirResumo = ticket => {
  ticketResumo.value = ticket;
  resumoDialog.value?.open();
};

const irParaTicketCompleto = ticket => {
  resumoDialog.value?.close();
  router.push(
    frontendURL(`accounts/${currentAccountId.value}/tickets/${ticket.id}`)
  );
};

const escolherMesa = async teamId => {
  destino.value.teamId = teamId;
  destino.value.columnId = null;
  destino.value.categoryId = null;
  if (!teamId) return;

  // As listas de Estágios e Categorias vêm de `fetchColumns`/`fetchCategories`
  // (é o que os getters acima leem, e o que o formulário de criação usa).
  // `fetchBoard` guarda outra coisa - o quadro do Kanban, com os tickets - e
  // por isso deixava o seletor de Estágio sempre vazio ("Nenhum resultado
  // encontrado").
  try {
    await Promise.all([
      store.dispatch('ticketColumns/fetchColumns', teamId),
      store.dispatch('ticketColumns/fetchCategories', teamId),
    ]);
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  }
};

const abrirEncaminhamento = async ticket => {
  emTriagem.value = ticket;
  destino.value = { teamId: null, columnId: null, categoryId: null };
  // A Mesa de entrada veio da Categoria escolhida pelo cliente: é o palpite
  // mais provável, e quem tria confirma ou muda.
  await escolherMesa(ticket.team_id);
  encaminharDialog.value?.open();
};

// Mesmo fluxo do botao "Aceitar e encaminhar" da fila - so' que acionado de
// dentro do resumo, pra quem abriu so' pra espiar decidir encaminhar sem
// precisar fechar e procurar o outro botao.
const abrirEncaminhamentoDoResumo = ticket => {
  resumoDialog.value?.close();
  abrirEncaminhamento(ticket);
};

const podeEncaminhar = computed(
  () => Boolean(destino.value.teamId) && Boolean(destino.value.columnId)
);

const encaminhar = async () => {
  if (!podeEncaminhar.value || isSaving.value) return;

  isSaving.value = true;
  try {
    await TicketsAPI.approveTriage(emTriagem.value.id, {
      teamId: destino.value.teamId,
      ticketColumnId: destino.value.columnId,
      ticketCategoryId: destino.value.categoryId,
    });
    useAlert(
      t('TICKET.TRIAGE.APPROVED', { number: emTriagem.value.display_id })
    );
    encaminharDialog.value?.close();
    await carregar();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  store.dispatch('teams/get');
  await carregar();
});
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 min-w-0 gap-4 p-4">
    <header class="flex flex-col flex-shrink-0 w-full gap-1 min-w-0">
      <h1 class="m-0 text-xl font-medium text-n-slate-12">
        {{ t('TICKET.TRIAGE.TITLE') }}
      </h1>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('TICKET.TRIAGE.DESCRIPTION') }}
      </p>
    </header>

    <PageLoader v-if="isLoading" />

    <div
      v-else-if="!fila.length"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
    >
      <Icon icon="i-lucide-inbox-check" class="size-6 text-n-teal-11" />
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('TICKET.TRIAGE.EMPTY') }}
      </p>
    </div>

    <ul v-else class="flex flex-col gap-2 m-0 overflow-y-auto">
      <li
        v-for="ticket in fila"
        :key="ticket.id"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak sm:flex-row sm:items-center"
      >
        <div class="flex flex-col flex-1 gap-1 min-w-0">
          <div class="flex flex-wrap items-center gap-2 min-w-0">
            <span class="text-xs font-medium text-n-slate-10">
              #{{ ticket.display_id }}
            </span>
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ ticket.title }}
            </span>
            <Label
              v-if="ticket.priority"
              :label="
                t(`TICKET.FORM.PRIORITY.${ticket.priority.toUpperCase()}`)
              "
              :color="priorityColor(ticket.priority)"
              size="small"
            />
          </div>
          <span class="text-xs text-n-slate-10">
            {{
              t('TICKET.TRIAGE.OPENED_BY', {
                name: ticket.requester_name || '—',
                company: ticket.company_name || '—',
                at: dataHora(ticket.created_at),
              })
            }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{
              t('TICKET.TRIAGE.SUGGESTED', {
                category: ticket.ticket_category_name || '—',
                team: ticket.team_name,
              })
            }}
          </span>
        </div>

        <div class="flex flex-shrink-0 gap-2">
          <Button
            faded
            slate
            size="sm"
            icon="i-lucide-eye"
            :label="t('TICKET.TRIAGE.OPEN')"
            @click="abrirResumo(ticket)"
          />
          <Button
            size="sm"
            icon="i-lucide-check"
            :label="t('TICKET.TRIAGE.APPROVE')"
            @click="abrirEncaminhamento(ticket)"
          />
        </div>
      </li>
    </ul>

    <Dialog
      ref="resumoDialog"
      type="edit"
      width="md"
      :title="
        t('TICKET.TRIAGE.SUMMARY.TITLE', { number: ticketResumo?.display_id })
      "
    >
      <div v-if="ticketResumo" class="flex flex-col gap-3 min-w-0">
        <div class="flex flex-wrap items-center gap-2 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ ticketResumo.title }}
          </span>
          <Label
            v-if="ticketResumo.priority"
            :label="
              t(`TICKET.FORM.PRIORITY.${ticketResumo.priority.toUpperCase()}`)
            "
            :color="priorityColor(ticketResumo.priority)"
            size="small"
          />
        </div>
        <span class="text-xs text-n-slate-10">
          {{
            t('TICKET.TRIAGE.OPENED_BY', {
              name: ticketResumo.requester_name || '—',
              company: ticketResumo.company_name || '—',
              at: dataHora(ticketResumo.created_at),
            })
          }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{
            t('TICKET.TRIAGE.SUGGESTED', {
              category: ticketResumo.ticket_category_name || '—',
              team: ticketResumo.team_name,
            })
          }}
        </span>
        <p
          v-if="ticketResumo.description"
          class="m-0 text-sm whitespace-pre-wrap text-n-slate-12"
        >
          {{ ticketResumo.description }}
        </p>
      </div>

      <template #footer>
        <div class="flex items-center justify-between w-full gap-3">
          <Button
            faded
            slate
            class="w-full"
            type="button"
            :label="t('TICKET.TRIAGE.SUMMARY.VIEW_FULL')"
            @click="irParaTicketCompleto(ticketResumo)"
          />
          <Button
            class="w-full"
            type="button"
            :label="t('TICKET.TRIAGE.SUMMARY.OPEN_AND_FORWARD')"
            @click="abrirEncaminhamentoDoResumo(ticketResumo)"
          />
        </div>
      </template>
    </Dialog>

    <Dialog
      ref="encaminharDialog"
      type="edit"
      width="lg"
      :title="
        t('TICKET.TRIAGE.DIALOG.TITLE', { number: emTriagem?.display_id })
      "
      :description="t('TICKET.TRIAGE.DIALOG.DESCRIPTION')"
      :confirm-button-label="t('TICKET.TRIAGE.DIALOG.CONFIRM')"
      :disable-confirm-button="!podeEncaminhar"
      :is-loading="isSaving"
      @confirm="encaminhar"
    >
      <div class="flex flex-col gap-4 min-w-0">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.TRIAGE.DIALOG.TEAM') }}
          </span>
          <TicketSelect
            :model-value="destino.teamId"
            :options="teamOptions"
            class="w-full"
            @update:model-value="escolherMesa"
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.TRIAGE.DIALOG.COLUMN') }}
          </span>
          <TicketSelect
            v-model="destino.columnId"
            :options="columnOptions"
            :disabled="!destino.teamId"
            class="w-full"
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.TRIAGE.DIALOG.CATEGORY') }}
          </span>
          <TicketSelect
            v-model="destino.categoryId"
            :options="categoryOptions"
            :disabled="!destino.teamId"
            clearable
            :clear-label="t('TICKET.TRIAGE.DIALOG.CATEGORY_KEEP')"
            :placeholder="t('TICKET.TRIAGE.DIALOG.CATEGORY_KEEP')"
            class="w-full"
          />
        </label>
      </div>
    </Dialog>
  </div>
</template>
