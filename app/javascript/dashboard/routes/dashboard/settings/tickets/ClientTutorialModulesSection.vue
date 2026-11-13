<script setup>
/**
 * Os módulos dos tutoriais (DS Connect, DS Comercial...): cada um vira um card na
 * aba Tutoriais da Área do Cliente e abre os vídeos que estão dentro. Fica no topo
 * da tela Configurações > Tutoriais do Portal.
 *
 * Quem guarda a lista é a tela pai (o formulário do tutorial também usa os módulos
 * num seletor); aqui só se edita e, a cada mudança, o pai é avisado para recarregar.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { DirectUpload } from 'activestorage';
import { useAlert } from 'dashboard/composables';
import { setDirectUploadAuthHeaders } from 'dashboard/helper/directUploadsHelper';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import ClientTutorialModulesAPI from 'dashboard/api/clientTutorialModules';
import ClientTutorialsAPI from 'dashboard/api/clientTutorials';

import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmButton from 'dashboard/components-next/button/ConfirmButton.vue';

const props = defineProps({
  modules: { type: Array, default: () => [] },
});
const emit = defineEmits(['changed']);

const { t } = useI18n();

const showForm = ref(false);
const editing = ref(null);
const name = ref('');
const description = ref('');
const active = ref(true);
const isSubmitting = ref(false);

const MAXIMUM_LOGO_MB = 5;
const LOGO_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];
// Logo já salvo no módulo em edição ({ url, name }) e o recém-enviado, ainda
// não salvo ({ signedId, name, url }).
const savedLogo = ref(null);
const uploadedLogo = ref(null);
const removeSavedLogo = ref(false);
const isUploading = ref(false);
const logoInput = ref(null);
const shownLogo = computed(() => uploadedLogo.value || savedLogo.value);

const aviso = error =>
  useAlert(
    parseAPIErrorResponse(error) ||
      t('TICKET.SETTINGS.CLIENT_TUTORIALS.API.ERROR')
  );

const resetForm = () => {
  editing.value = null;
  name.value = '';
  description.value = '';
  active.value = true;
  savedLogo.value = null;
  uploadedLogo.value = null;
  removeSavedLogo.value = false;
  isUploading.value = false;
};

const openCreate = () => {
  resetForm();
  showForm.value = true;
};

const openEdit = module => {
  resetForm();
  editing.value = module;
  name.value = module.name;
  description.value = module.description || '';
  active.value = module.active;
  if (module.logo_url) {
    savedLogo.value = { url: module.logo_url, name: module.logo_name };
  }
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
  resetForm();
};

const pickLogo = () => logoInput.value?.click();

const uploadLogo = file =>
  new Promise((resolve, reject) => {
    const upload = new DirectUpload(
      file,
      ClientTutorialsAPI.directUploadUrl(),
      { directUploadWillCreateBlobWithXHR: setDirectUploadAuthHeaders }
    );
    upload.create((error, blob) => (error ? reject(error) : resolve(blob)));
  });

const onLogoChosen = async event => {
  const [file] = Array.from(event.target.files || []);
  event.target.value = '';
  if (!file) return;

  if (!LOGO_TYPES.includes(file.type)) {
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.ERRORS.LOGO_TYPE'));
    return;
  }
  if (file.size > MAXIMUM_LOGO_MB * 1024 * 1024) {
    useAlert(
      t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.ERRORS.LOGO_SIZE', {
        size: MAXIMUM_LOGO_MB,
      })
    );
    return;
  }

  isUploading.value = true;
  try {
    const blob = await uploadLogo(file);
    uploadedLogo.value = {
      signedId: blob.signed_id,
      name: file.name,
      url: URL.createObjectURL(file),
    };
  } catch {
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.ERRORS.UPLOAD_FAILED'));
  } finally {
    isUploading.value = false;
  }
};

const removeLogo = () => {
  uploadedLogo.value = null;
  if (savedLogo.value) {
    savedLogo.value = null;
    removeSavedLogo.value = true;
  }
};

const submit = async () => {
  if (!name.value.trim() || isUploading.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const payload = {
      client_tutorial_module: {
        name: name.value.trim(),
        description: description.value.trim(),
        active: active.value,
      },
    };
    if (uploadedLogo.value) {
      payload.logo_signed_id = uploadedLogo.value.signedId;
    } else if (removeSavedLogo.value) {
      payload.remove_logo = true;
    }
    if (editing.value) {
      await ClientTutorialModulesAPI.update(editing.value.id, payload);
    } else {
      await ClientTutorialModulesAPI.create(payload);
    }
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.API.SAVED'));
    closeForm();
    emit('changed');
  } catch (error) {
    aviso(error);
  } finally {
    isSubmitting.value = false;
  }
};

const toggleActive = async module => {
  try {
    await ClientTutorialModulesAPI.update(module.id, {
      client_tutorial_module: { active: !module.active },
    });
    emit('changed');
  } catch (error) {
    aviso(error);
  }
};

// Mesma ideia dos tutoriais: troca com o vizinho e regrava a posição de todos.
const move = async (index, delta) => {
  if (!props.modules[index + delta]) return;

  const reordered = [...props.modules];
  [reordered[index], reordered[index + delta]] = [
    reordered[index + delta],
    reordered[index],
  ];

  try {
    await Promise.all(
      reordered
        .map((module, position) => ({ module, position }))
        .filter(({ module, position }) => module.position !== position)
        .map(({ module, position }) =>
          ClientTutorialModulesAPI.update(module.id, {
            client_tutorial_module: { position },
          })
        )
    );
    emit('changed');
  } catch (error) {
    aviso(error);
  }
};

const remove = async module => {
  try {
    await ClientTutorialModulesAPI.delete(module.id);
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.API.DELETED'));
    if (editing.value?.id === module.id) closeForm();
    emit('changed');
  } catch (error) {
    aviso(error);
  }
};
</script>

<template>
  <section
    class="flex flex-col gap-3 min-w-0"
    data-testid="tutorial-modules-section"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-col">
        <h3 class="m-0 text-base font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.TITLE') }}
        </h3>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.DESCRIPTION') }}
        </p>
      </div>
      <Button
        size="sm"
        slate
        faded
        icon="i-lucide-plus"
        :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.ADD')"
        data-testid="module-add"
        @click="openCreate"
      />
    </div>

    <form
      v-if="showForm"
      class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak min-w-0"
      data-testid="module-form"
      @submit.prevent="submit"
    >
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.NAME') }}
        </span>
        <input
          v-model="name"
          type="text"
          maxlength="120"
          class="w-full mb-0"
          :placeholder="
            t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.NAME_PLACEHOLDER')
          "
        />
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.DESCRIPTION') }}
        </span>
        <textarea
          v-model="description"
          rows="2"
          maxlength="500"
          class="w-full mb-0"
          :placeholder="
            t(
              'TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.DESCRIPTION_PLACEHOLDER'
            )
          "
        />
      </label>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.LOGO') }}
        </span>
        <input
          ref="logoInput"
          type="file"
          accept="image/png,image/jpeg,image/webp,image/gif"
          class="hidden"
          data-testid="module-logo-input"
          @change="onLogoChosen"
        />
        <div class="flex flex-wrap items-center gap-3 text-sm">
          <img
            v-if="shownLogo"
            :src="shownLogo.url"
            :alt="name"
            class="object-contain w-16 h-16 border rounded-lg border-n-weak"
            data-testid="module-logo-preview"
          />
          <Button
            type="button"
            size="sm"
            slate
            faded
            icon="i-lucide-image-plus"
            :label="
              shownLogo
                ? t(
                    'TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.LOGO_REPLACE'
                  )
                : t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.LOGO_PICK')
            "
            :disabled="isUploading"
            @click="pickLogo"
          />
          <span v-if="isUploading" class="text-n-slate-11">
            {{
              t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.LOGO_SENDING')
            }}
          </span>
          <button
            v-if="shownLogo && !isUploading"
            type="button"
            class="p-0 text-n-ruby-11 hover:underline"
            @click="removeLogo"
          >
            {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.FILE_REMOVE') }}
          </button>
        </div>
        <span class="text-xs text-n-slate-11">
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.FORM.LOGO_HINT') }}
        </span>
      </div>

      <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
        <input v-model="active" type="checkbox" class="mb-0" />
        {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.ACTIVE') }}
      </label>

      <div class="flex justify-end gap-2">
        <Button
          type="button"
          slate
          faded
          size="sm"
          :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.CANCEL')"
          @click="closeForm"
        />
        <Button
          type="submit"
          size="sm"
          :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.SAVE')"
          :disabled="!name.trim()"
          :is-loading="isSubmitting"
          data-testid="module-save"
        />
      </div>
    </form>

    <p
      v-if="!modules.length && !showForm"
      class="m-0 text-sm text-n-slate-11"
      data-testid="modules-empty"
    >
      {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.EMPTY') }}
    </p>

    <ul class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="(module, index) in modules"
        :key="module.id"
        class="flex flex-wrap items-center gap-3 p-3 border rounded-xl border-n-weak min-w-0"
        :data-testid="`module-row-${module.id}`"
      >
        <img
          v-if="module.logo_url"
          :src="module.logo_url"
          :alt="module.name"
          class="object-contain w-10 h-10 rounded"
        />
        <div class="flex flex-col min-w-0 grow">
          <span class="font-medium truncate text-n-slate-12">
            {{ module.name }}
          </span>
          <span
            v-if="module.description"
            class="text-xs truncate text-n-slate-11"
          >
            {{ module.description }}
          </span>
        </div>

        <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-11">
          <input
            type="checkbox"
            class="mb-0"
            :checked="module.active"
            :aria-label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.ACTIVE')"
            @change="toggleActive(module)"
          />
          {{
            module.active
              ? t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.ACTIVE')
              : t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.INACTIVE')
          }}
        </label>

        <div class="flex items-center gap-1">
          <Button
            slate
            ghost
            size="sm"
            icon="i-lucide-arrow-up"
            :title="t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.MOVE_UP')"
            :disabled="index === 0"
            @click="move(index, -1)"
          />
          <Button
            slate
            ghost
            size="sm"
            icon="i-lucide-arrow-down"
            :title="t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.MOVE_DOWN')"
            :disabled="index === modules.length - 1"
            @click="move(index, 1)"
          />
          <Button
            slate
            faded
            size="sm"
            icon="i-lucide-pencil"
            :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.EDIT')"
            @click="openEdit(module)"
          />
          <ConfirmButton
            :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.DELETE')"
            :confirm-label="
              t('TICKET.SETTINGS.CLIENT_TUTORIALS.MODULES.CONFIRM_DELETE')
            "
            color="slate"
            confirm-color="ruby"
            variant="outline"
            icon="i-lucide-trash-2"
            size="sm"
            @click="remove(module)"
          />
        </div>
      </li>
    </ul>
  </section>
</template>
