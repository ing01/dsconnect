<script setup>
/**
 * Configurações > Tickets > Mensagens ao cliente.
 *
 * Cada mensagem diz: "quando o ticket ENTRAR neste Estágio (ou PASSAR para esta
 * Mesa), envie este texto ao solicitante". O texto aceita variáveis ({{numero}},
 * {{estagio}}...), trocadas pelos dados do ticket no envio.
 *
 * É a tela central dessas mensagens; a ação "enviar mensagem ao cliente" da
 * Automação de Estágio continua existindo, mas esta tem as variáveis e mostra
 * tudo num lugar só.
 */
import { computed, nextTick, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NoticesAPI from 'dashboard/api/ticketCustomerNoticeRules';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const VARIABLES = [
  'numero',
  'titulo',
  'cliente',
  'solicitante',
  'responsavel',
  'estagio',
  'mesa',
  'mesa_anterior',
];

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const teams = computed(() => getters['teams/getTeams'].value);
const rules = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const pendingDelete = ref(null);

const emptyForm = () => ({
  id: null,
  kind: 'stage',
  name: '',
  team_id: '',
  ticket_column_id: '',
  from_team_id: '',
  body: '',
  notify_customer: true,
  active: true,
});
// As chaves duplas entram como valor do parametro: escritas no texto da
// traducao, o vue-i18n as trata como sintaxe invalida e a tela nao renderiza.
const bodyPlaceholder = computed(() =>
  t('TICKET.SETTINGS.NOTICES.FORM.BODY_PLACEHOLDER', {
    solicitante: '{{solicitante}}',
    numero: '{{numero}}',
  })
);
const form = ref(emptyForm());
const showForm = ref(false);
const bodyField = ref(null);
const formAnchor = ref(null);

const columnsOf = teamId =>
  teamId ? store.getters['ticketColumns/getColumns'](Number(teamId)) || [] : [];

// No formulário, "Mesa" é a Mesa do Estágio (tipo stage) ou a Mesa de destino
// (tipo team); o Estágio só existe no primeiro caso.
const formColumns = computed(() => columnsOf(form.value.team_id));

const originTeams = computed(() =>
  teams.value.filter(team => team.id !== Number(form.value.team_id))
);

const isInvalid = computed(() => {
  const current = form.value;
  if (!current.name.trim() || !current.body.trim()) return true;
  if (current.kind === 'stage') return !current.ticket_column_id;
  return !current.team_id;
});

const teamName = id => {
  const team = teams.value.find(item => item.id === Number(id));
  return team ? formatMesaName(team.name) : '';
};

// O servidor guarda só o Estágio; a Mesa dele sai das colunas já carregadas.
const ownerTeamOfColumn = columnId =>
  teams.value.find(team =>
    columnsOf(team.id).some(column => column.id === columnId)
  );

const whenText = rule => {
  if (rule.kind === 'team') {
    const to = teamName(rule.team_id);
    return rule.from_team_id
      ? t('TICKET.SETTINGS.NOTICES.WHEN_TEAM_FROM', {
          from: teamName(rule.from_team_id),
          to,
        })
      : t('TICKET.SETTINGS.NOTICES.WHEN_TEAM', { to });
  }
  const owner = ownerTeamOfColumn(rule.ticket_column_id);
  const column = columnsOf(owner?.id).find(
    item => item.id === rule.ticket_column_id
  );
  return t('TICKET.SETTINGS.NOTICES.WHEN_STAGE', {
    stage: column?.name || `#${rule.ticket_column_id}`,
    team: owner ? formatMesaName(owner.name) : '',
  });
};

const aviso = error =>
  useAlert(
    parseAPIErrorResponse(error) || t('TICKET.SETTINGS.NOTICES.API.ERROR')
  );

const load = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('teams/get');
    await Promise.all(
      teams.value.map(team =>
        store.dispatch('ticketColumns/fetchColumns', team.id)
      )
    );
    const { data } = await NoticesAPI.get();
    rules.value = data.payload || [];
  } catch (error) {
    aviso(error);
  } finally {
    isLoading.value = false;
  }
};

const scrollToForm = async () => {
  await nextTick();
  formAnchor.value?.scrollIntoView?.({ behavior: 'smooth', block: 'start' });
};

const openCreate = () => {
  form.value = emptyForm();
  showForm.value = true;
  scrollToForm();
};

const openEdit = rule => {
  const teamId =
    rule.kind === 'stage'
      ? ownerTeamOfColumn(rule.ticket_column_id)?.id
      : rule.team_id;
  form.value = {
    id: rule.id,
    kind: rule.kind,
    name: rule.name,
    team_id: teamId || '',
    ticket_column_id: rule.ticket_column_id || '',
    from_team_id: rule.from_team_id || '',
    body: rule.body,
    notify_customer: rule.notify_customer,
    active: rule.active,
  };
  showForm.value = true;
  scrollToForm();
};

const closeForm = () => {
  showForm.value = false;
};

// Trocar o tipo ou a Mesa invalida o que dependia dela.
const onKindChange = () => {
  form.value.ticket_column_id = '';
  form.value.from_team_id = '';
};
const onTeamChange = () => {
  form.value.ticket_column_id = '';
  if (String(form.value.from_team_id) === String(form.value.team_id)) {
    form.value.from_team_id = '';
  }
};

const payload = () => {
  const current = form.value;
  const base = {
    kind: current.kind,
    name: current.name.trim(),
    body: current.body.trim(),
    notify_customer: current.notify_customer,
    active: current.active,
  };
  return current.kind === 'stage'
    ? { ...base, ticket_column_id: current.ticket_column_id }
    : {
        ...base,
        team_id: current.team_id,
        from_team_id: current.from_team_id || null,
      };
};

const submit = async () => {
  if (isInvalid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    if (form.value.id) {
      await NoticesAPI.update(form.value.id, {
        ticket_customer_notice_rule: payload(),
      });
    } else {
      await NoticesAPI.create({ ticket_customer_notice_rule: payload() });
    }
    showForm.value = false;
    await load();
  } catch (error) {
    aviso(error);
  } finally {
    isSubmitting.value = false;
  }
};

const toggleActive = async rule => {
  try {
    await NoticesAPI.update(rule.id, {
      ticket_customer_notice_rule: { active: !rule.active },
    });
    rules.value = rules.value.map(item =>
      item.id === rule.id ? { ...item, active: !rule.active } : item
    );
  } catch (error) {
    aviso(error);
  }
};

const confirmDelete = async () => {
  const rule = pendingDelete.value;
  pendingDelete.value = null;
  if (!rule) return;

  try {
    await NoticesAPI.delete(rule.id);
    rules.value = rules.value.filter(item => item.id !== rule.id);
  } catch (error) {
    aviso(error);
  }
};

// Insere {{variavel}} onde o cursor está no texto, em vez de só no fim.
const insertVariable = async name => {
  const token = `{{${name}}}`;
  const field = bodyField.value;
  const text = form.value.body;
  const start = field?.selectionStart ?? text.length;
  const end = field?.selectionEnd ?? text.length;
  form.value.body = `${text.slice(0, start)}${token}${text.slice(end)}`;
  await nextTick();
  field?.focus?.();
  field?.setSelectionRange?.(start + token.length, start + token.length);
};

onBeforeMount(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('TICKET.SETTINGS.LOADING')"
    :no-records-found="!isLoading && !teams.length"
    :no-records-message="t('TICKET.SETTINGS.NO_MESA')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.NOTICES.TITLE')"
        :description="t('TICKET.SETTINGS.NOTICES.DESCRIPTION')"
      >
        <template #actions>
          <Button
            size="sm"
            icon="i-lucide-plus"
            :label="t('TICKET.SETTINGS.NOTICES.ADD')"
            data-testid="notice-add"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4 min-w-0">
        <form
          v-if="showForm"
          ref="formAnchor"
          class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak min-w-0"
          data-testid="notice-form"
          @submit.prevent="submit"
        >
          <h3 class="m-0 text-base font-medium text-n-slate-12">
            {{
              form.id
                ? t('TICKET.SETTINGS.NOTICES.FORM.EDIT_TITLE')
                : t('TICKET.SETTINGS.NOTICES.FORM.NEW_TITLE')
            }}
          </h3>

          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.NOTICES.FORM.NAME') }}
            </span>
            <input
              v-model="form.name"
              type="text"
              class="w-full mb-0"
              maxlength="120"
              :placeholder="t('TICKET.SETTINGS.NOTICES.FORM.NAME_PLACEHOLDER')"
              data-testid="notice-name"
            />
          </label>

          <fieldset class="flex flex-col gap-2 p-0 m-0 border-0 min-w-0">
            <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.NOTICES.FORM.WHEN') }}
            </legend>
            <div class="flex flex-wrap gap-2">
              <label
                v-for="kind in ['stage', 'team']"
                :key="kind"
                class="flex items-center gap-2 px-3 py-2 text-sm border rounded-lg cursor-pointer min-w-0"
                :class="
                  form.kind === kind
                    ? 'border-n-brand bg-n-alpha-2 text-n-slate-12'
                    : 'border-n-weak text-n-slate-11'
                "
              >
                <input
                  v-model="form.kind"
                  type="radio"
                  name="notice-kind"
                  class="m-0"
                  :value="kind"
                  :data-testid="`notice-kind-${kind}`"
                  @change="onKindChange"
                />
                {{ t(`TICKET.SETTINGS.NOTICES.KIND.${kind.toUpperCase()}`) }}
              </label>
            </div>

            <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 min-w-0">
              <label class="flex flex-col gap-1 min-w-0">
                <span class="text-xs text-n-slate-11">
                  {{
                    form.kind === 'stage'
                      ? t('TICKET.SETTINGS.NOTICES.FORM.TEAM')
                      : t('TICKET.SETTINGS.NOTICES.FORM.TO_TEAM')
                  }}
                </span>
                <select
                  v-model="form.team_id"
                  class="w-full mb-0"
                  data-testid="notice-team"
                  @change="onTeamChange"
                >
                  <option value="">
                    {{ t('TICKET.SETTINGS.NOTICES.FORM.CHOOSE') }}
                  </option>
                  <option v-for="team in teams" :key="team.id" :value="team.id">
                    {{ formatMesaName(team.name) }}
                  </option>
                </select>
              </label>

              <label
                v-if="form.kind === 'stage'"
                class="flex flex-col gap-1 min-w-0"
              >
                <span class="text-xs text-n-slate-11">
                  {{ t('TICKET.SETTINGS.NOTICES.FORM.STAGE') }}
                </span>
                <select
                  v-model="form.ticket_column_id"
                  class="w-full mb-0"
                  :disabled="!form.team_id"
                  data-testid="notice-stage"
                >
                  <option value="">
                    {{
                      form.team_id
                        ? t('TICKET.SETTINGS.NOTICES.FORM.CHOOSE')
                        : t('TICKET.SETTINGS.NOTICES.FORM.CHOOSE_TEAM_FIRST')
                    }}
                  </option>
                  <option
                    v-for="column in formColumns"
                    :key="column.id"
                    :value="column.id"
                  >
                    {{ column.name }}
                  </option>
                </select>
              </label>

              <label v-else class="flex flex-col gap-1 min-w-0">
                <span class="text-xs text-n-slate-11">
                  {{ t('TICKET.SETTINGS.NOTICES.FORM.FROM_TEAM') }}
                </span>
                <select
                  v-model="form.from_team_id"
                  class="w-full mb-0"
                  data-testid="notice-from-team"
                >
                  <option value="">
                    {{ t('TICKET.SETTINGS.NOTICES.FORM.ANY_TEAM') }}
                  </option>
                  <option
                    v-for="team in originTeams"
                    :key="team.id"
                    :value="team.id"
                  >
                    {{ formatMesaName(team.name) }}
                  </option>
                </select>
              </label>
            </div>
          </fieldset>

          <div class="flex flex-col gap-2 min-w-0">
            <label
              class="text-sm font-medium text-n-slate-12"
              for="notice-body"
            >
              {{ t('TICKET.SETTINGS.NOTICES.FORM.BODY') }}
            </label>
            <textarea
              id="notice-body"
              ref="bodyField"
              v-model="form.body"
              rows="6"
              class="w-full mb-0"
              :placeholder="bodyPlaceholder"
              data-testid="notice-body"
            />
            <div class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11">
                {{ t('TICKET.SETTINGS.NOTICES.FORM.VARIABLES_HINT') }}
              </span>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="variable in VARIABLES"
                  :key="variable"
                  type="button"
                  class="px-2 py-1 text-xs border rounded-full border-n-weak bg-n-alpha-1 text-n-slate-12 hover:border-n-brand"
                  :data-testid="`notice-var-${variable}`"
                  @click="insertVariable(variable)"
                >
                  {{
                    t(
                      `TICKET.SETTINGS.NOTICES.VARIABLES.${variable.toUpperCase()}`
                    )
                  }}
                </button>
              </div>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <label class="flex items-start gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.notify_customer"
                type="checkbox"
                class="mt-0.5 shrink-0"
                data-testid="notice-notify"
              />
              <span>
                {{ t('TICKET.SETTINGS.NOTICES.FORM.NOTIFY') }}
                <span class="block text-xs text-n-slate-11">
                  {{ t('TICKET.SETTINGS.NOTICES.FORM.NOTIFY_HINT') }}
                </span>
              </span>
            </label>
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.active"
                type="checkbox"
                class="shrink-0"
                data-testid="notice-active"
              />
              {{ t('TICKET.SETTINGS.NOTICES.FORM.ACTIVE') }}
            </label>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              type="submit"
              :is-loading="isSubmitting"
              :disabled="isInvalid"
              :label="
                form.id
                  ? t('TICKET.SETTINGS.NOTICES.FORM.SAVE')
                  : t('TICKET.SETTINGS.NOTICES.FORM.CREATE')
              "
              data-testid="notice-submit"
            />
            <Button
              variant="faded"
              color="slate"
              size="sm"
              type="button"
              :label="t('TICKET.SETTINGS.NOTICES.FORM.CANCEL')"
              @click="closeForm"
            />
          </div>
        </form>

        <p
          v-if="pendingDelete"
          class="flex flex-wrap items-center justify-between gap-3 p-3 text-sm border rounded-lg border-n-amber-8 bg-n-amber-3 text-n-amber-11 min-w-0"
        >
          {{
            t('TICKET.SETTINGS.NOTICES.DELETE_CONFIRM', {
              name: pendingDelete.name,
            })
          }}
          <span class="flex items-center flex-shrink-0 gap-2">
            <Button
              size="sm"
              color="ruby"
              :label="t('TICKET.SETTINGS.NOTICES.DELETE')"
              data-testid="notice-delete-confirm"
              @click="confirmDelete"
            />
            <Button
              variant="faded"
              color="slate"
              size="sm"
              :label="t('TICKET.SETTINGS.NOTICES.FORM.CANCEL')"
              @click="pendingDelete = null"
            />
          </span>
        </p>

        <p
          v-if="!isLoading && !rules.length"
          class="p-6 m-0 text-sm text-center border border-dashed rounded-xl border-n-weak text-n-slate-11"
          data-testid="notice-empty"
        >
          {{ t('TICKET.SETTINGS.NOTICES.EMPTY') }}
        </p>

        <div class="grid grid-cols-1 gap-3 lg:grid-cols-2 min-w-0">
          <article
            v-for="rule in rules"
            :key="rule.id"
            class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1 min-w-0"
            :class="{ 'opacity-60': !rule.active }"
            :data-testid="`notice-${rule.id}`"
          >
            <div class="flex items-start justify-between gap-3 min-w-0">
              <div class="flex flex-col gap-1 min-w-0">
                <h4 class="m-0 text-base font-medium truncate text-n-slate-12">
                  {{ rule.name }}
                </h4>
                <p
                  class="flex items-center gap-1.5 m-0 text-xs text-n-slate-11"
                >
                  <Icon
                    :icon="
                      rule.kind === 'stage'
                        ? 'i-lucide-columns-3'
                        : 'i-lucide-arrow-right-left'
                    "
                    class="size-3.5 shrink-0"
                  />
                  <span class="min-w-0 truncate">{{ whenText(rule) }}</span>
                </p>
              </div>
              <span
                v-if="!rule.active"
                class="flex-shrink-0 px-1.5 py-0.5 text-xs rounded-full bg-n-slate-3 text-n-slate-11"
              >
                {{ t('TICKET.SETTINGS.NOTICES.INACTIVE') }}
              </span>
            </div>

            <p
              class="m-0 text-sm whitespace-pre-line text-n-slate-11 line-clamp-4"
            >
              {{ rule.body }}
            </p>

            <div
              class="flex flex-wrap items-center justify-between gap-2 mt-auto"
            >
              <span class="flex items-center gap-1 text-xs text-n-slate-10">
                <Icon
                  :icon="
                    rule.notify_customer
                      ? 'i-lucide-mail'
                      : 'i-lucide-notebook-pen'
                  "
                  class="size-3.5"
                />
                {{
                  rule.notify_customer
                    ? t('TICKET.SETTINGS.NOTICES.BY_EMAIL')
                    : t('TICKET.SETTINGS.NOTICES.REGISTER_ONLY')
                }}
              </span>
              <div class="flex items-center gap-1">
                <Button
                  v-tooltip.top="
                    rule.active
                      ? t('TICKET.SETTINGS.NOTICES.DEACTIVATE')
                      : t('TICKET.SETTINGS.NOTICES.ACTIVATE')
                  "
                  variant="ghost"
                  color="slate"
                  size="sm"
                  :icon="rule.active ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                  :aria-label="
                    rule.active
                      ? t('TICKET.SETTINGS.NOTICES.DEACTIVATE')
                      : t('TICKET.SETTINGS.NOTICES.ACTIVATE')
                  "
                  :data-testid="`notice-toggle-${rule.id}`"
                  @click="toggleActive(rule)"
                />
                <Button
                  v-tooltip.top="t('TICKET.SETTINGS.NOTICES.EDIT')"
                  variant="ghost"
                  color="slate"
                  size="sm"
                  icon="i-lucide-pencil"
                  :aria-label="t('TICKET.SETTINGS.NOTICES.EDIT')"
                  :data-testid="`notice-edit-${rule.id}`"
                  @click="openEdit(rule)"
                />
                <Button
                  v-tooltip.top="t('TICKET.SETTINGS.NOTICES.DELETE')"
                  variant="ghost"
                  color="ruby"
                  size="sm"
                  icon="i-lucide-trash-2"
                  :aria-label="t('TICKET.SETTINGS.NOTICES.DELETE')"
                  :data-testid="`notice-delete-${rule.id}`"
                  @click="pendingDelete = rule"
                />
              </div>
            </div>
          </article>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
