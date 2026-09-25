<script setup>
/**
 * Abertura de chamado pelo cliente.
 *
 * Monta o `Dialog` de `components-next` - o mesmo que os diálogos de ticket do
 * painel usam (fechamento, catálogo, transferência) -, e não um modal montado à
 * mão. Com isso vêm o espaçamento, o cabeçalho e o rodapé padrão do sistema, e
 * a largura responsiva.
 *
 * O formulário pede apenas o PROBLEMA: categoria, assunto, descrição e
 * arquivos. Mesa, Estágio e prioridade são decisão de quem atende e acontecem
 * na triagem - pedir isso ao cliente seria pedir que adivinhasse o organograma
 * do atendimento.
 *
 * Empresa e solicitante também não aparecem: o servidor grava os do contato
 * autenticado, e mandar outros no corpo não muda nada - vide
 * Api::V1::Client::TicketsController.
 */
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import TicketSelect from 'dashboard/routes/dashboard/tickets/components/TicketSelect.vue';
import TicketFileInput from 'dashboard/routes/dashboard/tickets/components/create/TicketFileInput.vue';

const props = defineProps({
  categories: { type: Array, default: () => [] },
});

const emit = defineEmits(['created']);

const { t } = useI18n();

const dialogRef = ref(null);
const isSubmitting = ref(false);
const files = ref([]);
// O que falta, por campo. Preenchido só quando a pessoa tenta enviar: apontar
// erro antes de ela ter a chance de preencher é rabugice.
const erros = ref({});
const form = ref({ categoryId: null, title: '', description: '' });

const categoryOptions = computed(() =>
  props.categories.map(c => ({ value: c.id, label: c.name }))
);

// A Categoria escolhida pode exigir anexo - a regra vem do cadastro dela, e não
// daqui.
const exigeAnexo = computed(() =>
  Boolean(
    props.categories.find(c => c.id === form.value.categoryId)
      ?.require_attachment
  )
);

// O que está faltando, campo a campo.
//
// O botão de confirmar NÃO fica desabilitado: um botão apagado não diz o que
// falta, e a pessoa fica olhando para a tela sem saber o que fazer. Ele
// continua clicável e o clique aponta o campo.
const camposFaltando = () => {
  const faltando = {};

  if (!form.value.categoryId) {
    faltando.categoryId = t('CLIENT_AREA.NEW_TICKET.ERRORS.CATEGORY');
  }
  if (!form.value.title.trim()) {
    faltando.title = t('CLIENT_AREA.NEW_TICKET.ERRORS.SUBJECT');
  }
  if (!form.value.description.trim()) {
    faltando.description = t('CLIENT_AREA.NEW_TICKET.ERRORS.BODY');
  }
  // O servidor recusa de todo jeito; aqui a checagem existe para a pessoa não
  // descobrir isso depois de escrever o chamado inteiro.
  if (exigeAnexo.value && !files.value.length) {
    faltando.files = t('CLIENT_AREA.NEW_TICKET.ERRORS.FILES');
  }

  return faltando;
};

// Corrigir o campo apaga o aviso dele na hora - manter o vermelho depois de
// preenchido faria a tela mentir.
watch(
  [form, files],
  () => {
    if (!Object.keys(erros.value).length) return;

    const aindaFaltando = camposFaltando();
    erros.value = Object.fromEntries(
      Object.entries(erros.value).filter(([campo]) => aindaFaltando[campo])
    );
  },
  { deep: true }
);

const open = () => {
  files.value = [];
  erros.value = {};
  form.value = { categoryId: null, title: '', description: '' };
  dialogRef.value?.open();
};

const submit = async () => {
  if (isSubmitting.value) return;

  const faltando = camposFaltando();
  if (Object.keys(faltando).length) {
    erros.value = faltando;
    // O aviso nomeia o que falta; a borda vermelha diz ONDE. Um sem o outro
    // deixa a pessoa procurando.
    useAlert(
      t('CLIENT_AREA.NEW_TICKET.ERRORS.SUMMARY', {
        fields: Object.values(faltando).join(', '),
      })
    );
    return;
  }

  erros.value = {};
  isSubmitting.value = true;
  try {
    const { data } = await ClientAreaAPI.createTicket(
      {
        ticket_category_id: form.value.categoryId,
        title: form.value.title.trim(),
        description: form.value.description.trim(),
      },
      files.value
    );
    useAlert(t('CLIENT_AREA.NEW_TICKET.CREATED', { number: data.display_id }));
    dialogRef.value?.close();
    emit('created', data);
  } catch (error) {
    // A recusa do servidor vem com `error` (e `message` quando é validação do
    // model). Ler só uma das duas faz a tela cair na mensagem genérica.
    const resposta = error?.response?.data || {};

    if (resposta.code === 'attachment_required') {
      erros.value = { files: t('CLIENT_AREA.NEW_TICKET.ERRORS.FILES') };
    }

    useAlert(
      resposta.error || resposta.message || t('CLIENT_AREA.NEW_TICKET.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="2xl"
    overflow-y-auto
    :title="t('CLIENT_AREA.NEW_TICKET.TITLE')"
    :description="t('CLIENT_AREA.NEW_TICKET.DESCRIPTION')"
    :cancel-button-label="t('CLIENT_AREA.NEW_TICKET.CANCEL')"
    :confirm-button-label="t('CLIENT_AREA.NEW_TICKET.CONFIRM')"
    :is-loading="isSubmitting"
    @confirm="submit"
  >
    <div class="flex flex-col w-full gap-4 min-w-0">
      <label
        class="flex flex-col w-full gap-1 min-w-0 sm:max-w-[calc(50%-0.5rem)]"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.NEW_TICKET.CATEGORY') }}
        </span>
        <TicketSelect
          v-model="form.categoryId"
          :options="categoryOptions"
          :has-error="Boolean(erros.categoryId)"
          class="w-full"
          show-search
          :search-placeholder="t('CLIENT_AREA.NEW_TICKET.CATEGORY_SEARCH')"
          :placeholder="t('CLIENT_AREA.NEW_TICKET.CATEGORY_PLACEHOLDER')"
        />
        <span v-if="erros.categoryId" class="text-xs erro-campo text-n-ruby-9">
          {{ erros.categoryId }}
        </span>
      </label>

      <Input
        v-model="form.title"
        :label="t('CLIENT_AREA.NEW_TICKET.SUBJECT')"
        :placeholder="t('CLIENT_AREA.NEW_TICKET.SUBJECT_PLACEHOLDER')"
        :message="erros.title"
        :message-type="erros.title ? 'error' : 'info'"
        class="w-full"
      />

      <TextArea
        v-model="form.description"
        :label="t('CLIENT_AREA.NEW_TICKET.BODY')"
        :placeholder="t('CLIENT_AREA.NEW_TICKET.BODY_PLACEHOLDER')"
        :max-length="5000"
        :message="erros.description"
        :message-type="erros.description ? 'error' : 'info'"
        min-height="8rem"
        max-height="16rem"
        resize
        class="w-full"
      />

      <!-- Em erro o bloco inteiro ganha contorno: o anexo não é um campo com
           borda própria, então destacar só o texto não mostraria ONDE. -->
      <div
        class="flex flex-col w-full gap-1 min-w-0 rounded-lg transition-colors"
        :class="erros.files ? 'border border-n-ruby-8 p-3 -m-0.5' : ''"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.NEW_TICKET.FILES') }}
          <span v-if="exigeAnexo" class="text-n-ruby-11">*</span>
        </span>
        <TicketFileInput v-model="files" />
        <span v-if="erros.files" class="text-xs erro-campo text-n-ruby-9">
          {{ erros.files }}
        </span>
        <span v-else-if="exigeAnexo" class="text-xs text-n-amber-11">
          {{ t('CLIENT_AREA.NEW_TICKET.FILES_REQUIRED') }}
        </span>
      </div>

      <p class="m-0 text-xs text-n-slate-10">
        {{ t('CLIENT_AREA.NEW_TICKET.TRIAGE_NOTE') }}
      </p>
    </div>
  </Dialog>
</template>
