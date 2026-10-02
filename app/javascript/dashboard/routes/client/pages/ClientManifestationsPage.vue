<script setup>
/**
 * "SAC e Sugestões" no Portal do Cliente.
 *
 * Lista as manifestações que este contato pode ver - o recorte por empresa e
 * pela permissão dele é feito no servidor (`Contact#visible_manifestations`), e
 * não aqui: filtrar no navegador exigiria baixar o que ele não pode ver.
 *
 * Cartões, e não tabela: no celular uma tabela de sete colunas vira rolagem
 * lateral, e esta é a tela que mais é aberta do telefone.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  statusColor,
  kindColor,
} from 'dashboard/routes/dashboard/manifestations/helpers/manifestationLabels';
import ClientManifestationDialog from '../components/ClientManifestationDialog.vue';

const { t } = useI18n();
const router = useRouter();

const isLoading = ref(true);
const items = ref([]);
const dialogRef = ref(null);

const temItens = computed(() => items.value.length > 0);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

const carregar = async () => {
  try {
    const { data } = await ClientAreaAPI.manifestations();
    items.value = data.payload || [];
  } catch {
    useAlert(t('MANIFESTATION.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const abrir = item =>
  router.push({
    name: 'client_manifestation_detail',
    params: { manifestationId: item.id },
  });

// Depois de registrar, vai direto para o detalhe: é onde o acompanhamento
// acontece, e é o que a pessoa quer ver a seguir.
const onCriada = manifestacao => {
  items.value = [manifestacao, ...items.value];
  abrir(manifestacao);
};

onMounted(carregar);
</script>

<template>
  <div class="flex flex-col flex-1 h-full min-h-0 gap-4 p-4 min-w-0 sm:p-6">
    <div class="flex flex-wrap items-start justify-between flex-shrink-0 gap-3">
      <div class="min-w-0">
        <h1 class="m-0 text-xl font-medium text-n-slate-12">
          {{ t('MANIFESTATION.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('MANIFESTATION.DESCRIPTION') }}
        </p>
      </div>
      <NextButton
        size="sm"
        icon="i-lucide-plus"
        :label="t('MANIFESTATION.NEW.ACTION')"
        class="flex-shrink-0"
        @click="dialogRef?.open()"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center py-16 text-n-slate-10">
      <Spinner />
    </div>

    <div
      v-else-if="!temItens"
      class="flex flex-col items-center gap-2 py-16 text-center text-n-slate-11"
    >
      <Icon icon="i-lucide-message-square-plus" class="size-8" />
      <p class="m-0 text-sm">{{ t('MANIFESTATION.LIST.EMPTY') }}</p>
    </div>

    <ul
      v-else
      class="flex flex-col gap-3 p-0 m-0 overflow-y-auto list-none grow min-h-0"
    >
      <li v-for="item in items" :key="item.id">
        <button
          type="button"
          class="flex flex-col w-full gap-2 p-4 text-left border rounded-xl border-n-weak hover:bg-n-alpha-1 min-w-0"
          @click="abrir(item)"
        >
          <span class="flex flex-wrap items-center gap-2 min-w-0">
            <span class="text-xs font-medium text-n-slate-11">
              {{ item.reference }}
            </span>
            <Label
              :label="t(`MANIFESTATION.KINDS.${item.kind}`)"
              :color="kindColor(item.kind)"
              compact
            />
            <Label
              :label="t(`MANIFESTATION.STATUSES.${item.status}`)"
              :color="statusColor(item.status)"
              compact
            />
          </span>

          <span class="text-sm font-medium truncate text-n-slate-12 min-w-0">
            {{ item.title }}
          </span>

          <span
            class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-n-slate-11 min-w-0"
          >
            <span>{{
              t(`MANIFESTATION.SUBJECT_AREAS.${item.subject_area}`)
            }}</span>
            <span>{{ dataHora(item.created_at) }}</span>
            <!-- Convertida em ticket: o cliente precisa saber que o assunto
                 passou a ser tratado como chamado. -->
            <span
              v-if="item.converted"
              class="flex items-center gap-1 text-n-teal-11"
            >
              <Icon icon="i-lucide-ticket" class="size-3.5" />
              {{ `#${item.converted_ticket_display_id}` }}
            </span>
          </span>
        </button>
      </li>
    </ul>

    <ClientManifestationDialog ref="dialogRef" @created="onCriada" />
  </div>
</template>
