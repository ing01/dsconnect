<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['create', 'update']);

const { t } = useI18n();
const dialogRef = ref(null);
const mode = ref('add');
const editingId = ref(null);
const revealedFields = ref(new Set());

const DB_TYPE_OPTIONS = ['UTF8', 'SQL-ASCII'].map(value => ({
  value,
  label: value,
}));

const blankForm = () => ({
  label: '',
  dbType: '',
  dbName: '',
  dbHost: '',
  dbPort: '',
  dbUsername: '',
  dbPassword: '',
  remoteAccessType: '',
  anydeskId: '',
  anydeskPassword: '',
  rdpAddress: '',
  rdpUsername: '',
  rdpPassword: '',
  notes: '',
});

const form = reactive(blankForm());

const isFormInvalid = computed(() => !form.label.trim());
const dialogTitle = computed(() =>
  mode.value === 'edit'
    ? t('COMPANIES.DETAIL.CREDENTIALS.FORM.EDIT_TITLE')
    : t('COMPANIES.DETAIL.CREDENTIALS.FORM.ADD_TITLE')
);

const secretFieldType = key =>
  revealedFields.value.has(key) ? 'text' : 'password';

const toggleReveal = key => {
  const next = new Set(revealedFields.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  revealedFields.value = next;
};

const resetForm = () => {
  Object.assign(form, blankForm());
  revealedFields.value = new Set();
  mode.value = 'add';
  editingId.value = null;
};

const open = (credential = null) => {
  resetForm();
  if (credential) {
    mode.value = 'edit';
    editingId.value = credential.id;
    Object.assign(form, {
      label: credential.label || '',
      dbType: credential.dbType || '',
      dbName: credential.dbName || '',
      dbHost: credential.dbHost || '',
      dbPort: credential.dbPort || '',
      dbUsername: credential.dbUsername || '',
      dbPassword: credential.dbPassword || '',
      remoteAccessType: credential.remoteAccessType || '',
      anydeskId: credential.anydeskId || '',
      anydeskPassword: credential.anydeskPassword || '',
      rdpAddress: credential.rdpAddress || '',
      rdpUsername: credential.rdpUsername || '',
      rdpPassword: credential.rdpPassword || '',
      notes: credential.notes || '',
    });
  }
  dialogRef.value?.open();
};

const closeDialog = () => {
  dialogRef.value?.close();
};

const onSuccess = () => {
  resetForm();
  closeDialog();
};

const handleConfirm = () => {
  if (isFormInvalid.value) return;

  const payload = {
    label: form.label.trim(),
    dbType: form.dbType || null,
    dbName: form.dbName.trim() || null,
    dbHost: form.dbHost.trim() || null,
    dbPort: form.dbPort || null,
    dbUsername: form.dbUsername.trim() || null,
    dbPassword: form.dbPassword || null,
    remoteAccessType: form.remoteAccessType.trim() || null,
    anydeskId: form.anydeskId.trim() || null,
    anydeskPassword: form.anydeskPassword || null,
    rdpAddress: form.rdpAddress.trim() || null,
    rdpUsername: form.rdpUsername.trim() || null,
    rdpPassword: form.rdpPassword || null,
    notes: form.notes.trim() || null,
  };

  if (mode.value === 'edit') {
    emit('update', { id: editingId.value, payload });
  } else {
    emit('create', payload);
  }
};

defineExpose({ dialogRef, onSuccess, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    overflow-y-auto
    @confirm="handleConfirm"
    @close="resetForm"
  >
    <div class="flex flex-col gap-6">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ dialogTitle }}
      </span>

      <Input
        v-model="form.label"
        :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.LABEL.LABEL')"
        :placeholder="t('COMPANIES.DETAIL.CREDENTIALS.FORM.LABEL.PLACEHOLDER')"
        :disabled="isLoading"
        autofocus
      />

      <div class="flex flex-col gap-3">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('COMPANIES.DETAIL.CREDENTIALS.FORM.SECTION_DB') }}
        </span>
        <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <div class="flex flex-col gap-1">
            <label class="text-sm text-n-slate-11">
              {{ t('COMPANIES.DETAIL.CREDENTIALS.FORM.DB_TYPE.LABEL') }}
            </label>
            <Select
              v-model="form.dbType"
              :options="DB_TYPE_OPTIONS"
              :disabled="isLoading"
            />
          </div>
          <Input
            v-model="form.dbName"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.DB_NAME.LABEL')"
            :disabled="isLoading"
          />
          <Input
            v-model="form.dbHost"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.DB_HOST.LABEL')"
            :disabled="isLoading"
          />
          <Input
            v-model="form.dbPort"
            type="number"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.DB_PORT.LABEL')"
            :disabled="isLoading"
          />
          <Input
            v-model="form.dbUsername"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.DB_USERNAME.LABEL')"
            :disabled="isLoading"
          />
          <div class="flex items-end gap-1">
            <Input
              v-model="form.dbPassword"
              :type="secretFieldType('dbPassword')"
              :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.DB_PASSWORD.LABEL')"
              :disabled="isLoading"
              class="flex-1"
            />
            <Button
              icon="i-lucide-eye"
              variant="ghost"
              color="slate"
              size="sm"
              class="mb-1"
              @click="toggleReveal('dbPassword')"
            />
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('COMPANIES.DETAIL.CREDENTIALS.FORM.SECTION_REMOTE_ACCESS') }}
        </span>
        <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            v-model="form.remoteAccessType"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.REMOTE_ACCESS_TYPE.LABEL')"
            :placeholder="t('COMPANIES.DETAIL.CREDENTIALS.FORM.REMOTE_ACCESS_TYPE.PLACEHOLDER')"
            :disabled="isLoading"
          />
          <Input
            v-model="form.anydeskId"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.REMOTE_ACCESS_ID.LABEL')"
            :disabled="isLoading"
          />
          <div class="flex items-end gap-1">
            <Input
              v-model="form.anydeskPassword"
              :type="secretFieldType('anydeskPassword')"
              :label="
                t('COMPANIES.DETAIL.CREDENTIALS.FORM.REMOTE_ACCESS_PASSWORD.LABEL')
              "
              :disabled="isLoading"
              class="flex-1"
            />
            <Button
              icon="i-lucide-eye"
              variant="ghost"
              color="slate"
              size="sm"
              class="mb-1"
              @click="toggleReveal('anydeskPassword')"
            />
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('COMPANIES.DETAIL.CREDENTIALS.FORM.SECTION_RDP') }}
        </span>
        <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            v-model="form.rdpAddress"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.RDP_ADDRESS.LABEL')"
            :disabled="isLoading"
          />
          <Input
            v-model="form.rdpUsername"
            :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.RDP_USERNAME.LABEL')"
            :disabled="isLoading"
          />
          <div class="flex items-end gap-1">
            <Input
              v-model="form.rdpPassword"
              :type="secretFieldType('rdpPassword')"
              :label="
                t('COMPANIES.DETAIL.CREDENTIALS.FORM.RDP_PASSWORD.LABEL')
              "
              :disabled="isLoading"
              class="flex-1"
            />
            <Button
              icon="i-lucide-eye"
              variant="ghost"
              color="slate"
              size="sm"
              class="mb-1"
              @click="toggleReveal('rdpPassword')"
            />
          </div>
        </div>
      </div>

      <TextArea
        v-model="form.notes"
        :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.NOTES.LABEL')"
        :disabled="isLoading"
        :max-length="2000"
        class="w-full"
        auto-height
      />
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.CANCEL')"
          variant="link"
          type="reset"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click="closeDialog"
        />
        <Button
          :label="t('COMPANIES.DETAIL.CREDENTIALS.FORM.SAVE')"
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
