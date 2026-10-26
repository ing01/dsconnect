import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import TicketsAPI from 'dashboard/api/tickets';

const LAST_TEAM_STORAGE_KEY = 'ticket-backlog-last-team-id';

// O Backlog do Modulo de Desenvolvimento: uma Mesa com a flag ligada organiza
// seus tickets em Sprints (mais o proprio Backlog, para o que ainda nao tem
// sprint). Cada "balde" (Sprint ou Backlog) busca os PROPRIOS tickets pelo
// mesmo endpoint da Busca detalhada (`TicketsAPI.get`), direto - e nao pelo
// `tickets/fetchTickets` da Vuex, que guarda UMA lista compartilhada (usada
// pela Busca detalhada em si) e seria sobrescrita a cada balde.
export function useBacklog() {
  const store = useStore();
  const { t } = useI18n();
  const allTeams = useMapGetter('teams/getTeams');

  // So' as Mesas que ligaram o modulo aparecem aqui - em qualquer outra Mesa
  // esta tela nao tem o que mostrar, exatamente como pedido.
  const devTeams = computed(() =>
    allTeams.value.filter(team => team.development_module_enabled)
  );

  const state = reactive({
    selectedTeamId: null,
    ticketsBySprint: {},
    backlogTickets: [],
    isLoading: false,
    isCreatingSprint: false,
    // Qual Sprint a tela de "Sprint ativo" mostra - nulo enquanto nao foi
    // escolhido ainda (`loadTeamData` escolhe um padrao assim que os Sprints
    // da Mesa chegam).
    boardSprintId: null,
  });

  // Fonte unica dos Sprints: o que `ticketColumns/fetchSprints` ja guardou na
  // Vuex para esta Mesa, sem copia local - `loadTeamData` so' a mantem fresca.
  const sprints = computed(
    () => store.getters['ticketColumns/getSprints'](state.selectedTeamId) || []
  );

  // O quadro Kanban da Mesa, tal como e' - mesma fonte que o `TicketsPage`
  // usa. A tela de Sprint ativo reaproveita ele inteiro, so' escondendo
  // visualmente (via `filters.sprintId`) quem nao e' do Sprint escolhido.
  const board = computed(() =>
    store.getters['ticketColumns/getBoard'](state.selectedTeamId)
  );

  // O Sprint "vigente": o que contem hoje no intervalo, ou o proximo upcoming
  // se nenhum contiver (ex.: todos os Sprints cadastrados sao futuros). `null`
  // quando a Mesa ainda nao tem nenhum Sprint - a tela entao so' mostra o
  // convite para criar um.
  const currentSprint = computed(() => {
    const today = new Date().toISOString().slice(0, 10);
    return (
      sprints.value.find(
        sprint => sprint.starts_on <= today && today <= sprint.ends_on
      ) ||
      sprints.value[0] ||
      null
    );
  });

  // Membros da Mesa, nao todo agente da conta - a mesma fonte que o Kanban
  // usa para resolver nome/avatar nos cartoes.
  const mesaAgents = computed(
    () =>
      store.getters['teamMembers/getTeamMembers'](state.selectedTeamId) || []
  );

  // Estagios da Mesa - para o seletor de Estagio em cada linha (Backlog e
  // Sprint) e para o filtro por Estagio.
  const columns = computed(
    () => store.getters['ticketColumns/getColumns'](state.selectedTeamId) || []
  );

  const selectTeam = teamId => {
    state.selectedTeamId = teamId ? Number(teamId) : null;
    if (state.selectedTeamId) {
      window.localStorage.setItem(LAST_TEAM_STORAGE_KEY, state.selectedTeamId);
    }
  };

  const restoreLastTeam = () => {
    if (state.selectedTeamId || !devTeams.value.length) return;

    const saved = Number(window.localStorage.getItem(LAST_TEAM_STORAGE_KEY));
    const exists = devTeams.value.some(team => team.id === saved);
    selectTeam(exists ? saved : devTeams.value[0].id);
  };

  const loadBucketTickets = async () => {
    if (!state.selectedTeamId) return;

    state.isLoading = true;
    try {
      // `status: 'open'` pelo mesmo motivo do Kanban: um ticket resolvido,
      // fechado ou cancelado sai do fluxo operacional - aqui tambem, nao so'
      // nas colunas do quadro.
      const [backlogResponse, ...sprintResponses] = await Promise.all([
        TicketsAPI.get({
          team_id: state.selectedTeamId,
          without_sprint: true,
          status: 'open',
        }),
        ...sprints.value.map(sprint =>
          TicketsAPI.get({ sprint_id: sprint.id, status: 'open' })
        ),
      ]);

      state.backlogTickets = backlogResponse.data.payload;
      state.ticketsBySprint = Object.fromEntries(
        sprints.value.map((sprint, index) => [
          sprint.id,
          sprintResponses[index].data.payload,
        ])
      );
    } finally {
      state.isLoading = false;
    }
  };

  // O quadro Kanban inteiro (`fetchBoard`) e' pesado - toda Mesa com varios
  // Estagios cheios de ticket vem junto - e so' a aba "Sprint ativo" precisa
  // dele. Antes ele entrava no MESMO `Promise.all` que busca os Sprints, e
  // por ser o mais lento dos tres, segurava a lista de Sprints (rapida) ate
  // ele terminar - um Sprint ja criado "demorava" a aparecer no Backlog so'
  // porque a tela esperava o quadro carregar sem precisar dele. Agora o
  // quadro so' e' buscado quando `ensureBoardLoaded` e' chamado (ver
  // `BacklogPage.vue`, ao entrar na aba "Sprint ativo").
  const loadTeamData = async () => {
    if (!state.selectedTeamId) return;

    await Promise.all([
      store.dispatch('ticketColumns/fetchSprints', state.selectedTeamId),
      store.dispatch('ticketColumns/fetchColumns', state.selectedTeamId),
      store.dispatch('teamMembers/get', { teamId: state.selectedTeamId }),
    ]);
    await loadBucketTickets();

    // So' redefine o Sprint do quadro quando o escolhido nao existe mais
    // (Mesa trocada, ou aquele Sprint foi concluido e saiu da lista) - trocar
    // sempre que a lista chega de novo tiraria a pessoa do Sprint que estava
    // olhando a cada acao (criar outro Sprint, mover um ticket...).
    const stillExists = sprints.value.some(
      sprint => sprint.id === state.boardSprintId
    );
    if (!stillExists) {
      state.boardSprintId = currentSprint.value?.id || null;
    }
  };

  // Chamado so' quando a tela de Sprint ativo de fato precisa do quadro -
  // mantem o Backlog rapido, sem puxar o board por nada.
  const ensureBoardLoaded = () => {
    if (!state.selectedTeamId) return;

    store.dispatch('ticketColumns/fetchBoard', state.selectedTeamId);
  };

  const createSprint = async ({ name, startsOn, endsOn }) => {
    state.isCreatingSprint = true;
    try {
      await store.dispatch('ticketColumns/createSprint', {
        teamId: state.selectedTeamId,
        name,
        starts_on: startsOn,
        ends_on: endsOn,
      });
      await loadBucketTickets();
    } finally {
      state.isCreatingSprint = false;
    }
  };

  // Arrastar um cartao entre baldes so' muda `sprint_id` - a mesma troca de
  // propriedade que a tela de detalhe ja faz, so' que aqui e' o
  // arrastar-e-soltar quem decide o valor. O `vuedraggable` ja tirou o
  // cartao de um balde e colocou no outro ANTES deste metodo rodar - se o
  // servidor recusar (por exemplo, um agente sem permissao sobre aquele
  // ticket), recarregar os baldes desfaz a mudanca visual, em vez de deixar
  // o cartao no lugar errado sem avisar ninguem.
  const moveTicketToSprint = async (ticketId, sprintId) => {
    try {
      await TicketsAPI.update(ticketId, { ticket: { sprint_id: sprintId } });
    } catch (error) {
      useAlert(t('TICKET.API.ERROR_MESSAGE'));
    } finally {
      await loadBucketTickets();
    }
  };

  const selectBoardSprint = sprintId => {
    state.boardSprintId = sprintId ? Number(sprintId) : null;
  };

  // Trocar o Estagio direto pela linha (Backlog ou Sprint), sem arrastar -
  // a mesma acao de mover do quadro, so' que disparada pelo seletor da
  // linha. Sem `position`: o servidor poe o ticket no fim do Estagio novo.
  const moveTicketToColumn = async (ticketId, ticketColumnId) => {
    try {
      await store.dispatch('ticketColumns/moveTicket', {
        teamId: state.selectedTeamId,
        id: ticketId,
        ticketColumnId,
      });
    } catch (error) {
      useAlert(parseAPIErrorResponse(error) || t('TICKET.API.MOVE_ERROR'));
    } finally {
      await loadBucketTickets();
    }
  };

  // Mover entre Estagios dentro da tela de Sprint ativo e' a MESMA acao
  // operacional do Kanban (`TicketsPage.vue#moveTicket`) - so' reaproveitada
  // aqui, erro tratado do mesmo jeito.
  const moveTicketInBoard = async ({ ticketId, ticketColumnId, position }) => {
    try {
      await store.dispatch('ticketColumns/moveTicket', {
        teamId: state.selectedTeamId,
        id: ticketId,
        ticketColumnId,
        position,
      });
    } catch (error) {
      useAlert(parseAPIErrorResponse(error) || t('TICKET.API.MOVE_ERROR'));
    }
  };

  // Troca qual Sprint abre por padrao na tela de Sprint ativo - nao fecha
  // nada. `Sprint#activate!` ja' cuida de desativar o anterior da mesma Mesa.
  const activateSprint = async sprintId => {
    try {
      await store.dispatch('ticketColumns/activateSprint', {
        teamId: state.selectedTeamId,
        sprintId,
      });
    } catch (error) {
      useAlert(t('TICKET.API.ERROR_MESSAGE'));
    }
  };

  // Edicao em massa: aplica a MESMA mudanca a uma lista de tickets, em
  // paralelo, e so' recarrega os baldes uma vez no final - em vez de um
  // `loadBucketTickets` por ticket, o que refaria a mesma busca N vezes.
  // `patch` e' o que `TicketsAPI.update` ja aceita hoje (sprint_id,
  // assignee_id, priority...) - igual as trocas de campo unico ja feitas
  // pela linha, so' que pra varios tickets de uma vez.
  const bulkUpdateTickets = async (ticketIds, patch) => {
    if (!ticketIds.length) return;

    state.isLoading = true;
    try {
      const results = await Promise.allSettled(
        ticketIds.map(id => TicketsAPI.update(id, { ticket: patch }))
      );
      const failed = results.filter(result => result.status === 'rejected');
      if (failed.length) {
        useAlert(
          t('TICKET.BACKLOG.BULK_PARTIAL_ERROR', {
            count: failed.length,
            total: ticketIds.length,
          })
        );
      }
    } finally {
      await loadBucketTickets();
      state.isLoading = false;
    }
  };

  // Trocar o Estagio em massa precisa do endpoint `move` (nao do `update`
  // comum) - mesma razao de `moveTicketToColumn`, so' que para varios
  // tickets de uma vez.
  const bulkMoveToColumn = async (ticketIds, ticketColumnId) => {
    if (!ticketIds.length) return;

    state.isLoading = true;
    try {
      const results = await Promise.allSettled(
        ticketIds.map(id =>
          store.dispatch('ticketColumns/moveTicket', {
            teamId: state.selectedTeamId,
            id,
            ticketColumnId,
          })
        )
      );
      const failed = results.filter(result => result.status === 'rejected');
      if (failed.length) {
        useAlert(
          t('TICKET.BACKLOG.BULK_PARTIAL_ERROR', {
            count: failed.length,
            total: ticketIds.length,
          })
        );
      }
    } finally {
      await loadBucketTickets();
      state.isLoading = false;
    }
  };

  // Fecha o Sprint: o que ainda nao chegou no Estagio final da Mesa vai pro
  // proximo Sprint (ou pro Backlog, sem um proximo) - `Sprint#conclude!`
  // decide isso no servidor. Recarrega tudo depois, porque sprints, baldes do
  // Backlog e o quadro mudam juntos.
  const concludeSprint = async sprintId => {
    try {
      await store.dispatch('ticketColumns/concludeSprint', {
        teamId: state.selectedTeamId,
        sprintId,
      });
    } catch (error) {
      useAlert(t('TICKET.API.ERROR_MESSAGE'));
    } finally {
      await loadTeamData();
      ensureBoardLoaded();
    }
  };

  watch(devTeams, restoreLastTeam, { immediate: true });
  watch(() => state.selectedTeamId, loadTeamData);

  return {
    devTeams,
    sprints,
    board,
    currentSprint,
    mesaAgents,
    columns,
    state,
    selectTeam,
    selectBoardSprint,
    ensureBoardLoaded,
    createSprint,
    moveTicketToSprint,
    moveTicketToColumn,
    moveTicketInBoard,
    bulkUpdateTickets,
    bulkMoveToColumn,
    activateSprint,
    concludeSprint,
    reload: loadTeamData,
  };
}
