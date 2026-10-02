<script setup>
/**
 * "Converter em Ticket".
 *
 * Quem decide a Mesa é quem converte - a conversão não adivinha: a manifestação
 * não tem Mesa, e escolher a primeira ativa em silêncio mandaria uma reclamação
 * do comercial para o Suporte.
 *
 * A Categoria é opcional. Quando não escolhida, o servidor usa a entrada padrão
 * da Mesa, porque o ticket EXIGE categoria - e barrar a conversão por uma
 * escolha que é nossa seria pior.
 *
 * O diálogo não impede a segunda conversão: quem impede é o servidor
 * (`converted_ticket_id` preenchido). Aqui o botão simplesmente deixa de
 * aparecer, o que é conveniência, não regra.
 */
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  manifestation: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const dialogRef = ref(null);
const teamId = ref('');
const categoryId = ref('');

const teams = computed(() =>
  (getters['teams/getTeams'].value || []).filter(team => team.active !== false)
);
const uiFlags = computed(() => getters['manifestations/getUIFlags'].value);

// As Categorias da Mesa escolhida. Elas vivem no modulo `ticketColumns` - sao
// por Mesa, como os Estagios -, e nao num modulo proprio.
//
// Categoria de outra Mesa nao sobrevive a validacao do ticket
// (`ticket_category_belongs_to_team`), entao a lista acompanha a Mesa.
const categories = computed(() =>
  teamId.value
    ? getters['ticketColumns/getCategories'].value(teamId.value) || []
    : []
);

// Trocar a Mesa descarta a Categoria: ela pertencia a Mesa anterior.
watch(teamId, async novo => {
  categoryId.value = '';
  if (novo) {
    await store.dispatch('ticketColumns/fetchCategories', novo);
  }
});

const open = async () => {
  teamId.value = '';
  categoryId.value = '';
  await store.dispatch('teams/get');
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const confirmar = async () => {
  try {
    const dados = await store.dispatch('manifestations/convert', {
      id: props.manifestation.id,
      teamId: teamId.value || null,
      ticketCategoryId: categoryId.value || null,
    });
    useAlert(
      t('MANIFESTATION.CONVERT.DONE', {
        number: dados.converted_ticket_display_id,
      })
    );
    close();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('MANIFESTATION.API.ERROR'));
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('MANIFESTATION.CONVERT.TITLE')"
    :description="t('MANIFESTATION.CONVERT.DESCRIPTION')"
    :confirm-button-label="t('MANIFESTATION.CONVERT.CONFIRM')"
    :cancel-button-label="t('MANIFESTATION.CONVERT.CANCEL')"
    :is-loading="uiFlags.isConverting"
    :disable-confirm-button="!teamId"
    @confirm="confirmar"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.CONVERT.TEAM') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <select v-model="teamId" class="w-full mb-0">
          <option value="" disabled>—</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ formatMesaName(team.name) }}
          </option>
        </select>
      </label>

      <label v-if="categories.length" class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.CONVERT.CATEGORY') }}
        </span>
        <select v-model="categoryId" class="w-full mb-0">
          <option value="">—</option>
          <option
            v-for="categoria in categories"
            :key="categoria.id"
            :value="categoria.id"
          >
            {{ categoria.name }}
          </option>
        </select>
      </label>
    </div>
  </Dialog>
</template>
