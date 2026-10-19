<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TeamsAPI from 'dashboard/api/teams';
import TicketsAPI from 'dashboard/api/tickets';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const emit = defineEmits(['created', 'linked']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const mode = ref('create');
const isBooting = ref(false);
const isSubmitting = ref(false);
const devTeam = ref(null);
const noDevTeam = ref(false);

// Use a local ref instead of a store getter computed to avoid Vuex 4 + Vue 3
// reactivity tracking issues with factory-function getters.
const allCategories = ref([]);

// Only show "Erro" and "Tarefa" type categories for development tickets.
const categories = computed(() =>
  allCategories.value.filter(c =>
    ['erro', 'tarefa'].includes(c.name.toLowerCase().trim())
  )
);

const noCategoryMatch = computed(
  () => allCategories.value.length > 0 && categories.value.length === 0
);
const columns = computed(() =>
  devTeam.value
    ? store.getters['ticketColumns/getColumns'](devTeam.value.id) || []
    : []
);
const members = computed(() =>
  devTeam.value
    ? store.getters['teamMembers/getTeamMembers'](devTeam.value.id) || []
    : []
);

const PRIORITIES = [
  { value: 'low', label: t('TICKET.FORM.PRIORITY.LOW') },
  { value: 'medium', label: t('TICKET.FORM.PRIORITY.MEDIUM') },
  { value: 'high', label: t('TICKET.FORM.PRIORITY.HIGH') },
  { value: 'urgent', label: t('TICKET.FORM.PRIORITY.URGENT') },
];

// Create form
const form = ref({
  title: '',
  description: '',
  ticketCategoryId: null,
  assigneeId: null,
  priority: 'medium',
});
const errors = ref({});
const files = ref([]);
const fileInput = ref(null);

const addFiles = event => {
  const chosen = Array.from(event.target.files || []);
  if (chosen.length) files.value = [...files.value, ...chosen];
  event.target.value = '';
};

const removeFile = index => {
  files.value = files.value.filter((_, i) => i !== index);
};

const formatSize = bytes => `${Math.max(1, Math.round(bytes / 1024))} KB`;

const htmlToPlainText = html => {
  if (!html) return '';
  const el = document.createElement('div');
  el.innerHTML = html;
  return (el.textContent || el.innerText || '').trim();
};

// Link search
const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
let searchTimer = null;

const loadDevTeam = async () => {
  if (devTeam.value || noDevTeam.value) return;
  isBooting.value = true;
  try {
    const { data } = await TeamsAPI.get();
    const found = (data || []).find(team =>
      team.name.toLowerCase().includes('desenvolv')
    );
    if (!found) {
      noDevTeam.value = true;
      return;
    }
    devTeam.value = found;
    const [, cats] = await Promise.all([
      store.dispatch('ticketColumns/fetchColumns', found.id),
      store.dispatch('ticketColumns/fetchCategories', found.id),
      store.dispatch('teamMembers/get', { teamId: found.id }),
    ]);
    allCategories.value = Array.isArray(cats) ? cats : [];
  } catch {
    noDevTeam.value = true;
  } finally {
    isBooting.value = false;
  }
};

const resetForm = () => {
  form.value = {
    title: '',
    description: htmlToPlainText(props.ticket?.description),
    ticketCategoryId: null,
    assigneeId: null,
    priority: 'medium',
  };
  errors.value = {};
  files.value = [];
};

const resetLink = () => {
  searchQuery.value = '';
  searchResults.value = [];
};

const open = async (initialMode = 'create') => {
  mode.value = initialMode;
  resetForm();
  resetLink();
  // Re-fetch categories before opening so new ones (e.g. "Tarefa") are
  // visible immediately — dialog only opens after fresh data arrives.
  if (devTeam.value) {
    const cats = await store.dispatch(
      'ticketColumns/fetchCategories',
      devTeam.value.id
    );
    allCategories.value = Array.isArray(cats) ? cats : [];
  }
  dialogRef.value?.open();
  if (initialMode === 'link') searchTickets();
};

const validate = () => {
  const e = {};
  if (!form.value.title.trim())
    e.title = t('TICKET.DETAIL.DEVELOPMENT.CREATE.TITLE_REQUIRED');
  if (!form.value.description.trim())
    e.description = t('TICKET.DETAIL.DEVELOPMENT.CREATE.DESCRIPTION_REQUIRED');
  if (!form.value.ticketCategoryId)
    e.category = t('TICKET.DETAIL.DEVELOPMENT.CREATE.CATEGORY_REQUIRED');
  errors.value = e;
  return !Object.keys(e).length;
};

const handleConfirm = () => {
  if (mode.value === 'create') submitCreate();
};

const submitCreate = async () => {
  if (!validate() || !devTeam.value) return;
  const col = columns.value[0];
  if (!col) {
    useAlert(t('TICKET.DETAIL.DEVELOPMENT.NO_COLUMN'));
    return;
  }
  isSubmitting.value = true;
  try {
    const { data: created } = await TicketsAPI.createTicket({
      ticket: {
        title: form.value.title.trim(),
        description: form.value.description,
        ticket_category_id: form.value.ticketCategoryId,
        assignee_id: form.value.assigneeId || null,
        priority: form.value.priority,
        team_id: devTeam.value.id,
        ticket_column_id: col.id,
        company_id: props.ticket.company_id,
        contact_id: props.ticket.contact_id || props.ticket.contact?.id || null,
        parent_id: props.ticket.id,
      },
    });
    // Upload attachments sequentially after the ticket exists.
    for (const file of files.value) {
      // eslint-disable-next-line no-await-in-loop
      await TicketsAPI.createAttachment(created.id, file);
    }
    dialogRef.value?.close();
    emit('created');
  } catch {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};

const searchTickets = async () => {
  if (!devTeam.value) return;
  isSearching.value = true;
  try {
    const { data } = await TicketsAPI.search(searchQuery.value.trim(), {
      team_id: devTeam.value.id,
    });
    const existingChildIds = new Set(
      (props.ticket.children || []).map(c => c.id)
    );
    searchResults.value = (data?.payload || []).filter(
      ticket => ticket.id !== props.ticket.id && !existingChildIds.has(ticket.id)
    );
  } catch {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
};

const linkTicket = async target => {
  isSubmitting.value = true;
  try {
    await TicketsAPI.setParent(target.id, props.ticket.id);
    dialogRef.value?.close();
    emit('linked');
  } catch {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};

watch(searchQuery, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    if (mode.value === 'link') searchTickets();
  }, 400);
});

// When switching to link mode, do initial search
watch(mode, newMode => {
  if (newMode === 'link') {
    resetLink();
    searchTickets();
  } else {
    resetForm();
  }
});

// If the dev team finishes loading while the dialog is open on "vincular" tab
// and no search has run yet, trigger it now.
watch(devTeam, team => {
  if (team && mode.value === 'link' && !searchResults.value.length && !isSearching.value) {
    searchTickets();
  }
});

onMounted(loadDevTeam);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    overflow-y-auto
    :title="t('TICKET.DETAIL.DEVELOPMENT.DIALOG_TITLE')"
    :confirm-button-label="
      mode === 'create'
        ? t('TICKET.DETAIL.DEVELOPMENT.CREATE.CONFIRM')
        : ''
    "
    :show-confirm-button="mode === 'create'"
    :disable-confirm-button="isBooting || noDevTeam || isSubmitting"
    :is-loading="isSubmitting"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <!-- Tab switcher -->
      <div class="flex gap-2 border-b border-n-weak">
        <button
          type="button"
          class="px-1 pb-2 text-sm border-b-2 transition-colors"
          :class="
            mode === 'create'
              ? 'border-n-brand text-n-slate-12 font-medium'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          @click="mode = 'create'"
        >
          {{ t('TICKET.DETAIL.DEVELOPMENT.TAB_CREATE') }}
        </button>
        <button
          type="button"
          class="px-1 pb-2 text-sm border-b-2 transition-colors"
          :class="
            mode === 'link'
              ? 'border-n-brand text-n-slate-12 font-medium'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          @click="mode = 'link'"
        >
          {{ t('TICKET.DETAIL.DEVELOPMENT.TAB_LINK') }}
        </button>
      </div>

      <!-- Loading state -->
      <div v-if="isBooting" class="flex justify-center py-6">
        <Spinner />
      </div>

      <!-- No development team found -->
      <p
        v-else-if="noDevTeam"
        class="flex items-start gap-2 text-sm text-n-slate-11 py-2"
      >
        <Icon icon="i-lucide-alert-triangle" class="size-4 flex-shrink-0 mt-0.5 text-yellow-500" />
        {{ t('TICKET.DETAIL.DEVELOPMENT.NO_TEAM') }}
      </p>

      <!-- CREATE tab -->
      <template v-else-if="mode === 'create'">
        <!-- Title -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.TITLE_LABEL') }}
            <span class="text-red-500">*</span>
          </label>
          <input
            v-model="form.title"
            type="text"
            class="w-full rounded-xl border px-3 py-2 text-sm bg-transparent outline-none transition-colors"
            :class="
              errors.title
                ? 'border-red-400 focus:border-red-500'
                : 'border-n-strong focus:border-n-brand'
            "
            :placeholder="t('TICKET.DETAIL.DEVELOPMENT.CREATE.TITLE_PLACEHOLDER')"
            @input="delete errors.title"
          />
          <span v-if="errors.title" class="text-xs text-red-500">
            {{ errors.title }}
          </span>
        </div>

        <!-- Description -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.DESCRIPTION_LABEL') }}
            <span class="text-red-500">*</span>
          </label>
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full rounded-xl border px-3 py-2 text-sm bg-transparent outline-none resize-none transition-colors"
            :class="
              errors.description
                ? 'border-red-400 focus:border-red-500'
                : 'border-n-strong focus:border-n-brand'
            "
            :placeholder="t('TICKET.DETAIL.DEVELOPMENT.CREATE.DESCRIPTION_PLACEHOLDER')"
            @input="delete errors.description"
          />
          <span v-if="errors.description" class="text-xs text-red-500">
            {{ errors.description }}
          </span>
        </div>

        <!-- Attachments -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.FILES_LABEL') }}
          </label>
          <input
            ref="fileInput"
            type="file"
            multiple
            class="hidden"
            @change="addFiles"
          />
          <Button
            slate
            faded
            xs
            type="button"
            icon="i-lucide-paperclip"
            :label="t('TICKET.CREATE.FILES.ADD')"
            class="w-fit"
            @click="fileInput?.click()"
          />
          <ul v-if="files.length" class="flex flex-col gap-1 mt-1">
            <li
              v-for="(file, index) in files"
              :key="`${file.name}-${index}`"
              class="flex items-center gap-2 text-xs text-n-slate-11 min-w-0"
            >
              <Icon icon="i-lucide-file" class="flex-shrink-0 size-3.5" />
              <span class="truncate min-w-0" :title="file.name">{{ file.name }}</span>
              <span class="flex-shrink-0 text-n-slate-10">{{ formatSize(file.size) }}</span>
              <button
                type="button"
                class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
                @click="removeFile(index)"
              >
                <Icon icon="i-lucide-x" class="size-3.5" />
              </button>
            </li>
          </ul>
        </div>

        <!-- Category — Erro / Tarefa toggle -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.CATEGORY_LABEL') }}
            <span class="text-red-500">*</span>
          </label>
          <div class="flex gap-2">
            <button
              v-for="cat in categories"
              :key="cat.id"
              type="button"
              class="flex-1 py-2 px-3 text-sm rounded-xl border transition-colors font-medium"
              :class="
                form.ticketCategoryId === cat.id
                  ? 'border-n-brand bg-n-brand/10 text-n-brand'
                  : 'border-n-strong text-n-slate-11 hover:border-n-brand/60 hover:text-n-slate-12'
              "
              @click="form.ticketCategoryId = cat.id; delete errors.category"
            >
              {{ cat.name }}
            </button>
          </div>
          <span v-if="errors.category" class="text-xs text-red-500">
            {{ errors.category }}
          </span>
          <p v-if="noCategoryMatch" class="text-xs text-n-slate-10">
            {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.CATEGORY_NO_MATCH') }}
          </p>
          <p v-else-if="!categories.length && !allCategories.length" class="text-xs text-n-slate-10">
            {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.CATEGORY_NO_MATCH') }}
          </p>
        </div>

        <!-- Assignee + Priority side by side -->
        <div class="flex gap-3">
          <!-- Assignee -->
          <div class="flex flex-col gap-1 flex-1 min-w-0">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.ASSIGNEE_LABEL') }}
            </label>
            <select
              v-model="form.assigneeId"
              class="w-full rounded-xl border border-n-strong px-3 py-2 text-sm bg-transparent outline-none focus:border-n-brand transition-colors"
            >
              <option :value="null">
                {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.ASSIGNEE_PLACEHOLDER') }}
              </option>
              <option
                v-for="member in members"
                :key="member.id"
                :value="member.id"
              >
                {{ member.name }}
              </option>
            </select>
          </div>

          <!-- Priority -->
          <div class="flex flex-col gap-1 flex-1 min-w-0">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.DETAIL.DEVELOPMENT.CREATE.PRIORITY_LABEL') }}
              <span class="text-red-500">*</span>
            </label>
            <select
              v-model="form.priority"
              class="w-full rounded-xl border border-n-strong px-3 py-2 text-sm bg-transparent outline-none focus:border-n-brand transition-colors"
            >
              <option
                v-for="p in PRIORITIES"
                :key="p.value"
                :value="p.value"
              >
                {{ p.label }}
              </option>
            </select>
          </div>
        </div>
      </template>

      <!-- LINK tab -->
      <template v-else>
        <input
          v-model="searchQuery"
          type="text"
          class="w-full rounded-xl border border-n-strong px-3 py-2 text-sm bg-transparent outline-none focus:border-n-brand transition-colors"
          :placeholder="t('TICKET.DETAIL.DEVELOPMENT.LINK.SEARCH_PLACEHOLDER')"
        />

        <div v-if="isSearching" class="flex justify-center py-4">
          <Spinner />
        </div>

        <p
          v-else-if="!searchResults.length"
          class="text-sm text-n-slate-10 text-center py-4"
        >
          {{ t('TICKET.DETAIL.DEVELOPMENT.LINK.NO_RESULTS') }}
        </p>

        <div v-else class="max-h-64 overflow-y-auto flex flex-col gap-1">
          <div
            v-for="result in searchResults"
            :key="result.id"
            class="flex items-center justify-between gap-2 px-2 py-2 rounded-lg hover:bg-n-slate-3"
          >
            <span class="text-sm text-n-slate-12 truncate min-w-0">
              <span class="text-n-slate-10 text-xs">#{{ result.display_id }}</span>
              {{ result.title }}
            </span>
            <Button
              slate
              faded
              xs
              :label="t('TICKET.DETAIL.DEVELOPMENT.LINK.LINK_ACTION')"
              :is-loading="isSubmitting"
              @click="linkTicket(result)"
            />
          </div>
        </div>
      </template>
    </div>
  </Dialog>
</template>
