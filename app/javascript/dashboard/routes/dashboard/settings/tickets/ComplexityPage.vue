<script setup>
/**
 * Configurações > Tickets > Complexidade.
 *
 * Uma linha por nível e uma coluna por Mesa: a matriz do próprio pedido. Marcar a
 * célula é dizer que aquela Mesa oferece aquele nível.
 *
 * Diferente das Categorias e dos Estágios, esta tela NÃO tem seletor de Mesa: a
 * lista é da conta, e o que se configura aqui é justamente a relação entre as
 * duas coisas - ver uma Mesa por vez esconderia exatamente o que a tela existe
 * para mostrar.
 *
 * Nenhum nome vem do código. Os três iniciais são semeados pelo servidor na
 * primeira leitura, e a partir daí criar, renomear, reordenar e desativar é dado.
 */
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const teams = computed(() => getters['teams/getTeams'].value);
const complexities = computed(
  () => getters['ticketComplexities/getComplexities'].value
);
const uiFlags = computed(() => getters['ticketComplexities/getUIFlags'].value);

// O nível em edição, ou `null` quando o formulário está criando um novo.
const editing = ref(null);
const name = ref('');
const showForm = ref(false);
const isSubmitting = ref(false);
const pendingDelete = ref(null);

const isInvalid = computed(() => !name.value.trim());

const tableHeaders = computed(() => [
  t('TICKET.SETTINGS.COMPLEXITY.TABLE.NAME'),
  ...teams.value.map(team => formatMesaName(team.name)),
  t('TICKET.SETTINGS.COMPLEXITY.TABLE.ACTIONS'),
]);

const offersTeam = (complexity, teamId) =>
  (complexity.team_ids || []).includes(teamId);

const openCreate = () => {
  editing.value = null;
  name.value = '';
  showForm.value = true;
};

const openEdit = complexity => {
  editing.value = complexity;
  name.value = complexity.name;
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
};

const aviso = error =>
  useAlert(
    parseAPIErrorResponse(error) || t('TICKET.SETTINGS.COMPLEXITY.API.ERROR')
  );

const submit = async () => {
  if (isInvalid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    if (editing.value) {
      await store.dispatch('ticketComplexities/update', {
        id: editing.value.id,
        name: name.value.trim(),
      });
    } else {
      // Um nível novo já nasce disponível em todas as Mesas: a matriz existe para
      // RESTRINGIR, e nascer indisponível em todas o tornaria invisível sem que
      // nada na tela dissesse por quê.
      await store.dispatch('ticketComplexities/create', {
        name: name.value.trim(),
        team_ids: teams.value.map(team => team.id),
      });
    }
    showForm.value = false;
  } catch (error) {
    aviso(error);
  } finally {
    isSubmitting.value = false;
  }
};

// Marcar e desmarcar a célula é a mesma ação: o servidor recebe o conjunto
// completo de Mesas daquele nível.
const toggleTeam = async (complexity, teamId) => {
  const atuais = complexity.team_ids || [];
  const proximos = atuais.includes(teamId)
    ? atuais.filter(id => id !== teamId)
    : [...atuais, teamId];

  try {
    await store.dispatch('ticketComplexities/update', {
      id: complexity.id,
      team_ids: proximos,
    });
  } catch (error) {
    aviso(error);
  }
};

// Desativar é o caminho comum: o nível sai dos formulários e continua nos
// tickets que já o usam.
const toggleActive = async complexity => {
  try {
    await store.dispatch('ticketComplexities/update', {
      id: complexity.id,
      active: !complexity.active,
    });
  } catch (error) {
    aviso(error);
  }
};

const confirmDelete = async () => {
  const complexity = pendingDelete.value;
  pendingDelete.value = null;
  if (!complexity) return;

  try {
    await store.dispatch('ticketComplexities/delete', complexity.id);
  } catch (error) {
    aviso(error);
  }
};

onBeforeMount(async () => {
  await store.dispatch('teams/get');
  await store.dispatch('ticketComplexities/fetch');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('TICKET.SETTINGS.LOADING')"
    :no-records-found="!teams.length"
    :no-records-message="t('TICKET.SETTINGS.NO_MESA')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.COMPLEXITY.TITLE')"
        :description="t('TICKET.SETTINGS.COMPLEXITY.DESCRIPTION')"
      >
        <template #actions>
          <Button
            size="sm"
            :label="t('TICKET.SETTINGS.COMPLEXITY.ADD')"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4 min-w-0">
        <!-- Criar e renomear usam o mesmo formulário: os campos são os mesmos, e
             duas telas para isso divergiriam na primeira mudança. -->
        <form
          v-if="showForm"
          class="flex flex-wrap items-end gap-3 p-4 border rounded-xl border-n-weak min-w-0"
          @submit.prevent="submit"
        >
          <label class="flex flex-col gap-1 grow min-w-48">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.COMPLEXITY.FORM.NAME') }}
            </span>
            <input
              v-model="name"
              type="text"
              class="w-full mb-0"
              :placeholder="
                t('TICKET.SETTINGS.COMPLEXITY.FORM.NAME_PLACEHOLDER')
              "
            />
          </label>
          <div class="flex items-center flex-shrink-0 gap-2">
            <Button
              size="sm"
              type="submit"
              :is-loading="isSubmitting"
              :disabled="isInvalid"
              :label="
                editing
                  ? t('TICKET.SETTINGS.COMPLEXITY.FORM.SAVE')
                  : t('TICKET.SETTINGS.COMPLEXITY.FORM.CREATE')
              "
            />
            <Button
              variant="faded"
              color="slate"
              size="sm"
              type="button"
              :label="t('TICKET.SETTINGS.COMPLEXITY.FORM.CANCEL')"
              @click="closeForm"
            />
          </div>
        </form>

        <p
          v-if="pendingDelete"
          class="flex flex-wrap items-center justify-between gap-3 p-3 text-sm border rounded-lg border-n-amber-8 bg-n-amber-3 text-n-amber-11 min-w-0"
        >
          {{
            t('TICKET.SETTINGS.COMPLEXITY.DELETE_CONFIRM', {
              name: pendingDelete.name,
            })
          }}
          <span class="flex items-center flex-shrink-0 gap-2">
            <Button
              size="sm"
              color="ruby"
              :label="t('TICKET.SETTINGS.COMPLEXITY.DELETE')"
              @click="confirmDelete"
            />
            <Button
              variant="faded"
              color="slate"
              size="sm"
              :label="t('TICKET.SETTINGS.COMPLEXITY.FORM.CANCEL')"
              @click="pendingDelete = null"
            />
          </span>
        </p>

        <BaseTable
          :headers="tableHeaders"
          :items="complexities"
          :no-data-message="t('TICKET.SETTINGS.COMPLEXITY.EMPTY')"
        >
          <template #row="{ items }">
            <BaseTableRow v-for="complexity in items" :key="complexity.id">
              <BaseTableCell>
                <span class="flex items-center gap-2 min-w-0">
                  <span
                    class="text-sm truncate"
                    :class="
                      complexity.active ? 'text-n-slate-12' : 'text-n-slate-10'
                    "
                  >
                    {{ complexity.name }}
                  </span>
                  <!-- Desativado continua na tabela: ele segue nos tickets que o
                       usam, e esconder faria parecer que foi apagado. -->
                  <span
                    v-if="!complexity.active"
                    class="flex-shrink-0 px-1.5 py-0.5 text-xs rounded-full bg-n-slate-3 text-n-slate-11"
                  >
                    {{ t('TICKET.SETTINGS.COMPLEXITY.INACTIVE') }}
                  </span>
                </span>
              </BaseTableCell>

              <BaseTableCell v-for="team in teams" :key="team.id">
                <Button
                  v-tooltip.top="
                    offersTeam(complexity, team.id)
                      ? t('TICKET.SETTINGS.COMPLEXITY.AVAILABLE')
                      : t('TICKET.SETTINGS.COMPLEXITY.UNAVAILABLE')
                  "
                  variant="ghost"
                  size="sm"
                  type="button"
                  :color="offersTeam(complexity, team.id) ? 'teal' : 'slate'"
                  :icon="
                    offersTeam(complexity, team.id)
                      ? 'i-lucide-check'
                      : 'i-lucide-minus'
                  "
                  :aria-pressed="offersTeam(complexity, team.id)"
                  :aria-label="
                    offersTeam(complexity, team.id)
                      ? t('TICKET.SETTINGS.COMPLEXITY.AVAILABLE')
                      : t('TICKET.SETTINGS.COMPLEXITY.UNAVAILABLE')
                  "
                  @click="toggleTeam(complexity, team.id)"
                />
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex justify-end flex-shrink-0 gap-3">
                  <Button
                    v-tooltip.top="t('TICKET.SETTINGS.COMPLEXITY.EDIT')"
                    variant="ghost"
                    color="slate"
                    size="sm"
                    icon="i-lucide-pencil"
                    :aria-label="t('TICKET.SETTINGS.COMPLEXITY.EDIT')"
                    @click="openEdit(complexity)"
                  />
                  <Button
                    v-tooltip.top="
                      complexity.active
                        ? t('TICKET.SETTINGS.COMPLEXITY.DEACTIVATE')
                        : t('TICKET.SETTINGS.COMPLEXITY.ACTIVATE')
                    "
                    variant="ghost"
                    color="slate"
                    size="sm"
                    :icon="
                      complexity.active ? 'i-lucide-eye-off' : 'i-lucide-eye'
                    "
                    :aria-label="
                      complexity.active
                        ? t('TICKET.SETTINGS.COMPLEXITY.DEACTIVATE')
                        : t('TICKET.SETTINGS.COMPLEXITY.ACTIVATE')
                    "
                    @click="toggleActive(complexity)"
                  />
                  <Button
                    v-tooltip.top="t('TICKET.SETTINGS.COMPLEXITY.DELETE')"
                    variant="ghost"
                    color="ruby"
                    size="sm"
                    icon="i-lucide-trash-2"
                    :aria-label="t('TICKET.SETTINGS.COMPLEXITY.DELETE')"
                    @click="pendingDelete = complexity"
                  />
                </div>
              </BaseTableCell>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>
    </template>
  </SettingsLayout>
</template>
