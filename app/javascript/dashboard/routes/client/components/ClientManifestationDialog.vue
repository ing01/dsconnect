<script setup>
/**
 * O formulário de nova manifestação, no Portal do Cliente.
 *
 * Empresa e solicitante NÃO aparecem como campo: são os do contato autenticado,
 * preenchidos no servidor. Mostrá-los como campo desabilitado sugeriria que há
 * uma escolha ali - e mostrá-los como campo editável seria mentira, porque o
 * servidor ignora o que vier no corpo (ver
 * Api::V1::Client::ManifestationsController).
 *
 * Mesmo arranjo do `ClientTicketDialog`: `Dialog` de `components-next`, que
 * emite `confirm` e NUNCA se fecha sozinho - quem chama é que decide, e por
 * isso o `close()` daqui é explícito.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  kindOptions,
  subjectAreaOptions,
} from 'dashboard/routes/dashboard/manifestations/helpers/manifestationLabels';

const emit = defineEmits(['created']);

const { t } = useI18n();

const dialogRef = ref(null);
const arquivoRef = ref(null);

const kind = ref('suggestion');
const subjectArea = ref('erp');
const title = ref('');
const description = ref('');
const arquivos = ref([]);
const isSubmitting = ref(false);

const tipos = computed(() => kindOptions(t));
const assuntos = computed(() => subjectAreaOptions(t));

// Título e descrição são os dois obrigatórios - os mesmos que o servidor exige.
const isInvalid = computed(
  () => !title.value.trim() || !description.value.trim()
);

const limpar = () => {
  kind.value = 'suggestion';
  subjectArea.value = 'erp';
  title.value = '';
  description.value = '';
  arquivos.value = [];
  if (arquivoRef.value) arquivoRef.value.value = null;
};

const open = () => {
  limpar();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const onArquivos = evento => {
  arquivos.value = Array.from(evento.target.files || []);
};

const removerArquivo = indice => {
  arquivos.value = arquivos.value.filter((_, i) => i !== indice);
  if (arquivoRef.value) arquivoRef.value.value = null;
};

const submit = async () => {
  if (isInvalid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const { data } = await ClientAreaAPI.createManifestation(
      {
        kind: kind.value,
        subject_area: subjectArea.value,
        title: title.value.trim(),
        description: description.value.trim(),
      },
      arquivos.value
    );
    useAlert(t('MANIFESTATION.NEW.DONE', { reference: data.reference }));
    emit('created', data);
    close();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('MANIFESTATION.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('MANIFESTATION.NEW.TITLE')"
    :description="t('MANIFESTATION.NEW.INTRO')"
    :confirm-button-label="t('MANIFESTATION.NEW.SUBMIT')"
    :cancel-button-label="t('MANIFESTATION.NEW.CANCEL')"
    :is-loading="isSubmitting"
    :disable-confirm-button="isInvalid"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <div class="grid gap-4 sm:grid-cols-2">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('MANIFESTATION.FIELDS.KIND') }}
          </span>
          <select v-model="kind" class="w-full mb-0">
            <option
              v-for="opcao in tipos"
              :key="opcao.value"
              :value="opcao.value"
            >
              {{ opcao.label }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('MANIFESTATION.FIELDS.SUBJECT_AREA') }}
          </span>
          <select v-model="subjectArea" class="w-full mb-0">
            <option
              v-for="opcao in assuntos"
              :key="opcao.value"
              :value="opcao.value"
            >
              {{ opcao.label }}
            </option>
          </select>
        </label>
      </div>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.FIELDS.TITLE') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <input
          v-model="title"
          type="text"
          class="w-full mb-0"
          :placeholder="t('MANIFESTATION.FIELDS.TITLE_PLACEHOLDER')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.FIELDS.DESCRIPTION') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <textarea
          v-model="description"
          rows="5"
          class="w-full mb-0"
          :placeholder="t('MANIFESTATION.FIELDS.DESCRIPTION_PLACEHOLDER')"
        />
      </label>

      <div class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('MANIFESTATION.FIELDS.ATTACHMENTS') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{ t('MANIFESTATION.FIELDS.ATTACHMENTS_HINT') }}
        </span>
        <input
          ref="arquivoRef"
          type="file"
          multiple
          class="w-full mb-0 text-sm"
          @change="onArquivos"
        />
        <ul
          v-if="arquivos.length"
          class="flex flex-col gap-1 p-0 m-0 list-none"
        >
          <li
            v-for="(arquivo, indice) in arquivos"
            :key="`${arquivo.name}-${indice}`"
            class="flex items-center gap-2 text-sm text-n-slate-11 min-w-0"
          >
            <Icon icon="i-lucide-paperclip" class="flex-shrink-0 size-4" />
            <span class="truncate">{{ arquivo.name }}</span>
            <button
              type="button"
              class="flex-shrink-0 text-n-ruby-11"
              @click="removerArquivo(indice)"
            >
              <Icon icon="i-lucide-x" class="size-4" />
            </button>
          </li>
        </ul>
      </div>
    </div>
  </Dialog>
</template>
