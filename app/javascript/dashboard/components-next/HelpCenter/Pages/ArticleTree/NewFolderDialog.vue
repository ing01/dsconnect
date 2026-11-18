<script setup>
/**
 * Cria uma pasta (Categoria da Central de Ajuda), na raiz ou dentro de outra pasta (subpasta).
 * O endereco (slug) sai do nome: quem organiza so' precisa dizer como a pasta se chama.
 */
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { convertToCategorySlug } from 'dashboard/helper/commons';
import categoriesAPI from 'dashboard/api/helpCenter/categories';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  portalSlug: { type: String, required: true },
  locale: { type: String, required: true },
  folders: { type: Array, default: () => [] },
});

const emit = defineEmits(['created']);

const { t } = useI18n();

// Espaco que nao some dentro do <option>: mostra a hierarquia.
const INDENT = String.fromCharCode(160).repeat(2);

const dialogRef = ref(null);
const name = ref('');
const parentId = ref('');
const isSaving = ref(false);

const canSave = computed(() => name.value.trim().length > 0);

const open = (initialParentId = null) => {
  name.value = '';
  parentId.value = initialParentId || '';
  dialogRef.value?.open();
};

const save = async () => {
  if (!canSave.value || isSaving.value) return;

  isSaving.value = true;
  try {
    const trimmed = name.value.trim();
    await categoriesAPI.create({
      portalSlug: props.portalSlug,
      categoryObj: {
        name: trimmed,
        slug: convertToCategorySlug(trimmed),
        locale: props.locale,
        description: '',
        ...(parentId.value ? { parent_category_id: parentId.value } : {}),
      },
    });
    useAlert(t('HELP_CENTER.KB_TREE.FOLDER.SUCCESS'));
    dialogRef.value?.close();
    emit('created');
  } catch (error) {
    useAlert(
      error?.response?.data?.message || t('HELP_CENTER.KB_TREE.FOLDER.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('HELP_CENTER.KB_TREE.FOLDER.TITLE')"
    :confirm-button-label="t('HELP_CENTER.KB_TREE.FOLDER.CONFIRM')"
    :disable-confirm-button="!canSave"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-4">
      <label class="flex flex-col gap-1 text-sm">
        <span class="font-medium text-n-slate-12">
          {{ t('HELP_CENTER.KB_TREE.FOLDER.NAME') }}
        </span>
        <input
          v-model="name"
          type="text"
          class="w-full mb-0 text-sm"
          :placeholder="t('HELP_CENTER.KB_TREE.FOLDER.NAME_PLACEHOLDER')"
          data-testid="kb-folder-name"
        />
      </label>
      <label class="flex flex-col gap-1 text-sm">
        <span class="font-medium text-n-slate-12">
          {{ t('HELP_CENTER.KB_TREE.FOLDER.PARENT') }}
        </span>
        <select
          v-model="parentId"
          class="w-full mb-0 text-sm"
          data-testid="kb-folder-parent"
        >
          <option value="">
            {{ t('HELP_CENTER.KB_TREE.FOLDER.NO_PARENT') }}
          </option>
          <option v-for="folder in folders" :key="folder.id" :value="folder.id">
            {{ INDENT.repeat(folder.depth) + folder.label }}
          </option>
        </select>
      </label>
    </div>
  </Dialog>
</template>
