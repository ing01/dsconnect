<script setup>
/**
 * Um formulario publicado na Central de Ajuda, preenchido pelo cliente LOGADO na Area do Cliente.
 * A pessoa chega aqui pelo botao "Preencher formulario" do artigo; sem sessao, a guarda de rotas a
 * leva ao login e a traz de volta para este endereco.
 */
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import ClientAreaAPI from 'dashboard/api/clientArea';
import Button from 'dashboard/components-next/button/Button.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';
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
// Muda a cada novo envio: o painel recomeca vazio sem recarregar a pagina.
const panelKey = ref(0);

const formId = computed(() => route.params.formId);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClientAreaAPI.form(formId.value);
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
    const { data } = await ClientAreaAPI.submitForm(form.value.id, payload);
    successMessage.value =
      data?.success_message || t('FORMS.FILL.SUCCESS_DEFAULT');
    isDone.value = true;
  } catch (error) {
    errorMessage.value =
      error?.response?.data?.message || t('FORMS.FILL.SUBMIT_ERROR');
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
  <div class="w-full h-full p-4 overflow-y-auto md:p-8">
    <div class="w-full max-w-2xl mx-auto">
      <PageLoader v-if="isLoading" />

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
          :is-submitting="isSubmitting"
          :error-message="errorMessage"
          @submit="submit"
        />
      </div>
    </div>
  </div>
</template>
