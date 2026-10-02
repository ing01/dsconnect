<script setup>
/**
 * O detalhe de uma manifestação, do lado da equipe.
 *
 * Aqui estão as quatro ações do dia: mover o status, assumir o caso, responder
 * ao cliente e anotar para a equipe. A conversão em ticket mora no diálogo
 * próprio, porque ela cria outro registro - não é uma alteração desta tela.
 *
 * Resposta e anotação usam o MESMO campo, com um interruptor entre as duas, e
 * a aparência muda junto (a anotação fica em âmbar, com o aviso de que o
 * cliente não a vê). Dois campos lado a lado seriam dois lugares para errar
 * qual é qual - e errar aqui é vazar uma anotação.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  statusColor,
  kindColor,
  statusOptions,
} from '../helpers/manifestationLabels';
import ManifestationConvertDialog from '../components/ManifestationConvertDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();

const manifestacao = computed(() => getters['manifestations/getManifestation'].value);
const uiFlags = computed(() => getters['manifestations/getUIFlags'].value);
const agents = computed(() => getters['agents/getVerifiedAgents'].value || []);
const currentRole = computed(() => getters.getCurrentRole?.value);

const convertDialogRef = ref(null);
const texto = ref('');
const ehAnotacao = ref(false);
const aguardarCliente = ref(false);

const statuses = computed(() => statusOptions(t));
const mensagens = computed(() => manifestacao.value?.messages || []);
const atividades = computed(() => manifestacao.value?.activities || []);
const anexos = computed(() => manifestacao.value?.attachments || []);

// Converter cria um chamado de verdade no Kanban: só administrador, a mesma
// regra do `ManifestationPolicy#convert?`. A tela esconde o botão; o servidor é
// que recusa.
const podeConverter = computed(() => currentRole.value === 'administrator');

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const carregar = async () => {
  try {
    await store.dispatch('manifestations/show', route.params.manifestationId);
  } catch {
    useAlert(t('MANIFESTATION.DETAIL.NOT_FOUND'));
  }
};

const mudarStatus = async novo => {
  if (!novo || novo === manifestacao.value.status) return;
  try {
    await store.dispatch('manifestations/update', {
      id: manifestacao.value.id,
      status: novo,
    });
    useAlert(t('MANIFESTATION.STATUS_CHANGE.DONE'));
  } catch {
    useAlert(t('MANIFESTATION.API.ERROR'));
  }
};

const mudarResponsavel = async novo => {
  try {
    await store.dispatch('manifestations/update', {
      id: manifestacao.value.id,
      assignee_id: novo || null,
    });
    useAlert(t('MANIFESTATION.ASSIGN.DONE'));
  } catch {
    useAlert(t('MANIFESTATION.API.ERROR'));
  }
};

const enviar = async () => {
  if (!texto.value.trim() || uiFlags.value.isUpdating) return;

  const eraAnotacao = ehAnotacao.value;
  try {
    await store.dispatch('manifestations/reply', {
      id: manifestacao.value.id,
      body: texto.value.trim(),
      internal: eraAnotacao,
      awaitingCustomer: !eraAnotacao && aguardarCliente.value,
    });
    texto.value = '';
    aguardarCliente.value = false;
    useAlert(
      eraAnotacao
        ? t('MANIFESTATION.REPLY.NOTE_SAVED')
        : t('MANIFESTATION.REPLY.SENT')
    );
  } catch (error) {
    useAlert(error?.response?.data?.error || t('MANIFESTATION.API.ERROR'));
  }
};

const abrirTicket = () =>
  router.push(
    frontendURL(
      `accounts/${route.params.accountId}/tickets/${manifestacao.value.converted_ticket_id}`
    )
  );

const descricaoAtividade = atividade => {
  const acao = t(`MANIFESTATION.ACTIVITY.${atividade.activity_type}`);
  if (atividade.activity_type !== 'status_changed') return acao;

  const para = t(`MANIFESTATION.STATUSES.${atividade.new_value}`);
  if (!atividade.previous_value) {
    return `${acao} ${t('MANIFESTATION.ACTIVITY.TO', { to: para })}`;
  }
  const de = t(`MANIFESTATION.STATUSES.${atividade.previous_value}`);
  return `${acao} ${t('MANIFESTATION.ACTIVITY.FROM_TO', { from: de, to: para })}`;
};

onMounted(async () => {
  await store.dispatch('agents/get');
  await carregar();
});
</script>

<template>
  <div class="flex flex-col h-full gap-4 p-4 overflow-y-auto min-w-0 sm:p-6">
    <Button
      variant="link"
      color="slate"
      size="sm"
      icon="i-lucide-arrow-left"
      :label="t('MANIFESTATION.DETAIL.BACK')"
      class="self-start flex-shrink-0"
      @click="router.push({ name: 'manifestations_index' })"
    />

    <div
      v-if="uiFlags.isFetchingItem && !manifestacao"
      class="flex justify-center py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <p v-else-if="!manifestacao" class="text-sm text-n-slate-11">
      {{ t('MANIFESTATION.DETAIL.NOT_FOUND') }}
    </p>

    <template v-else>
      <div class="flex flex-wrap items-start justify-between gap-3 min-w-0">
        <div class="min-w-0">
          <span class="flex flex-wrap items-center gap-2 min-w-0">
            <span class="text-xs font-medium text-n-slate-11">
              {{ manifestacao.reference }}
            </span>
            <Label
              :label="t(`MANIFESTATION.KINDS.${manifestacao.kind}`)"
              :color="kindColor(manifestacao.kind)"
              compact
            />
            <Label
              :label="t(`MANIFESTATION.STATUSES.${manifestacao.status}`)"
              :color="statusColor(manifestacao.status)"
              compact
            />
          </span>
          <h1 class="m-0 text-xl font-medium text-n-slate-12">
            {{ manifestacao.title }}
          </h1>
          <p class="m-0 text-sm text-n-slate-11">
            {{ t(`MANIFESTATION.SUBJECT_AREAS.${manifestacao.subject_area}`) }}
            &middot; {{ manifestacao.company_name || '—' }} &middot;
            {{ manifestacao.contact_name || '—' }} &middot;
            {{ dataHora(manifestacao.created_at) }}
          </p>
        </div>

        <div class="flex flex-wrap items-center flex-shrink-0 gap-2">
          <!-- Já convertida: o botão dá lugar ao caminho para o ticket. É isso
               que evita a segunda conversão pela tela; o servidor recusa de
               todo jeito. -->
          <Button
            v-if="manifestacao.converted"
            variant="faded"
            color="teal"
            size="sm"
            icon="i-lucide-ticket"
            :label="
              t('MANIFESTATION.CONVERT.OPEN_TICKET', {
                number: manifestacao.converted_ticket_display_id,
              })
            "
            @click="abrirTicket"
          />
          <Button
            v-else-if="podeConverter"
            variant="faded"
            color="slate"
            size="sm"
            icon="i-lucide-ticket"
            :label="t('MANIFESTATION.CONVERT.ACTION')"
            @click="convertDialogRef?.open()"
          />
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('MANIFESTATION.STATUS_CHANGE.LABEL') }}
          </span>
          <select
            :value="manifestacao.status"
            class="w-full mb-0"
            @change="mudarStatus($event.target.value)"
          >
            <option v-for="o in statuses" :key="o.value" :value="o.value">
              {{ o.label }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('MANIFESTATION.ASSIGN.LABEL') }}
          </span>
          <select
            :value="manifestacao.assignee_id || ''"
            class="w-full mb-0"
            @change="mudarResponsavel($event.target.value)"
          >
            <option value="">
              {{ t('MANIFESTATION.DETAIL.UNASSIGNED') }}
            </option>
            <option v-for="agente in agents" :key="agente.id" :value="agente.id">
              {{ agente.name }}
            </option>
          </select>
        </label>
      </div>

      <div
        class="p-4 text-sm whitespace-pre-line border rounded-xl border-n-weak text-n-slate-12 min-w-0"
      >
        {{ manifestacao.description }}
      </div>

      <div v-if="anexos.length" class="flex flex-col gap-2 min-w-0">
        <h2 class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.DETAIL.ATTACHMENTS') }}
        </h2>
        <ul class="flex flex-col gap-1 p-0 m-0 list-none">
          <li v-for="anexo in anexos" :key="anexo.id" class="min-w-0">
            <a
              :href="anexo.url"
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-2 text-sm text-n-blue-11 min-w-0"
            >
              <Icon icon="i-lucide-paperclip" class="flex-shrink-0 size-4" />
              <span class="truncate">{{ anexo.name }}</span>
            </a>
          </li>
        </ul>
      </div>

      <div class="flex flex-col gap-2 min-w-0">
        <h2 class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.DETAIL.MESSAGES') }}
        </h2>
        <p v-if="!mensagens.length" class="m-0 text-sm text-n-slate-11">
          {{ t('MANIFESTATION.DETAIL.NO_MESSAGES') }}
        </p>
        <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
          <li
            v-for="mensagem in mensagens"
            :key="mensagem.id"
            class="flex flex-col gap-1 p-3 rounded-xl min-w-0"
            :class="
              mensagem.visibility === 'internal_note'
                ? 'bg-n-amber-2 border border-n-amber-5'
                : 'bg-n-slate-2'
            "
          >
            <span
              class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11"
            >
              <!-- A distinção pedida: anotação interna é dita por escrito, e
                   não só por uma cor de fundo. -->
              <Label
                :label="
                  mensagem.visibility === 'internal_note'
                    ? t('MANIFESTATION.DETAIL.INTERNAL_NOTE')
                    : t('MANIFESTATION.DETAIL.PUBLIC_REPLY')
                "
                :color="
                  mensagem.visibility === 'internal_note' ? 'amber' : 'teal'
                "
                compact
              />
              <span>
                {{
                  mensagem.author_name ||
                  (mensagem.from_client
                    ? t('MANIFESTATION.DETAIL.BY_CLIENT')
                    : t('MANIFESTATION.DETAIL.BY_TEAM'))
                }}
                &middot; {{ dataHora(mensagem.created_at) }}
              </span>
            </span>
            <span class="text-sm whitespace-pre-line text-n-slate-12">
              {{ mensagem.body }}
            </span>
          </li>
        </ul>
      </div>

      <div
        class="flex flex-col gap-2 p-3 border rounded-xl min-w-0"
        :class="ehAnotacao ? 'border-n-amber-5 bg-n-amber-2' : 'border-n-weak'"
      >
        <div class="flex flex-wrap items-center gap-4">
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input v-model="ehAnotacao" type="checkbox" class="mb-0" />
            {{ t('MANIFESTATION.DETAIL.INTERNAL_NOTE') }}
          </label>
          <label
            v-if="!ehAnotacao"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <input v-model="aguardarCliente" type="checkbox" class="mb-0" />
            {{ t('MANIFESTATION.REPLY.AWAITING_CUSTOMER') }}
          </label>
        </div>

        <p v-if="ehAnotacao" class="m-0 text-xs text-n-amber-11">
          {{ t('MANIFESTATION.DETAIL.INTERNAL_NOTE_HINT') }}
        </p>

        <textarea
          v-model="texto"
          rows="3"
          class="w-full mb-0"
          :placeholder="
            ehAnotacao
              ? t('MANIFESTATION.REPLY.NOTE_PLACEHOLDER')
              : t('MANIFESTATION.REPLY.PLACEHOLDER')
          "
        />
        <Button
          size="sm"
          :color="ehAnotacao ? 'amber' : 'blue'"
          :label="
            ehAnotacao
              ? t('MANIFESTATION.REPLY.SAVE_NOTE')
              : t('MANIFESTATION.REPLY.SEND')
          "
          :is-loading="uiFlags.isUpdating"
          :disabled="!texto.trim()"
          class="self-start"
          @click="enviar"
        />
      </div>

      <div class="flex flex-col gap-2 min-w-0">
        <h2 class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.DETAIL.HISTORY') }}
        </h2>
        <p v-if="!atividades.length" class="m-0 text-sm text-n-slate-11">
          {{ t('MANIFESTATION.DETAIL.NO_HISTORY') }}
        </p>
        <ul v-else class="flex flex-col gap-1 p-0 m-0 list-none">
          <li
            v-for="atividade in atividades"
            :key="atividade.id"
            class="flex flex-wrap items-center gap-x-2 text-xs text-n-slate-11 min-w-0"
          >
            <Icon icon="i-lucide-dot" class="flex-shrink-0 size-4" />
            <span class="font-medium text-n-slate-12">
              {{
                atividade.author_name ||
                (atividade.from_client
                  ? t('MANIFESTATION.DETAIL.BY_CLIENT')
                  : t('MANIFESTATION.DETAIL.BY_TEAM'))
              }}
            </span>
            <span>{{ descricaoAtividade(atividade) }}</span>
            <span>&middot; {{ dataHora(atividade.created_at) }}</span>
          </li>
        </ul>
      </div>

      <ManifestationConvertDialog
        ref="convertDialogRef"
        :manifestation="manifestacao"
      />
    </template>
  </div>
</template>
