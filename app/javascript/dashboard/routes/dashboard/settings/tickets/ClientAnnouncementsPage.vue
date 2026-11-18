<script setup>
/**
 * Configurações > Avisos do Portal.
 *
 * O administrador cadastra os avisos do Mural de Avisos do Portal do Cliente:
 * título, texto simples, tipo (cor/ícone), período, link opcional e o público
 * (todos os clientes ou segmentado por Empresa, Nicho, Subnicho e Prioridade).
 * Dentro do período o aviso aparece na tela Principal do cliente e abre em
 * modal a cada login.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import ClientAnnouncementsAPI from 'dashboard/api/clientAnnouncements';
import CompanyNicheAPI from 'dashboard/api/companyNiches';
import CompanySubNicheAPI from 'dashboard/api/companySubNiches';
import CompanyAPI from 'dashboard/api/companies';
import { announcementKind } from 'dashboard/routes/client/announcementKinds';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmButton from 'dashboard/components-next/button/ConfirmButton.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const KINDS = ['info', 'warning', 'success', 'urgent'];
const LEVELS = [1, 2, 3];
const STATUS_CLASSES = {
  live: 'bg-n-teal-3 text-n-teal-11',
  scheduled: 'bg-n-blue-3 text-n-blue-11',
  expired: 'bg-n-slate-3 text-n-slate-11',
  inactive: 'bg-n-slate-3 text-n-slate-11',
};

const { t } = useI18n();

const announcements = ref([]);
const niches = ref([]);
const subNiches = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);

// Formulário: `editing` é o aviso em edição, ou null quando está criando.
const showForm = ref(false);
const editing = ref(null);
const title = ref('');
const body = ref('');
const kind = ref('info');
const startsAt = ref('');
const endsAt = ref('');
const linkUrl = ref('');
const linkLabel = ref('');
const active = ref(true);
const audience = ref('all');
const companyIds = ref([]);
const nicheIds = ref([]);
const subNicheIds = ref([]);
const levels = ref([]);

// Empresas escolhidas (id + nome, para mostrar as etiquetas) e a busca.
const selectedCompanies = ref([]);
const companyQuery = ref('');
const companyResults = ref([]);
const companySearched = ref(false);
let searchTimer = null;

const isInvalid = computed(() => {
  if (!title.value.trim()) return true;
  if (startsAt.value && endsAt.value && endsAt.value <= startsAt.value) {
    return true;
  }
  if (audience.value === 'segmented') {
    return ![
      companyIds.value,
      nicheIds.value,
      subNicheIds.value,
      levels.value,
    ].some(list => list.length);
  }
  return false;
});

const aviso = error =>
  useAlert(
    parseAPIErrorResponse(error) ||
      t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.API.ERROR')
  );

// <input type="datetime-local"> trabalha em hora local, sem fuso.
const toInputValue = iso => {
  if (!iso) return '';
  const date = new Date(iso);
  const pad = number => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};
const toIso = value => (value ? new Date(value).toISOString() : null);

const formatDate = iso =>
  new Date(iso).toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  });

const periodLabel = item =>
  t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.PERIOD', {
    start: item.starts_at
      ? formatDate(item.starts_at)
      : t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.NO_START'),
    end: item.ends_at
      ? formatDate(item.ends_at)
      : t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.NO_END'),
  });

const fetchAnnouncements = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClientAnnouncementsAPI.get();
    announcements.value = data;
  } catch (error) {
    aviso(error);
  } finally {
    isLoading.value = false;
  }
};

// Nichos/Subnichos só alimentam a segmentação: falhar não derruba a tela.
const fetchLists = async () => {
  const [nicheResponse, subNicheResponse] = await Promise.allSettled([
    CompanyNicheAPI.get(),
    CompanySubNicheAPI.get(),
  ]);
  if (nicheResponse.status === 'fulfilled') {
    niches.value = nicheResponse.value.data.payload || [];
  }
  if (subNicheResponse.status === 'fulfilled') {
    subNiches.value = subNicheResponse.value.data.payload || [];
  }
};

const resetForm = () => {
  editing.value = null;
  title.value = '';
  body.value = '';
  kind.value = 'info';
  startsAt.value = '';
  endsAt.value = '';
  linkUrl.value = '';
  linkLabel.value = '';
  active.value = true;
  audience.value = 'all';
  companyIds.value = [];
  nicheIds.value = [];
  subNicheIds.value = [];
  levels.value = [];
  selectedCompanies.value = [];
  companyQuery.value = '';
  companyResults.value = [];
  companySearched.value = false;
};

const openCreate = () => {
  resetForm();
  showForm.value = true;
};

const openEdit = item => {
  resetForm();
  editing.value = item;
  title.value = item.title;
  body.value = item.body || '';
  kind.value = item.kind;
  startsAt.value = toInputValue(item.starts_at);
  endsAt.value = toInputValue(item.ends_at);
  linkUrl.value = item.link_url || '';
  linkLabel.value = item.link_label || '';
  active.value = item.active;
  audience.value = item.audience;
  companyIds.value = [...item.company_ids];
  nicheIds.value = [...item.company_niche_ids];
  subNicheIds.value = [...item.company_sub_niche_ids];
  levels.value = [...item.client_levels];
  selectedCompanies.value = (item.companies || []).map(company => ({
    id: company.id,
    name: company.name,
  }));
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
  resetForm();
};

const toggleIn = (list, value) => {
  const index = list.value.indexOf(value);
  if (index === -1) list.value.push(value);
  else list.value.splice(index, 1);
};

const searchCompanies = async () => {
  const query = companyQuery.value.trim();
  if (!query) {
    companyResults.value = [];
    companySearched.value = false;
    return;
  }
  try {
    const { data } = await CompanyAPI.search(query);
    companyResults.value = data.payload || [];
  } catch {
    companyResults.value = [];
  } finally {
    companySearched.value = true;
  }
};

const onCompanyQuery = () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(searchCompanies, 300);
};

const addCompany = company => {
  if (!companyIds.value.includes(company.id)) {
    companyIds.value.push(company.id);
    selectedCompanies.value.push({ id: company.id, name: company.name });
  }
  companyQuery.value = '';
  companyResults.value = [];
  companySearched.value = false;
};

const removeCompany = id => {
  companyIds.value = companyIds.value.filter(item => item !== id);
  selectedCompanies.value = selectedCompanies.value.filter(
    item => item.id !== id
  );
};

const buildPayload = () => ({
  client_announcement: {
    title: title.value.trim(),
    body: body.value.trim(),
    kind: kind.value,
    starts_at: toIso(startsAt.value),
    ends_at: toIso(endsAt.value),
    link_url: linkUrl.value.trim(),
    link_label: linkLabel.value.trim(),
    active: active.value,
    audience: audience.value,
    // Array vazio precisa ir explícito, senão o Rails ignora e não limpa o filtro.
    company_ids: audience.value === 'segmented' ? companyIds.value : [],
    company_niche_ids: audience.value === 'segmented' ? nicheIds.value : [],
    company_sub_niche_ids:
      audience.value === 'segmented' ? subNicheIds.value : [],
    client_levels: audience.value === 'segmented' ? levels.value : [],
  },
});

const submit = async () => {
  if (isInvalid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const payload = buildPayload();
    if (editing.value) {
      await ClientAnnouncementsAPI.update(editing.value.id, payload);
    } else {
      await ClientAnnouncementsAPI.create(payload);
    }
    useAlert(t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.API.SAVED'));
    closeForm();
    await fetchAnnouncements();
  } catch (error) {
    aviso(error);
  } finally {
    isSubmitting.value = false;
  }
};

const toggleActive = async item => {
  try {
    await ClientAnnouncementsAPI.update(item.id, {
      client_announcement: { active: !item.active },
    });
    await fetchAnnouncements();
  } catch (error) {
    aviso(error);
  }
};

// Mesma regra dos Tutoriais: regrava a posição de todos pela ordem nova.
const move = async (index, delta) => {
  if (!announcements.value[index + delta]) return;

  const reordered = [...announcements.value];
  [reordered[index], reordered[index + delta]] = [
    reordered[index + delta],
    reordered[index],
  ];

  try {
    await Promise.all(
      reordered
        .map((item, position) => ({ item, position }))
        .filter(({ item, position }) => item.position !== position)
        .map(({ item, position }) =>
          ClientAnnouncementsAPI.update(item.id, {
            client_announcement: { position },
          })
        )
    );
    await fetchAnnouncements();
  } catch (error) {
    aviso(error);
  }
};

const remove = async item => {
  try {
    await ClientAnnouncementsAPI.delete(item.id);
    useAlert(t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.API.DELETED'));
    if (editing.value?.id === item.id) closeForm();
    await fetchAnnouncements();
  } catch (error) {
    aviso(error);
  }
};

const audienceLabel = item =>
  item.audience === 'segmented'
    ? t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.AUDIENCE_SEGMENTED')
    : t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.AUDIENCE_ALL');

const previewStyle = computed(() => announcementKind(kind.value));

onMounted(() => Promise.all([fetchAnnouncements(), fetchLists()]));
</script>

<template>
  <SettingsLayout :is-loading="isLoading">
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.TITLE')"
        :description="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            size="sm"
            icon="i-lucide-plus"
            :label="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.ADD')"
            data-testid="announcement-add"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4 min-w-0">
        <form
          v-if="showForm"
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak min-w-0"
          data-testid="announcement-form"
          @submit.prevent="submit"
        >
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.TITLE') }}
            </span>
            <input
              v-model="title"
              type="text"
              maxlength="200"
              class="w-full mb-0"
              data-testid="announcement-title"
              :placeholder="
                t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.TITLE_PLACEHOLDER')
              "
            />
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.BODY') }}
            </span>
            <textarea
              v-model="body"
              rows="5"
              maxlength="5000"
              class="w-full mb-0"
              data-testid="announcement-body"
            />
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.BODY_HELP') }}
            </span>
          </label>

          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.KIND') }}
            </span>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="option in KINDS"
                :key="option"
                type="button"
                class="inline-flex items-center gap-2 px-3 py-1 text-sm border rounded-lg"
                :class="
                  kind === option
                    ? `${announcementKind(option).card} text-n-slate-12 font-medium`
                    : 'border-n-weak text-n-slate-11'
                "
                :data-testid="`announcement-kind-${option}`"
                @click="kind = option"
              >
                <Icon :icon="announcementKind(option).icon" class="size-4" />
                {{ t(`TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.KIND.${option}`) }}
              </button>
            </div>
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.STARTS_AT') }}
              </span>
              <input
                v-model="startsAt"
                type="datetime-local"
                class="w-full mb-0"
                data-testid="announcement-starts-at"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.ENDS_AT') }}
              </span>
              <input
                v-model="endsAt"
                type="datetime-local"
                class="w-full mb-0"
                data-testid="announcement-ends-at"
              />
            </label>
          </div>
          <span class="-mt-2 text-xs text-n-slate-11">
            {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.PERIOD_HELP') }}
          </span>

          <div class="grid gap-3 sm:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.LINK_URL') }}
              </span>
              <input
                v-model="linkUrl"
                type="url"
                class="w-full mb-0"
                :placeholder="
                  t(
                    'TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.LINK_PLACEHOLDER'
                  )
                "
              />
            </label>
            <label v-if="linkUrl.trim()" class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.LINK_LABEL') }}
              </span>
              <input
                v-model="linkLabel"
                type="text"
                maxlength="60"
                class="w-full mb-0"
              />
            </label>
          </div>

          <!-- Público -->
          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.AUDIENCE') }}
            </span>
            <div class="flex flex-wrap gap-4 text-sm text-n-slate-12">
              <label class="flex items-center gap-2 mb-0">
                <input
                  v-model="audience"
                  type="radio"
                  value="all"
                  class="mb-0"
                  data-testid="announcement-audience-all"
                />
                {{
                  t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.AUDIENCE_ALL')
                }}
              </label>
              <label class="flex items-center gap-2 mb-0">
                <input
                  v-model="audience"
                  type="radio"
                  value="segmented"
                  class="mb-0"
                  data-testid="announcement-audience-segmented"
                />
                {{
                  t(
                    'TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.AUDIENCE_SEGMENTED'
                  )
                }}
              </label>
            </div>

            <div
              v-if="audience === 'segmented'"
              class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak"
              data-testid="announcement-segmentation"
            >
              <p class="m-0 text-xs text-n-slate-11">
                {{
                  t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.SEGMENT_HELP')
                }}
              </p>

              <div class="flex flex-col gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.LEVELS') }}
                </span>
                <div class="flex flex-wrap gap-3 text-sm text-n-slate-12">
                  <label
                    v-for="level in LEVELS"
                    :key="level"
                    class="flex items-center gap-2 mb-0"
                  >
                    <input
                      type="checkbox"
                      class="mb-0"
                      :checked="levels.includes(level)"
                      @change="toggleIn(levels, level)"
                    />
                    {{
                      t(`TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LEVEL.${level}`)
                    }}
                  </label>
                </div>
              </div>

              <div v-if="niches.length" class="flex flex-col gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.NICHES') }}
                </span>
                <div class="flex flex-wrap gap-3 text-sm text-n-slate-12">
                  <label
                    v-for="niche in niches"
                    :key="niche.id"
                    class="flex items-center gap-2 mb-0"
                  >
                    <input
                      type="checkbox"
                      class="mb-0"
                      :checked="nicheIds.includes(niche.id)"
                      @change="toggleIn(nicheIds, niche.id)"
                    />
                    {{ niche.name }}
                  </label>
                </div>
              </div>

              <div v-if="subNiches.length" class="flex flex-col gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{
                    t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.SUB_NICHES')
                  }}
                </span>
                <div class="flex flex-wrap gap-3 text-sm text-n-slate-12">
                  <label
                    v-for="subNiche in subNiches"
                    :key="subNiche.id"
                    class="flex items-center gap-2 mb-0"
                  >
                    <input
                      type="checkbox"
                      class="mb-0"
                      :checked="subNicheIds.includes(subNiche.id)"
                      @change="toggleIn(subNicheIds, subNiche.id)"
                    />
                    {{ subNiche.name }}
                  </label>
                </div>
              </div>

              <div class="flex flex-col gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.COMPANIES') }}
                </span>
                <div
                  v-if="selectedCompanies.length"
                  class="flex flex-wrap gap-2"
                >
                  <span
                    v-for="company in selectedCompanies"
                    :key="company.id"
                    class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-md bg-n-alpha-2 text-n-slate-12"
                  >
                    {{ company.name }}
                    <button
                      type="button"
                      class="p-0 text-n-slate-11 hover:text-n-ruby-11"
                      @click="removeCompany(company.id)"
                    >
                      <Icon icon="i-lucide-x" class="size-3" />
                    </button>
                  </span>
                </div>
                <input
                  v-model="companyQuery"
                  type="search"
                  class="w-full mb-0"
                  data-testid="announcement-company-search"
                  :placeholder="
                    t(
                      'TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.COMPANY_SEARCH'
                    )
                  "
                  @input="onCompanyQuery"
                />
                <ul
                  v-if="companyResults.length"
                  class="p-0 m-0 overflow-y-auto list-none border rounded-lg max-h-48 border-n-weak"
                >
                  <li v-for="company in companyResults" :key="company.id">
                    <button
                      type="button"
                      class="w-full px-3 py-2 text-sm text-left text-n-slate-12 hover:bg-n-alpha-2"
                      @click="addCompany(company)"
                    >
                      {{ company.name }}
                    </button>
                  </li>
                </ul>
                <p
                  v-else-if="companySearched && companyQuery.trim()"
                  class="m-0 text-xs text-n-slate-11"
                >
                  {{
                    t(
                      'TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.COMPANY_SEARCH_EMPTY'
                    )
                  }}
                </p>
              </div>
            </div>
          </div>

          <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
            <input v-model="active" type="checkbox" class="mb-0" />
            {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.ACTIVE') }}
          </label>

          <!-- Prévia do que o cliente verá -->
          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.PREVIEW') }}
            </span>
            <article
              class="flex items-start gap-3 p-4 border rounded-xl"
              :class="previewStyle.card"
              data-testid="announcement-preview"
            >
              <span
                class="flex items-center justify-center flex-shrink-0 rounded-full size-9"
                :class="previewStyle.iconWrap"
              >
                <Icon :icon="previewStyle.icon" class="size-4" />
              </span>
              <div class="flex flex-col min-w-0 gap-1">
                <h3
                  class="m-0 text-base font-semibold break-words text-n-slate-12"
                >
                  {{ title || '—' }}
                </h3>
                <p
                  v-if="body"
                  class="m-0 text-sm break-words whitespace-pre-line text-n-slate-12"
                >
                  {{ body }}
                </p>
              </div>
            </article>
          </div>

          <div class="flex justify-end gap-2">
            <Button
              type="button"
              slate
              faded
              size="sm"
              :label="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.CANCEL')"
              @click="closeForm"
            />
            <Button
              type="submit"
              size="sm"
              :label="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.SAVE')"
              :disabled="isInvalid"
              :is-loading="isSubmitting"
              data-testid="announcement-save"
            />
          </div>
        </form>

        <p
          v-if="!announcements.length && !showForm"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.EMPTY') }}
        </p>

        <ul class="flex flex-col gap-2 p-0 m-0 list-none">
          <li
            v-for="(item, index) in announcements"
            :key="item.id"
            class="flex flex-wrap items-center gap-3 p-3 border rounded-xl border-n-weak min-w-0"
            :data-testid="`announcement-row-${item.id}`"
          >
            <span
              class="flex items-center justify-center flex-shrink-0 rounded-full size-8"
              :class="announcementKind(item.kind).iconWrap"
            >
              <Icon :icon="announcementKind(item.kind).icon" class="size-4" />
            </span>

            <div class="flex flex-col min-w-0 grow">
              <span class="font-medium truncate text-n-slate-12">
                {{ item.title }}
              </span>
              <span class="text-xs truncate text-n-slate-11">
                {{ periodLabel(item) }} · {{ audienceLabel(item) }}
              </span>
            </div>

            <span
              class="px-2 py-0.5 text-xs font-medium rounded-md"
              :class="STATUS_CLASSES[item.status]"
              :data-testid="`announcement-status-${item.id}`"
            >
              {{
                t(`TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.STATUS.${item.status}`)
              }}
            </span>

            <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-11">
              <input
                type="checkbox"
                class="mb-0"
                :checked="item.active"
                :aria-label="
                  t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.FORM.ACTIVE')
                "
                @change="toggleActive(item)"
              />
              {{
                item.active
                  ? t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.ACTIVE')
                  : t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.INACTIVE')
              }}
            </label>

            <div class="flex items-center gap-1">
              <Button
                slate
                ghost
                size="sm"
                icon="i-lucide-arrow-up"
                :title="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.MOVE_UP')"
                :disabled="index === 0"
                @click="move(index, -1)"
              />
              <Button
                slate
                ghost
                size="sm"
                icon="i-lucide-arrow-down"
                :title="
                  t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.MOVE_DOWN')
                "
                :disabled="index === announcements.length - 1"
                @click="move(index, 1)"
              />
              <Button
                slate
                faded
                size="sm"
                icon="i-lucide-pencil"
                :label="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.EDIT')"
                @click="openEdit(item)"
              />
              <ConfirmButton
                :label="t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.DELETE')"
                :confirm-label="
                  t('TICKET.SETTINGS.CLIENT_ANNOUNCEMENTS.LIST.CONFIRM_DELETE')
                "
                color="slate"
                confirm-color="ruby"
                variant="outline"
                icon="i-lucide-trash-2"
                size="sm"
                @click="remove(item)"
              />
            </div>
          </li>
        </ul>
      </div>
    </template>
  </SettingsLayout>
</template>
