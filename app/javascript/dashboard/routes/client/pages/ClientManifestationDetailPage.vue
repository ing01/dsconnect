<script setup>
/**
 * O acompanhamento de uma manifestação, no Portal do Cliente.
 *
 * Mostra o status atual, a conversa com a equipe e o histórico de movimentações.
 *
 * As mensagens chegam JÁ filtradas pelo servidor (`visible_to_client`): não há
 * nenhuma decisão de visibilidade nesta tela, e é de propósito - uma regra de
 * sigilo escrita no navegador seria uma segunda versão dela, que poderia
 * discordar da primeira.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  statusColor,
  kindColor,
  isFinished,
} from 'dashboard/routes/dashboard/manifestations/helpers/manifestationLabels';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const isLoading = ref(true);
const manifestacao = ref(null);
const resposta = ref('');
const arquivos = ref([]);
const arquivoRef = ref(null);
const isSending = ref(false);

const mensagens = computed(() => manifestacao.value?.messages || []);
const atividades = computed(() => manifestacao.value?.activities || []);
const anexos = computed(() => manifestacao.value?.attachments || []);

// Encerrada é registro histórico: não recebe mais mensagem. O servidor recusa
// de todo jeito; esconder o campo evita escrever para depois ser barrado.
const encerrada = computed(() => isFinished(manifestacao.value?.status));

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const carregar = async () => {
  try {
    const { data } = await ClientAreaAPI.manifestation(
      route.params.manifestationId
    );
    manifestacao.value = data;
  } catch {
    useAlert(t('MANIFESTATION.DETAIL.NOT_FOUND'));
  } finally {
    isLoading.value = false;
  }
};

const onArquivos = evento => {
  arquivos.value = Array.from(evento.target.files || []);
};

const enviar = async () => {
  if (!resposta.value.trim() || isSending.value) return;

  isSending.value = true;
  try {
    await ClientAreaAPI.replyToManifestation(
      manifestacao.value.id,
      resposta.value.trim(),
      arquivos.value
    );
    resposta.value = '';
    arquivos.value = [];
    if (arquivoRef.value) arquivoRef.value.value = null;
    // Relê em vez de acrescentar à mão: a resposta pode ter mudado o status
    // (de "aguardando retorno" para "em andamento"), e o histórico ganhou
    // linhas que só o servidor sabe montar.
    await carregar();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('MANIFESTATION.API.ERROR'));
  } finally {
    isSending.value = false;
  }
};

// O texto de uma linha do histórico, montado a partir do que o servidor gravou.
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

onMounted(carregar);
</script>

<template>
  <div class="flex flex-col flex-1 h-full min-h-0 gap-4 p-4 min-w-0 sm:p-6">
    <NextButton
      variant="link"
      color="slate"
      size="sm"
      icon="i-lucide-arrow-left"
      :label="t('MANIFESTATION.DETAIL.BACK')"
      class="self-start flex-shrink-0"
      @click="router.push({ name: 'client_manifestations' })"
    />

    <div v-if="isLoading" class="flex justify-center py-16 text-n-slate-10">
      <Spinner />
    </div>

    <p v-else-if="!manifestacao" class="text-sm text-n-slate-11">
      {{ t('MANIFESTATION.DETAIL.NOT_FOUND') }}
    </p>

    <div
      v-else
      class="flex flex-col gap-4 overflow-y-auto grow min-h-0 min-w-0"
    >
      <div class="flex flex-col gap-2 min-w-0">
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
          &middot;
          {{ dataHora(manifestacao.created_at) }}
        </p>

        <!-- Virou chamado: o cliente precisa saber onde o assunto está sendo
             tratado agora. -->
        <p
          v-if="manifestacao.converted"
          class="flex items-center gap-2 m-0 text-sm text-n-teal-11"
        >
          <Icon icon="i-lucide-ticket" class="flex-shrink-0 size-4" />
          {{
            t('MANIFESTATION.CONVERT.ALREADY', {
              number: manifestacao.converted_ticket_display_id,
            })
          }}
        </p>
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
              mensagem.from_client
                ? 'bg-n-alpha-2 ltr:ml-6 rtl:mr-6'
                : 'bg-n-slate-2 ltr:mr-6 rtl:ml-6'
            "
          >
            <span class="text-xs text-n-slate-11">
              {{
                mensagem.author_name ||
                (mensagem.from_client
                  ? t('MANIFESTATION.DETAIL.BY_CLIENT')
                  : t('MANIFESTATION.DETAIL.BY_TEAM'))
              }}
              &middot;
              {{ dataHora(mensagem.created_at) }}
            </span>
            <span class="text-sm whitespace-pre-line text-n-slate-12">
              {{ mensagem.body }}
            </span>
          </li>
        </ul>
      </div>

      <div v-if="!encerrada" class="flex flex-col gap-2 min-w-0">
        <textarea
          v-model="resposta"
          rows="3"
          class="w-full mb-0"
          :placeholder="t('MANIFESTATION.REPLY.PLACEHOLDER')"
        />
        <input
          ref="arquivoRef"
          type="file"
          multiple
          class="w-full mb-0 text-sm"
          @change="onArquivos"
        />
        <NextButton
          size="sm"
          :label="t('MANIFESTATION.REPLY.SEND')"
          :is-loading="isSending"
          :disabled="!resposta.trim()"
          class="self-start"
          @click="enviar"
        />
      </div>
      <p v-else class="m-0 text-sm text-n-slate-11">
        {{ t('MANIFESTATION.REPLY.FINISHED') }}
      </p>

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
    </div>
  </div>
</template>
