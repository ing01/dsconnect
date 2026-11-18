<script setup>
/**
 * O formulario ABERTO da Central de Ajuda: quem recebeu o link preenche sem login. Pagina isolada
 * (sem menu, sem sessao): o formulario e' identificado so' pelo codigo do link.
 */
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import PublicFormsAPI from 'dashboard/api/publicForms';
import Button from 'dashboard/components-next/button/Button.vue';
import FormFillPanel from 'dashboard/components-next/forms/FormFillPanel.vue';

const route = useRoute();
const { t } = useI18n();

const form = ref(null);
const isLoading = ref(true);
const notFound = ref(false);
const isSubmitting = ref(false);
const errorMessage = ref('');
const successMessage = ref('');
const isDone = ref(false);
const panelKey = ref(0);

const token = computed(() => route.params.token);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await PublicFormsAPI.show(token.value);
    form.value = data;
  } catch (error) {
    notFound.value = true;
  } finally {
    isLoading.value = false;
  }
};

const submit = async payload => {
  isSubmitting.value = true;
  errorMessage.value = '';
  try {
    const { data } = await PublicFormsAPI.submit(token.value, payload);
    successMessage.value =
      data?.success_message || t('FORMS.FILL.SUCCESS_DEFAULT');
    isDone.value = true;
  } catch (error) {
    errorMessage.value =
      error?.response?.status === 429
        ? t('FORMS.FILL.TOO_MANY')
        : error?.response?.data?.message || t('FORMS.FILL.SUBMIT_ERROR');
  } finally {
    isSubmitting.value = false;
  }
};

const sendAnother = () => {
  isDone.value = false;
  panelKey.value += 1;
};

onMounted(load);
</script>

<template>
  <main
    class="min-h-screen p-4 bg-n-background md:p-8"
    data-testid="public-form-page"
  >
    <div class="w-full max-w-2xl mx-auto">
      <p v-if="isLoading" class="text-sm text-n-slate-11">
        {{ t('FORMS.FILL.LOADING') }}
      </p>

      <div
        v-else-if="notFound"
        class="flex flex-col gap-2"
        data-testid="form-not-found"
      >
        <h1 class="m-0 text-xl font-semibold text-n-slate-12">
          {{ t('FORMS.FILL.NOT_FOUND_TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('FORMS.FILL.NOT_FOUND_TEXT') }}
        </p>
      </div>

      <div
        v-else-if="isDone"
        class="flex flex-col gap-3 p-6 border rounded-xl border-n-weak bg-n-solid-1"
        data-testid="form-done"
      >
        <h1 class="m-0 text-xl font-semibold text-n-slate-12">
          {{ t('FORMS.FILL.SUCCESS_TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">{{ successMessage }}</p>
        <div>
          <Button
            faded
            slate
            :label="t('FORMS.FILL.SEND_ANOTHER')"
            @click="sendAnother"
          />
        </div>
      </div>

      <div v-else class="p-6 border rounded-xl border-n-weak bg-n-solid-1">
        <FormFillPanel
          :key="panelKey"
          :form="form"
          ask-respondent
          :is-submitting="isSubmitting"
          :error-message="errorMessage"
          @submit="submit"
        />
      </div>
    </div>
  </main>
</template>
