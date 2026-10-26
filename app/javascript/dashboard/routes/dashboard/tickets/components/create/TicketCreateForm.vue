<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTicketCreation } from '../../composables/useTicketCreation';
import { TICKET_DESCRIPTION_TEMPLATE } from '../../helpers/descriptionTemplate';
import TicketCompanySelect from '../TicketCompanySelect.vue';
import TicketContactSelect from '../TicketContactSelect.vue';
import TicketPicker from '../detail/actions/TicketPicker.vue';
import TicketFollowersSelect from './TicketFollowersSelect.vue';
import TicketFileInput from './TicketFileInput.vue';
import TicketRecentCompanyTickets from './TicketRecentCompanyTickets.vue';
import TicketKnowledgeAccordion from '../detail/TicketKnowledgeAccordion.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  // Everything the caller already knows. The Kanban sends the Mesa and the
  // Estagio of the column that was clicked; a chat sends Empresa, Solicitante
  // and the Conversation; a child ticket sends whatever the copy modal ticked.
  context: { type: Object, default: () => ({}) },
  isSubmitting: { type: Boolean, default: false },
  // "Criar e abrir outro" only makes sense when opening tickets in a row, which
  // is the Kanban case - not when a chat or a parent ticket started the flow.
  allowCreateAnother: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'cancel']);

import TicketSelect from '../TicketSelect.vue';

const { t } = useI18n();

const context = computed(() => props.context);
const {
  form,
  files,
  teams,
  columns,
  categories,
  complexities,
  mesaMembers,
  sprints,
  usesAssigneeLevels,
  assigneeLevels,
  membersForLevel,
  requiresAttachment,
  isDevMesa,
  isValid,
  toPayload,
  resetForNext,
} = useTicketCreation(context);

const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
const DEVELOPMENT_TYPES = ['bug', 'task'];
const RESOLUCOES = ['Definitiva', 'Paliativa'];

// As listas no formato do TicketSelect, o seletor padrao do modulo.
const toOptions = records =>
  records.map(record => ({ value: record.id, label: record.name }));

const teamOptions = computed(() => toOptions(teams.value));
const columnOptions = computed(() => toOptions(columns.value));
const categoryOptions = computed(() => toOptions(categories.value));
const complexityOptions = computed(() => toOptions(complexities.value));
const memberOptions = computed(() => toOptions(mesaMembers.value));
const sprintOptions = computed(() => toOptions(sprints.value));

// Um campo de responsavel por nivel quando a Mesa usa niveis; um so quando
// nao usa - a MESMA condicao que a tela de detalhe usa
// (`TicketPropertiesCard.vue`'s `usesAssigneeLevels`), e nao o tamanho de
// `assigneeLevels`: o servidor devolve `[1]` mesmo com a configuracao
// desligada (todo ticket "usa" o Nivel 1), entao esta lista nunca fica vazia
// e nunca seria o sinal certo para a troca de rotulo/campo.
//
// Sem niveis, cada campo oferece quem esta habilitado NAQUELE nivel - e por
// isso uma Mesa sem ninguem no Nivel 1 deixa de travar a abertura: basta
// indicar o Nivel 2.
const assigneeFields = computed(() => {
  if (!usesAssigneeLevels.value) {
    return [
      {
        level: 1,
        label: t('TICKET.CREATE.ASSIGNEE'),
        options: memberOptions.value,
      },
    ];
  }

  return assigneeLevels.value.map(level => ({
    level,
    label: t('TICKET.FORM.ASSIGNEE.LEVEL', { level }),
    options: toOptions(membersForLevel(level)),
  }));
});
const priorityOptions = computed(() =>
  PRIORITIES.map(value => ({
    value,
    label: t(`TICKET.FORM.PRIORITY.${value.toUpperCase()}`),
  }))
);

const showValidation = ref(false);

// FullEditor's image button dispatches `articles/attachImage` with a portal
// slug this route does not have, so those two options are left out; files go
// through the attachment field instead.
const EDITOR_MENU = [
  'bold',
  'italic',
  'link',
  'unorderedList',
  'orderedList',
  'heading',
  'code',
];

// A starting point for the structured description, not a template system: the
// button fills an empty editor and stays out of the way once there is text.
const applyTemplate = () => {
  form.value.description = TICKET_DESCRIPTION_TEMPLATE;
};

const submit = createAnother => {
  showValidation.value = true;
  if (!isValid.value) return;

  emit('submit', {
    ticket: toPayload(),
    files: [...files.value],
    createAnother,
    onCreated: createAnother ? resetForNext : null,
  });
};

const invalid = field => showValidation.value && !form.value[field];
const invalidText = field =>
  showValidation.value && !String(form.value[field] || '').trim();

defineExpose({ resetForNext });
</script>

<template>
  <form class="flex flex-col gap-4 min-w-0" @submit.prevent="submit(false)">
    <!-- Two columns on desktop, one on anything narrower. Every field is
         `min-w-0` so a long value truncates instead of widening the grid, which
         is what would otherwise scroll the page sideways. -->
    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.COMPANY.LABEL') }}<span class="text-n-ruby-11">*</span>
        </span>
        <TicketCompanySelect
          v-model="form.companyId"
          :initial-name="context.companyName || ''"
        />
        <span v-if="invalid('companyId')" class="text-xs text-n-ruby-11">
          {{ t('TICKET.CREATE.REQUIRED') }}
        </span>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.CREATE.TEAM') }}<span class="text-n-ruby-11">*</span>
        </span>
        <TicketSelect
          v-model="form.teamId"
          :options="teamOptions"
          :placeholder="t('TICKET.CREATE.SELECT')"
          :aria-label="t('TICKET.SETTINGS.MESA_LABEL')"
        />
        <span v-if="invalid('teamId')" class="text-xs text-n-ruby-11">
          {{ t('TICKET.CREATE.REQUIRED') }}
        </span>
      </label>

      <!-- The Solicitante comes from the Empresa's own contacts, so it stays
           disabled until there is one. -->
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.DETAIL.REQUESTER.CONTACT')
          }}<span class="text-n-ruby-11">*</span>
        </span>
        <TicketContactSelect
          v-model="form.contactId"
          :company-id="form.companyId"
          :initial-name="context.contactName || ''"
        />
        <span v-if="invalid('contactId')" class="text-xs text-n-ruby-11">
          {{ t('TICKET.CREATE.REQUIRED') }}
        </span>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.CREATE.STAGE') }}<span class="text-n-ruby-11">*</span>
        </span>
        <TicketSelect
          v-model="form.ticketColumnId"
          :options="columnOptions"
          :disabled="!columns.length"
          :placeholder="t('TICKET.CREATE.SELECT')"
          :aria-label="t('TICKET.DETAIL.PROPERTIES.STAGE')"
        />
        <span v-if="invalid('ticketColumnId')" class="text-xs text-n-ruby-11">
          {{ t('TICKET.CREATE.REQUIRED') }}
        </span>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.CREATE.PRIORITY') }}<span class="text-n-ruby-11">*</span>
        </span>
        <TicketSelect
          v-model="form.priority"
          :options="priorityOptions"
          :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
        />
      </label>

      <!-- Um campo por nivel de responsavel. Cada um lista so quem a Mesa
           habilitou naquele nivel: o servidor recusa qualquer outro, e
           oferecer todo mundo era o que fazia o agente de Nivel 2 cair no
           campo do Nivel 1. Nenhum e obrigatorio - da para abrir indicando
           apenas o Nivel 2, ou nenhum. -->
      <label
        v-for="campo in assigneeFields"
        :key="campo.level"
        class="flex flex-col gap-1 min-w-0"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ campo.label }}
        </span>
        <TicketSelect
          v-model="form.assignees[campo.level]"
          :options="campo.options"
          :disabled="!campo.options.length"
          clearable
          :clear-label="t('TICKET.CREATE.UNASSIGNED')"
          :placeholder="
            campo.options.length
              ? t('TICKET.CREATE.UNASSIGNED')
              : t('TICKET.CREATE.NO_AGENT_IN_LEVEL')
          "
          :aria-label="campo.label"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0 md:col-span-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.CREATE.CATEGORY') }}<span class="text-n-ruby-11">*</span>
        </span>
        <TicketSelect
          v-model="form.ticketCategoryId"
          :options="categoryOptions"
          :disabled="!categories.length"
          :placeholder="
            categories.length
              ? t('TICKET.CREATE.SELECT')
              : t('TICKET.CREATE.CATEGORY_NEEDS_TEAM')
          "
          :aria-label="t('TICKET.CREATE.CATEGORY')"
        />
        <span v-if="invalid('ticketCategoryId')" class="text-xs text-n-ruby-11">
          {{ t('TICKET.CREATE.REQUIRED') }}
        </span>
      </label>

      <!-- Complexidade. Sem asterisco: nao e exigida para ABRIR - a exigencia
           aparece no encerramento, e o modal de fechar diz isso. So os niveis que
           esta Mesa oferece aparecem aqui. -->
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.COMPLEXITY.LABEL') }}
        </span>
        <TicketSelect
          v-model="form.ticketComplexityId"
          :options="complexityOptions"
          :disabled="!complexities.length"
          :placeholder="
            complexities.length
              ? t('TICKET.COMPLEXITY.PLACEHOLDER')
              : t('TICKET.COMPLEXITY.EMPTY_FOR_MESA')
          "
          :aria-label="t('TICKET.COMPLEXITY.LABEL')"
        />
      </label>
    </div>

    <!-- So' aparece quando a Mesa escolhida tem o Modulo de Desenvolvimento
         ligado - em qualquer outra Mesa este bloco nao existe, nenhum campo
         novo chega ao servidor por conta propria. -->
    <div
      v-if="isDevMesa"
      class="flex flex-col gap-3 rounded-lg border border-n-weak p-3"
    >
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DEVELOPMENT_FIELDS.TITLE') }}
      </span>
      <div class="grid grid-cols-1 gap-4 md:grid-cols-2 min-w-0">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.TYPE.LABEL') }}
          </span>
          <select v-model="form.developmentType" class="mb-0">
            <option :value="null">
              {{ t('TICKET.DEVELOPMENT_FIELDS.TYPE.NONE') }}
            </option>
            <option v-for="type in DEVELOPMENT_TYPES" :key="type" :value="type">
              {{ t(`TICKET.DEVELOPMENT_FIELDS.TYPE.${type.toUpperCase()}`) }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.SPRINT.LABEL') }}
          </span>
          <select v-model="form.sprintId" class="mb-0">
            <option :value="null">
              {{ t('TICKET.DEVELOPMENT_FIELDS.SPRINT.BACKLOG') }}
            </option>
            <option
              v-for="sprint in sprintOptions"
              :key="sprint.value"
              :value="sprint.value"
            >
              {{ sprint.label }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.RESOLUCAO.LABEL') }}
          </span>
          <select v-model="form.devResolucao" class="mb-0">
            <option :value="null">
              {{ t('TICKET.DEVELOPMENT_FIELDS.RESOLUCAO.NONE') }}
            </option>
            <option v-for="opcao in RESOLUCOES" :key="opcao" :value="opcao">
              {{ opcao }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.FEATURE.LABEL') }}
          </span>
          <input
            v-model="form.devFeature"
            type="text"
            class="w-full mb-0"
            :placeholder="t('TICKET.DEVELOPMENT_FIELDS.FEATURE.PLACEHOLDER')"
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.DETALHES_OCULTOS.LABEL') }}
          </span>
          <input
            v-model="form.devDetalhesOcultos"
            type="text"
            class="w-full mb-0"
            :placeholder="
              t('TICKET.DEVELOPMENT_FIELDS.DETALHES_OCULTOS.PLACEHOLDER')
            "
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.ESTIMATIVA_HORAS') }}
          </span>
          <input
            v-model="form.devEstimativaHoras"
            type="number"
            min="0"
            step="0.5"
            class="w-full mb-0"
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.TEMPO_TESTE_HORAS') }}
          </span>
          <input
            v-model="form.devTempoTesteHoras"
            type="number"
            min="0"
            step="0.5"
            class="w-full mb-0"
          />
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DEVELOPMENT_FIELDS.DATA_LIMITE') }}
          </span>
          <input v-model="form.devDataLimite" type="date" class="w-full mb-0" />
        </label>
      </div>

      <div class="flex flex-wrap items-center gap-4">
        <div class="flex items-center gap-2">
          <input v-model="form.devRetrabalho" type="checkbox" :value="true" />
          <label>{{ t('TICKET.DEVELOPMENT_FIELDS.RETRABALHO') }}</label>
        </div>
        <div class="flex items-center gap-2">
          <input v-model="form.devFeitoTriagem" type="checkbox" :value="true" />
          <label>{{ t('TICKET.DEVELOPMENT_FIELDS.FEITO_TRIAGEM') }}</label>
        </div>
      </div>
    </div>

    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.FORM.TITLE.LABEL') }}<span class="text-n-ruby-11">*</span>
      </span>
      <!-- Just the title. The number and the Empresa/Solicitante are shown
           around it on the ticket page; repeating them here would store the
           same data twice. -->
      <input
        v-model="form.title"
        type="text"
        class="w-full mb-0"
        :placeholder="t('TICKET.FORM.TITLE.PLACEHOLDER')"
      />
      <span v-if="invalidText('title')" class="text-xs text-n-ruby-11">
        {{ t('TICKET.CREATE.REQUIRED') }}
      </span>
    </label>

    <!-- Description takes the space; the two reference panels sit beside it on
         desktop and stack underneath on narrower screens. -->
    <div
      class="grid grid-cols-1 gap-4 lg:grid-cols-[minmax(0,3fr)_minmax(0,1fr)] min-w-0"
    >
      <div class="flex flex-col gap-2 min-w-0">
        <div class="flex items-center justify-between gap-2 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('TICKET.DETAIL.DESCRIPTION.TITLE')
            }}<span class="text-n-ruby-11">*</span>
          </span>
          <Button
            v-if="!form.description"
            variant="link"
            color="slate"
            size="xs"
            type="button"
            :label="t('TICKET.DETAIL.DESCRIPTION.USE_TEMPLATE')"
            @click="applyTemplate"
          />
        </div>
        <FullEditor
          v-model="form.description"
          class="min-w-0 [&_.ProseMirror]:min-h-[14rem]"
          :enabled-menu-options="EDITOR_MENU"
          :placeholder="t('TICKET.FORM.DESCRIPTION.PLACEHOLDER')"
        />
        <span v-if="invalidText('description')" class="text-xs text-n-ruby-11">
          {{ t('TICKET.CREATE.REQUIRED') }}
        </span>

        <TicketFileInput v-model="files" />
        <!-- A Categoria escolhida exige anexo: dito aqui, e nao so no botao
             desabilitado, para a pessoa saber o que falta. -->
        <span v-if="requiresAttachment" class="text-xs text-n-amber-11">
          {{ t('TICKET.CREATE.ATTACHMENT_REQUIRED') }}
        </span>
      </div>

      <aside class="flex flex-col gap-4 min-w-0">
        <TicketRecentCompanyTickets :company-id="form.companyId" />
        <TicketKnowledgeAccordion :ticket="{ title: form.title }" />
      </aside>
    </div>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.DETAIL.FOLLOWERS.TITLE') }}
        </span>
        <TicketFollowersSelect
          v-model="form.followerIds"
          :members="mesaMembers"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.PARENT_DIALOG.LABEL') }}
        </span>
        <!-- Already filled and left alone when the flow started from "Criar
             ticket filho". -->
        <TicketPicker
          v-model="form.parentId"
          :disabled="!!context.parentId"
          :placeholder="t('TICKET.ACTIONS.PICKER.PLACEHOLDER')"
        />
      </label>
    </div>

    <div
      class="sticky bottom-0 z-10 flex flex-wrap items-center justify-end gap-2 py-3 -mb-1 border-t bg-n-alpha-3 backdrop-blur-[4px] border-n-weak"
    >
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('TICKET.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <Button
        v-if="allowCreateAnother"
        variant="faded"
        color="slate"
        type="button"
        :is-loading="isSubmitting"
        :label="t('TICKET.CREATE.SUBMIT_AND_NEW')"
        @click="submit(true)"
      />
      <Button
        type="submit"
        :is-loading="isSubmitting"
        :label="t('TICKET.CREATE.SUBMIT')"
      />
    </div>
  </form>
</template>
