<script setup>
/**
 * Configurações > Tickets > Tutoriais do Portal.
 *
 * O administrador cadastra o que o cliente vê na aba "Tutoriais" da Área do
 * Cliente: título, texto e o vídeo - um link (YouTube/Vimeo) OU um arquivo MP4
 * enviado daqui. Tudo é editável depois: dá para trocar o vídeo, reordenar,
 * desativar (some para o cliente sem apagar) e excluir.
 *
 * O arquivo vai direto do navegador para o storage (o vídeo pesa dezenas de MB);
 * o servidor só recebe o identificador do envio junto do formulário.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { DirectUpload } from 'activestorage';
import { useAlert } from 'dashboard/composables';
import { setDirectUploadAuthHeaders } from 'dashboard/helper/directUploadsHelper';
import { resolveTutorialVideo } from 'dashboard/helper/tutorialVideo';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import ClientTutorialsAPI from 'dashboard/api/clientTutorials';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmButton from 'dashboard/components-next/button/ConfirmButton.vue';

const MAXIMUM_VIDEO_MB = 500;
const VIDEO_TYPES = ['video/mp4', 'video/webm'];

const { t } = useI18n();

const tutorials = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);

// Formulário: `editing` é o tutorial em edição, ou null quando está criando.
const showForm = ref(false);
const editing = ref(null);
const title = ref('');
const description = ref('');
const active = ref(true);
// 'link' ou 'file': o servidor guarda um OU o outro.
const source = ref('link');
const videoUrl = ref('');
// Arquivo já salvo no tutorial em edição, e o recém-enviado (ainda não salvo).
const savedFile = ref(null);
const uploadedFile = ref(null);
const removeSavedFile = ref(false);
const uploadProgress = ref(null);
const fileInput = ref(null);

const isUploading = computed(() => uploadProgress.value !== null);
const isInvalid = computed(() => !title.value.trim() || isUploading.value);

const aviso = error =>
  useAlert(
    parseAPIErrorResponse(error) ||
      t('TICKET.SETTINGS.CLIENT_TUTORIALS.API.ERROR')
  );

const fetchTutorials = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClientTutorialsAPI.get();
    tutorials.value = data;
  } catch (error) {
    aviso(error);
  } finally {
    isLoading.value = false;
  }
};

const resetForm = () => {
  editing.value = null;
  title.value = '';
  description.value = '';
  active.value = true;
  source.value = 'link';
  videoUrl.value = '';
  savedFile.value = null;
  uploadedFile.value = null;
  removeSavedFile.value = false;
  uploadProgress.value = null;
};

const openCreate = () => {
  resetForm();
  showForm.value = true;
};

const openEdit = tutorial => {
  resetForm();
  editing.value = tutorial;
  title.value = tutorial.title;
  description.value = tutorial.description || '';
  active.value = tutorial.active;
  if (tutorial.video_file_url) {
    source.value = 'file';
    savedFile.value = {
      name: tutorial.video_file_name,
      url: tutorial.video_file_url,
    };
  } else {
    videoUrl.value = tutorial.video_url || '';
  }
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
  resetForm();
};

const pickFile = () => fileInput.value?.click();

const uploadFile = file =>
  new Promise((resolve, reject) => {
    const upload = new DirectUpload(
      file,
      ClientTutorialsAPI.directUploadUrl(),
      {
        directUploadWillCreateBlobWithXHR: setDirectUploadAuthHeaders,
        directUploadWillStoreFileWithXHR: request =>
          request.upload.addEventListener('progress', event => {
            if (event.lengthComputable) {
              uploadProgress.value = Math.round(
                (event.loaded / event.total) * 100
              );
            }
          }),
      }
    );
    upload.create((error, blob) => (error ? reject(error) : resolve(blob)));
  });

const onFileChosen = async event => {
  const [file] = Array.from(event.target.files || []);
  event.target.value = '';
  if (!file) return;

  if (!VIDEO_TYPES.includes(file.type)) {
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.ERRORS.FILE_TYPE'));
    return;
  }
  if (file.size > MAXIMUM_VIDEO_MB * 1024 * 1024) {
    useAlert(
      t('TICKET.SETTINGS.CLIENT_TUTORIALS.ERRORS.FILE_TOO_LARGE', {
        size: MAXIMUM_VIDEO_MB,
      })
    );
    return;
  }

  uploadProgress.value = 0;
  try {
    const blob = await uploadFile(file);
    uploadedFile.value = { signedId: blob.signed_id, name: file.name };
  } catch {
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.ERRORS.UPLOAD_FAILED'));
  } finally {
    uploadProgress.value = null;
  }
};

const removeFile = () => {
  uploadedFile.value = null;
  if (savedFile.value) {
    savedFile.value = null;
    removeSavedFile.value = true;
  }
};

// O que o formulário manda: arquivo novo (signed id), link, ou a remoção do vídeo.
const buildPayload = () => {
  const payload = {
    client_tutorial: {
      title: title.value.trim(),
      description: description.value.trim(),
      active: active.value,
    },
  };

  if (source.value === 'file') {
    if (uploadedFile.value)
      payload.video_signed_id = uploadedFile.value.signedId;
    if (removeSavedFile.value && !uploadedFile.value) {
      payload.remove_video_file = true;
    }
    return payload;
  }

  payload.client_tutorial.video_url = videoUrl.value.trim();
  if (!videoUrl.value.trim()) payload.remove_video_file = true;
  return payload;
};

const submit = async () => {
  if (isInvalid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const payload = buildPayload();
    if (editing.value) {
      await ClientTutorialsAPI.update(editing.value.id, payload);
    } else {
      await ClientTutorialsAPI.create(payload);
    }
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.API.SAVED'));
    closeForm();
    await fetchTutorials();
  } catch (error) {
    aviso(error);
  } finally {
    isSubmitting.value = false;
  }
};

const toggleActive = async tutorial => {
  try {
    await ClientTutorialsAPI.update(tutorial.id, {
      client_tutorial: { active: !tutorial.active },
    });
    await fetchTutorials();
  } catch (error) {
    aviso(error);
  }
};

// Reordenar troca o tutorial com o vizinho e regrava a posição de TODOS pela ordem
// nova (0, 1, 2...): trocar só os dois deixava posições repetidas na lista.
const move = async (index, delta) => {
  if (!tutorials.value[index + delta]) return;

  const reordered = [...tutorials.value];
  [reordered[index], reordered[index + delta]] = [
    reordered[index + delta],
    reordered[index],
  ];

  try {
    await Promise.all(
      reordered
        .map((tutorial, position) => ({ tutorial, position }))
        .filter(({ tutorial, position }) => tutorial.position !== position)
        .map(({ tutorial, position }) =>
          ClientTutorialsAPI.update(tutorial.id, {
            client_tutorial: { position },
          })
        )
    );
    await fetchTutorials();
  } catch (error) {
    aviso(error);
  }
};

const remove = async tutorial => {
  try {
    await ClientTutorialsAPI.delete(tutorial.id);
    useAlert(t('TICKET.SETTINGS.CLIENT_TUTORIALS.API.DELETED'));
    if (editing.value?.id === tutorial.id) closeForm();
    await fetchTutorials();
  } catch (error) {
    aviso(error);
  }
};

const sourceLabel = tutorial => {
  if (tutorial.video_file_url) {
    return t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.FILE', {
      name: tutorial.video_file_name,
    });
  }
  if (tutorial.video_url) return tutorial.video_url;
  return t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.NO_VIDEO');
};

const linkPreview = computed(() => resolveTutorialVideo(videoUrl.value));

onMounted(fetchTutorials);
</script>

<template>
  <SettingsLayout :is-loading="isLoading">
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.CLIENT_TUTORIALS.TITLE')"
        :description="t('TICKET.SETTINGS.CLIENT_TUTORIALS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            size="sm"
            icon="i-lucide-plus"
            :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.ADD')"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4 min-w-0">
        <!-- Criar e editar usam o mesmo formulário. -->
        <form
          v-if="showForm"
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak min-w-0"
          data-testid="tutorial-form"
          @submit.prevent="submit"
        >
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.TITLE') }}
            </span>
            <input
              v-model="title"
              type="text"
              maxlength="200"
              class="w-full mb-0"
              :placeholder="
                t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.TITLE_PLACEHOLDER')
              "
            />
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.DESCRIPTION') }}
            </span>
            <textarea
              v-model="description"
              rows="4"
              class="w-full mb-0"
              :placeholder="
                t(
                  'TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.DESCRIPTION_PLACEHOLDER'
                )
              "
            />
          </label>

          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.SOURCE') }}
            </span>
            <div class="flex flex-wrap gap-4 text-sm text-n-slate-12">
              <label class="flex items-center gap-2 mb-0">
                <input
                  v-model="source"
                  type="radio"
                  value="link"
                  class="mb-0"
                />
                {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.SOURCE_LINK') }}
              </label>
              <label class="flex items-center gap-2 mb-0">
                <input
                  v-model="source"
                  type="radio"
                  value="file"
                  class="mb-0"
                />
                {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.SOURCE_FILE') }}
              </label>
            </div>

            <div v-if="source === 'link'" class="flex flex-col gap-2">
              <input
                v-model="videoUrl"
                type="url"
                class="w-full mb-0"
                data-testid="tutorial-link"
                :placeholder="
                  t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.LINK_PLACEHOLDER')
                "
              />
              <iframe
                v-if="linkPreview?.type === 'iframe'"
                :src="linkPreview.src"
                :title="title"
                class="w-full max-w-xl border-0 rounded-lg aspect-video"
                allowfullscreen
              />
            </div>

            <div v-else class="flex flex-col gap-2">
              <input
                ref="fileInput"
                type="file"
                accept="video/mp4,video/webm"
                class="hidden"
                data-testid="tutorial-file-input"
                @change="onFileChosen"
              />
              <div class="flex flex-wrap items-center gap-2 text-sm">
                <Button
                  type="button"
                  size="sm"
                  slate
                  faded
                  icon="i-lucide-upload"
                  :label="
                    uploadedFile || savedFile
                      ? t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.FILE_REPLACE')
                      : t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.FILE_PICK')
                  "
                  :disabled="isUploading"
                  @click="pickFile"
                />
                <span v-if="isUploading" class="text-n-slate-11">
                  {{
                    t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.UPLOADING', {
                      progress: uploadProgress,
                    })
                  }}
                </span>
                <span
                  v-else-if="uploadedFile || savedFile"
                  class="text-n-slate-12"
                >
                  {{ (uploadedFile || savedFile).name }}
                </span>
                <button
                  v-if="(uploadedFile || savedFile) && !isUploading"
                  type="button"
                  class="p-0 text-n-ruby-11 hover:underline"
                  @click="removeFile"
                >
                  {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.FILE_REMOVE') }}
                </button>
              </div>
              <video
                v-if="savedFile && !uploadedFile"
                :src="savedFile.url"
                class="w-full max-w-xl rounded-lg aspect-video"
                controls
                preload="metadata"
              />
            </div>
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
              :disabled="isInvalid"
              :is-loading="isSubmitting"
              data-testid="tutorial-save"
            />
          </div>
        </form>

        <p
          v-if="!tutorials.length && !showForm"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('TICKET.SETTINGS.CLIENT_TUTORIALS.EMPTY') }}
        </p>

        <ul class="flex flex-col gap-2 p-0 m-0 list-none">
          <li
            v-for="(tutorial, index) in tutorials"
            :key="tutorial.id"
            class="flex flex-wrap items-center gap-3 p-3 border rounded-xl border-n-weak min-w-0"
            :data-testid="`tutorial-row-${tutorial.id}`"
          >
            <div class="flex flex-col min-w-0 grow">
              <span class="font-medium truncate text-n-slate-12">
                {{ tutorial.title }}
              </span>
              <span class="text-xs truncate text-n-slate-11">
                {{ sourceLabel(tutorial) }}
              </span>
            </div>

            <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-11">
              <input
                type="checkbox"
                class="mb-0"
                :checked="tutorial.active"
                :aria-label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.FORM.ACTIVE')"
                @change="toggleActive(tutorial)"
              />
              {{
                tutorial.active
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
                :disabled="index === tutorials.length - 1"
                @click="move(index, 1)"
              />
              <Button
                slate
                faded
                size="sm"
                icon="i-lucide-pencil"
                :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.EDIT')"
                @click="openEdit(tutorial)"
              />
              <ConfirmButton
                :label="t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.DELETE')"
                :confirm-label="
                  t('TICKET.SETTINGS.CLIENT_TUTORIALS.LIST.CONFIRM_DELETE')
                "
                color="slate"
                confirm-color="ruby"
                variant="outline"
                icon="i-lucide-trash-2"
                size="sm"
                @click="remove(tutorial)"
              />
            </div>
          </li>
        </ul>
      </div>
    </template>
  </SettingsLayout>
</template>
