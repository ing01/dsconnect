<script setup>
/**
 * Liga e desliga o acesso de um contato à Área do Cliente.
 *
 * Fica dentro de Empresas → Contatos porque é ali que a relação existe, e o
 * acesso é um atributo do contato - não há cadastro de cliente em outro lugar.
 */
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contact: { type: Object, required: true },
});

const emit = defineEmits(['saved', 'close']);

const { t } = useI18n();

const enabled = ref(false);
const password = ref('');
const visibility = ref('own');
const isSaving = ref(false);

// Sem e-mail não há login: o e-mail do contato É a credencial.
const hasEmail = computed(() => Boolean(props.contact.email));
const jaTemSenha = computed(() => Boolean(props.contact.clientAccessReady));

// Na primeira habilitação a senha é obrigatória; depois ela só é enviada se a
// equipe quiser trocá-la.
const precisaDeSenha = computed(() => enabled.value && !jaTemSenha.value);
const podeSalvar = computed(() => {
  if (!enabled.value) return true;
  if (!hasEmail.value) return false;
  return precisaDeSenha.value ? password.value.length >= 8 : true;
});

watch(
  () => props.contact,
  contato => {
    enabled.value = Boolean(contato.clientAccessEnabled);
    visibility.value = contato.clientTicketsVisibility || 'own';
    password.value = '';
  },
  { immediate: true, deep: true }
);

const salvar = async () => {
  if (!podeSalvar.value || isSaving.value) return;

  isSaving.value = true;
  try {
    const { data } = await ContactAPI.setClientAccess(props.contact.id, {
      enabled: enabled.value,
      password: password.value || undefined,
      ticketsVisibility: visibility.value,
    });
    useAlert(
      t(
        enabled.value
          ? 'COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.ENABLED'
          : 'COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.DISABLED'
      )
    );
    emit('saved', data);
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.TITLE')"
      :header-content="contact.email || contact.name"
    />

    <div class="flex flex-col gap-4 px-8 pt-2 pb-8">
      <p v-if="!hasEmail" class="m-0 text-sm text-n-ruby-11">
        {{ t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.NO_EMAIL') }}
      </p>

      <label class="flex items-start gap-2">
        <input
          v-model="enabled"
          type="checkbox"
          class="mt-1"
          :disabled="!hasEmail"
        />
        <span class="flex flex-col">
          <span class="text-sm text-n-slate-12">
            {{ t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.ENABLE_LABEL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.ENABLE_HELP') }}
          </span>
        </span>
      </label>

      <template v-if="enabled && hasEmail">
        <label class="flex flex-col gap-1">
          <span class="text-sm text-n-slate-11">
            {{
              jaTemSenha
                ? t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.NEW_PASSWORD')
                : t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.PASSWORD')
            }}
          </span>
          <input
            v-model="password"
            type="password"
            autocomplete="new-password"
            class="h-10 px-2.5 mb-0 text-sm border rounded-lg bg-n-solid-1 border-n-weak text-n-slate-12"
            :placeholder="
              jaTemSenha
                ? t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.KEEP_PASSWORD')
                : t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.PASSWORD_HINT')
            "
          />
          <span class="text-xs text-n-slate-10">
            {{ t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.PASSWORD_HINT') }}
          </span>
        </label>

        <div class="flex flex-col gap-1">
          <span class="text-sm text-n-slate-11">
            {{ t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.VISIBILITY') }}
          </span>
          <label
            v-for="opcao in ['own', 'company']"
            :key="opcao"
            class="flex items-start gap-2"
          >
            <input
              v-model="visibility"
              type="radio"
              :value="opcao"
              class="mt-1"
            />
            <span class="text-sm text-n-slate-12">
              {{
                t(
                  `COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.VISIBILITY_${opcao.toUpperCase()}`
                )
              }}
            </span>
          </label>
        </div>
      </template>

      <div class="flex justify-end gap-2">
        <Button
          faded
          slate
          :label="t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.CANCEL')"
          @click="emit('close')"
        />
        <Button
          :label="t('COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.CONFIRM')"
          :disabled="!podeSalvar"
          :is-loading="isSaving"
          @click="salvar"
        />
      </div>
    </div>
  </div>
</template>
