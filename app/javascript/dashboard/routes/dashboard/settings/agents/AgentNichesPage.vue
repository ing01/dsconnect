<script setup>
/**
 * Configurações > Nichos por agente: os Nichos e Sub-nichos de empresa que cada analista atende.
 * Por enquanto é só cadastro e consulta - nada muda sozinho nas empresas a partir daqui. Dois
 * analistas podem dividir o mesmo sub-nicho. A busca acha pelo nome do agente OU pelo nicho.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgentNichesAPI from 'dashboard/api/agentNiches';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  namesFor,
  filterAgents,
  filterItems,
  toggleId,
  sameIds,
} from './agentNichesHelper';

const { t } = useI18n();

const agents = ref([]);
const niches = ref([]);
const subNiches = ref([]);
const isLoading = ref(true);
const query = ref('');

const editingId = ref(null);
const draft = ref({ nicheIds: [], subNicheIds: [] });
const nicheQuery = ref('');
const subNicheQuery = ref('');
const isSaving = ref(false);

const visibleAgents = computed(() =>
  filterAgents(agents.value, query.value, niches.value, subNiches.value)
);
const editingAgent = computed(() =>
  agents.value.find(agent => agent.id === editingId.value)
);
const hasChanges = computed(
  () =>
    !!editingAgent.value &&
    (!sameIds(draft.value.nicheIds, editingAgent.value.niche_ids) ||
      !sameIds(draft.value.subNicheIds, editingAgent.value.sub_niche_ids))
);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await AgentNichesAPI.list();
    agents.value = data.agents;
    niches.value = data.niches;
    subNiches.value = data.sub_niches;
  } catch (error) {
    useAlert(t('AGENT_NICHES.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const startEditing = agent => {
  editingId.value = agent.id;
  draft.value = {
    nicheIds: [...agent.niche_ids],
    subNicheIds: [...agent.sub_niche_ids],
  };
  nicheQuery.value = '';
  subNicheQuery.value = '';
};

const stopEditing = () => {
  editingId.value = null;
};

const save = async () => {
  if (!editingAgent.value || isSaving.value) return;

  isSaving.value = true;
  try {
    const { data } = await AgentNichesAPI.save(
      editingAgent.value.id,
      draft.value
    );
    agents.value = agents.value.map(agent =>
      agent.id === data.id ? data : agent
    );
    useAlert(t('AGENT_NICHES.SAVED'));
    stopEditing();
  } catch (error) {
    useAlert(error?.response?.data?.message || t('AGENT_NICHES.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('AGENT_NICHES.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('AGENT_NICHES.TITLE')"
        :description="t('AGENT_NICHES.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-4 min-w-0" data-testid="agent-niches">
        <input
          v-model="query"
          type="search"
          class="w-full mb-0 text-sm"
          :placeholder="t('AGENT_NICHES.SEARCH')"
          data-testid="agent-niches-search"
        />

        <p
          v-if="!visibleAgents.length"
          class="m-0 text-sm text-n-slate-11"
          data-testid="agent-niches-empty"
        >
          {{ t('AGENT_NICHES.EMPTY') }}
        </p>

        <article
          v-for="agent in visibleAgents"
          :key="agent.id"
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak min-w-0"
          :data-testid="`agent-${agent.id}`"
        >
          <header class="flex flex-wrap items-center justify-between gap-2">
            <div class="min-w-0">
              <h3 class="m-0 text-base font-medium truncate text-n-slate-12">
                {{ agent.name }}
              </h3>
              <p class="m-0 text-xs text-n-slate-11">
                {{
                  t('AGENT_NICHES.COUNTS', {
                    niches: agent.niche_ids.length,
                    subNiches: agent.sub_niche_ids.length,
                  })
                }}
              </p>
            </div>
            <Button
              v-if="editingId !== agent.id"
              size="sm"
              faded
              slate
              icon="i-lucide-pencil"
              :label="t('AGENT_NICHES.EDIT')"
              :data-testid="`agent-edit-${agent.id}`"
              @click="startEditing(agent)"
            />
          </header>

          <!-- Consulta: o que o agente atende hoje. -->
          <div v-if="editingId !== agent.id" class="flex flex-col gap-2">
            <div
              class="flex flex-wrap gap-1.5"
              :data-testid="`agent-niches-${agent.id}`"
            >
              <span
                v-for="name in namesFor(agent.niche_ids, niches)"
                :key="`n-${name}`"
                class="px-2 py-0.5 text-xs font-medium rounded-md bg-n-blue-3 text-n-blue-11"
              >
                {{ name }}
              </span>
              <span
                v-if="!agent.niche_ids.length"
                class="text-xs text-n-slate-10"
              >
                {{ t('AGENT_NICHES.NO_NICHES') }}
              </span>
            </div>
            <div class="flex flex-wrap gap-1.5">
              <span
                v-for="name in namesFor(agent.sub_niche_ids, subNiches)"
                :key="`s-${name}`"
                class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{ name }}
              </span>
              <span
                v-if="!agent.sub_niche_ids.length"
                class="text-xs text-n-slate-10"
              >
                {{ t('AGENT_NICHES.NO_SUB_NICHES') }}
              </span>
            </div>
          </div>

          <!-- Edicao: duas listas marcaveis, cada uma com a sua busca. -->
          <div
            v-else
            class="flex flex-col gap-4"
            :data-testid="`agent-editor-${agent.id}`"
          >
            <div class="grid gap-4 md:grid-cols-2">
              <section class="flex flex-col gap-2 min-w-0">
                <h4 class="m-0 text-sm font-medium text-n-slate-12">
                  {{ t('AGENT_NICHES.NICHES') }}
                  <span class="font-normal text-n-slate-11">
                    ({{ draft.nicheIds.length }})
                  </span>
                </h4>
                <input
                  v-model="nicheQuery"
                  type="search"
                  class="w-full mb-0 text-sm"
                  :placeholder="t('AGENT_NICHES.FILTER')"
                />
                <ul class="m-0 overflow-y-auto list-none max-h-64">
                  <li
                    v-for="niche in filterItems(niches, nicheQuery)"
                    :key="niche.id"
                  >
                    <label
                      class="flex items-center gap-2 px-1 py-1 text-sm rounded cursor-pointer hover:bg-n-alpha-2"
                    >
                      <input
                        type="checkbox"
                        class="mb-0"
                        :checked="draft.nicheIds.includes(niche.id)"
                        :data-testid="`niche-${niche.id}`"
                        @change="
                          draft.nicheIds = toggleId(draft.nicheIds, niche.id)
                        "
                      />
                      {{ niche.name }}
                    </label>
                  </li>
                </ul>
              </section>

              <section class="flex flex-col gap-2 min-w-0">
                <h4 class="m-0 text-sm font-medium text-n-slate-12">
                  {{ t('AGENT_NICHES.SUB_NICHES') }}
                  <span class="font-normal text-n-slate-11">
                    ({{ draft.subNicheIds.length }})
                  </span>
                </h4>
                <input
                  v-model="subNicheQuery"
                  type="search"
                  class="w-full mb-0 text-sm"
                  :placeholder="t('AGENT_NICHES.FILTER')"
                />
                <ul class="m-0 overflow-y-auto list-none max-h-64">
                  <li
                    v-for="sub in filterItems(subNiches, subNicheQuery)"
                    :key="sub.id"
                  >
                    <label
                      class="flex items-center gap-2 px-1 py-1 text-sm rounded cursor-pointer hover:bg-n-alpha-2"
                    >
                      <input
                        type="checkbox"
                        class="mb-0"
                        :checked="draft.subNicheIds.includes(sub.id)"
                        :data-testid="`sub-niche-${sub.id}`"
                        @change="
                          draft.subNicheIds = toggleId(
                            draft.subNicheIds,
                            sub.id
                          )
                        "
                      />
                      {{ sub.name }}
                    </label>
                  </li>
                </ul>
              </section>
            </div>

            <div class="flex justify-end gap-2">
              <Button
                size="sm"
                faded
                slate
                :label="t('AGENT_NICHES.CANCEL')"
                :disabled="isSaving"
                @click="stopEditing"
              />
              <Button
                size="sm"
                :label="t('AGENT_NICHES.SAVE')"
                :is-loading="isSaving"
                :disabled="!hasChanges || isSaving"
                data-testid="agent-save"
                @click="save"
              />
            </div>
          </div>
        </article>
      </div>
    </template>
  </SettingsLayout>
</template>
