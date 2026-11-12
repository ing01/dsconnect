<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import articlesAPI from 'dashboard/api/helpCenter/articles';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import {
  MAX_IMAGE_FILE_BYTES,
  MAX_MARKDOWN_FILE_BYTES,
  imageKey,
  isImageFile,
  isMarkdownFile,
  listLocalImages,
  parseMarkdownArticle,
  replaceLocalImages,
} from 'dashboard/helper/markdownArticleImport';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  categories: { type: Array, default: () => [] },
});

const emit = defineEmits(['imported']);

const { t } = useI18n();
const route = useRoute();
const currentUserId = useMapGetter('getCurrentUserID');

const dialogRef = ref(null);
const fileInput = ref(null);
// Cada item: { name, title, content, error, status } - status: ready | done | failed.
const items = ref([]);
// Imagens escolhidas junto com os .md, pela chave (nome do arquivo em minusculas).
const images = ref({});
const categoryId = ref('');
const isImporting = ref(false);

const categoryOptions = computed(() =>
  props.categories.map(category => ({
    value: category.id,
    label: category.name,
  }))
);

const readyItems = computed(() =>
  items.value.filter(item => item.status === 'ready')
);
const hasFailures = computed(() =>
  items.value.some(item => item.status === 'failed')
);
const imageCount = computed(() => Object.keys(images.value).length);
const isConfirmDisabled = computed(
  () => !readyItems.value.length || isImporting.value
);

const open = () => {
  items.value = [];
  images.value = {};
  // A categoria que a pessoa estava olhando ja vem escolhida.
  const active = props.categories.find(
    category => category.slug === route.params.categorySlug
  );
  categoryId.value = active ? active.id : '';
  dialogRef.value?.open();
};

const pickFiles = () => fileInput.value?.click();

const readFile = file =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error);
    reader.readAsText(file, 'utf-8');
  });

const describeFile = async file => {
  if (!isMarkdownFile(file.name)) {
    return {
      name: file.name,
      status: 'failed',
      error: t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.NOT_MARKDOWN'),
    };
  }
  if (file.size > MAX_MARKDOWN_FILE_BYTES) {
    return {
      name: file.name,
      status: 'failed',
      error: t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.TOO_LARGE'),
    };
  }
  try {
    const { title, content } = parseMarkdownArticle(
      await readFile(file),
      file.name
    );
    return {
      name: file.name,
      title,
      content,
      status: 'ready',
      imageKeys: listLocalImages(content),
    };
  } catch (error) {
    return {
      name: file.name,
      status: 'failed',
      error: t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.READ_ERROR'),
    };
  }
};

const onFilesChosen = async event => {
  const files = Array.from(event.target.files || []);
  // Permite escolher o mesmo arquivo de novo depois de corrigi-lo.
  if (fileInput.value) fileInput.value.value = '';

  const pictures = files.filter(file => isImageFile(file.name));
  const others = files.filter(file => !isImageFile(file.name));
  const tooBig = pictures.filter(file => file.size > MAX_IMAGE_FILE_BYTES);
  const nextImages = { ...images.value };
  pictures
    .filter(file => file.size <= MAX_IMAGE_FILE_BYTES)
    .forEach(file => {
      nextImages[imageKey(file.name)] = file;
    });
  images.value = nextImages;

  const described = [
    ...(await Promise.all(others.map(describeFile))),
    ...tooBig.map(file => ({
      name: file.name,
      status: 'failed',
      error: t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.IMAGE_TOO_LARGE'),
    })),
  ];
  items.value = [
    ...items.value.filter(item => item.status !== 'failed'),
    ...described,
  ];
};

// Imagens que o texto usa e que ainda nao foram escolhidas.
const missingImages = item =>
  (item.imageKeys || []).filter(key => !images.value[key]);

const removeItem = index => {
  items.value = items.value.filter((_, position) => position !== index);
};

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.CREATE_ERROR');

// Um por vez e na ordem escolhida: a Central ordena por data de atualizacao, e assim o
// primeiro arquivo fica como o mais antigo. Um que falha nao impede os seguintes.
// Cada imagem sobe uma vez so, mesmo usada em varios manuais.
const uploads = {};
const uploadImage = key => {
  if (!uploads[key]) {
    uploads[key] = uploadFile(images.value[key]).then(
      ({ fileUrl }) => fileUrl,
      error => {
        delete uploads[key];
        throw Object.assign(error || {}, { imageKey: key });
      }
    );
  }
  return uploads[key];
};

// Sobe as imagens do manual e devolve o texto com os caminhos trocados pelos enderecos.
const contentWithImages = async item => {
  const urls = {};
  await Promise.all(
    (item.imageKeys || [])
      .filter(key => images.value[key])
      .map(async key => {
        urls[key] = await uploadImage(key);
      })
  );
  return replaceLocalImages(item.content, key => urls[key]);
};

const importAll = async () => {
  if (isConfirmDisabled.value) return;

  isImporting.value = true;
  let created = 0;
  try {
    await readyItems.value.reduce(async (previous, item) => {
      await previous;
      try {
        const content = await contentWithImages(item);
        await articlesAPI.createArticle({
          portalSlug: route.params.portalSlug,
          articleObj: {
            title: item.title,
            content,
            authorId: currentUserId.value,
            categoryId: categoryId.value || undefined,
            locale: route.params.locale,
          },
        });
        item.status = 'done';
        created += 1;
      } catch (error) {
        item.status = 'failed';
        item.error = error?.imageKey
          ? t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.IMAGE_UPLOAD_ERROR', {
              name: error.imageKey,
            })
          : errorMessage(error);
      }
    }, Promise.resolve());
  } finally {
    isImporting.value = false;
  }

  if (created) {
    useAlert(t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.SUCCESS', created));
    emit('imported');
  }
  if (!hasFailures.value) dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="lg"
    overflow-y-auto
    :title="t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.TITLE')"
    :description="t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.DESCRIPTION')"
    :confirm-button-label="
      t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.CONFIRM', readyItems.length)
    "
    :disable-confirm-button="isConfirmDisabled"
    :is-loading="isImporting"
    @confirm="importAll"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <div class="flex flex-col gap-2">
        <input
          ref="fileInput"
          type="file"
          class="hidden"
          multiple
          accept=".md,.markdown,.png,.jpg,.jpeg,.gif,.webp"
          @change="onFilesChosen"
        />
        <Button
          variant="faded"
          color="slate"
          icon="i-lucide-file-up"
          :label="t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.CHOOSE')"
          :disabled="isImporting"
          @click="pickFiles"
        />
        <span v-if="imageCount" class="text-xs text-n-slate-10">
          {{
            t(
              'HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.IMAGES_SELECTED',
              imageCount
            )
          }}
        </span>
      </div>

      <ul v-if="items.length" class="flex flex-col gap-1.5 p-0 m-0 list-none">
        <li
          v-for="(item, index) in items"
          :key="`${item.name}-${index}`"
          class="flex items-start gap-2 px-3 py-2 text-sm rounded-lg bg-n-solid-2 min-w-0"
        >
          <Icon
            :icon="
              item.status === 'done'
                ? 'i-lucide-circle-check'
                : item.status === 'failed'
                  ? 'i-lucide-circle-alert'
                  : 'i-lucide-file-text'
            "
            class="flex-shrink-0 mt-0.5 size-4"
            :class="{
              'text-n-teal-11': item.status === 'done',
              'text-n-ruby-11': item.status === 'failed',
              'text-n-slate-11': item.status === 'ready',
            }"
          />
          <div class="flex flex-col min-w-0 grow">
            <span class="truncate text-n-slate-12">
              {{ item.title || item.name }}
            </span>
            <span class="text-xs truncate text-n-slate-10">{{
              item.name
            }}</span>
            <span v-if="item.error" class="text-xs text-n-ruby-11">
              {{ item.error }}
            </span>
            <span
              v-if="item.status === 'ready' && missingImages(item).length"
              class="text-xs text-n-amber-11"
            >
              {{
                t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.IMAGE_MISSING', {
                  names: missingImages(item).join(', '),
                })
              }}
            </span>
          </div>
          <button
            v-if="item.status !== 'done' && !isImporting"
            type="button"
            class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
            :title="t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.REMOVE')"
            @click="removeItem(index)"
          >
            <Icon icon="i-lucide-x" class="size-3.5" />
          </button>
        </li>
      </ul>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.CATEGORY_LABEL') }}
          <span class="font-normal text-n-slate-10">
            {{ t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.OPTIONAL') }}
          </span>
        </span>
        <ComboBox
          v-model="categoryId"
          :options="categoryOptions"
          :placeholder="
            t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.CATEGORY_PLACEHOLDER')
          "
          class="[&>div>button:not(.focused)]:!outline-n-slate-5 [&>div>button:not(.focused)]:dark:!outline-n-slate-5"
        />
      </div>

      <p class="m-0 text-xs text-n-slate-10">
        {{ t('HELP_CENTER.ARTICLES_PAGE.IMPORT_MARKDOWN.NOTE') }}
      </p>
    </div>
  </Dialog>
</template>
