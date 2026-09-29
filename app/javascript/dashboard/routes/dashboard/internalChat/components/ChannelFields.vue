<script setup>
/**
 * Os campos de um canal, usados por criar E editar.
 *
 * Vive num componente proprio porque os dois diálogos pedem exatamente as mesmas
 * coisas: duplicar a marcação faria a próxima opção nova entrar só num dos dois -
 * e ninguém descobriria qual.
 *
 * O que difere é a participação: ela é definida na criação e não muda por aqui
 * (mudar quem está no canal é outro pedido, com outro endpoint). Em `editing`, a
 * lista de membros deixa de ser escolhível e passa a ser só a base de quem pode
 * ser autorizado a escrever.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  PUBLIC,
  PRIVATE,
  EVERYONE,
  MODERATORS,
} from '../helpers/channelOptions';

const props = defineProps({
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
  // Canal que já existe: a participação não se mexe aqui.
  editing: { type: Boolean, default: false },
});

const form = defineModel({ type: Object, required: true });

const { t } = useI18n();

const selectableUsers = computed(() =>
  props.users.filter(user => user.id !== props.currentUserId)
);

const toggleMember = id => {
  const index = form.value.memberIds.indexOf(id);
  if (index === -1) {
    form.value.memberIds.push(id);
    return;
  }

  form.value.memberIds.splice(index, 1);
  // Quem sai do canal não pode continuar na lista de quem escreve nele.
  form.value.moderatorIds = form.value.moderatorIds.filter(item => item !== id);
};

const toggleModerator = id => {
  const index = form.value.moderatorIds.indexOf(id);
  if (index === -1) form.value.moderatorIds.push(id);
  else form.value.moderatorIds.splice(index, 1);
};

// Só quem está no canal pode ser autorizado a escrever nele.
const membrosDoCanal = computed(() =>
  selectableUsers.value.filter(user => form.value.memberIds.includes(user.id))
);
</script>

<template>
  <div class="flex flex-col gap-4 min-w-0">
    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.NAME') }}
        <span class="text-n-ruby-11">*</span>
      </span>
      <input
        v-model="form.name"
        type="text"
        class="w-full mb-0"
        :placeholder="t('INTERNAL_CHAT.CREATE_CHANNEL.NAME_PLACEHOLDER')"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.DESCRIPTION') }}
      </span>
      <input
        v-model="form.description"
        type="text"
        class="w-full mb-0"
        :placeholder="t('INTERNAL_CHAT.CREATE_CHANNEL.DESCRIPTION_PLACEHOLDER')"
      />
    </label>

    <fieldset class="flex flex-col gap-1.5 p-0 m-0 border-0">
      <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.VISIBILITY') }}
      </legend>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <input
          v-model="form.visibility"
          type="radio"
          :value="PUBLIC"
          class="m-0"
        />
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PUBLIC') }}
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <input
          v-model="form.visibility"
          type="radio"
          :value="PRIVATE"
          class="m-0"
        />
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PRIVATE') }}
      </label>
    </fieldset>

    <!-- Na edição a participação não aparece: mudar quem está no canal é outro
         pedido, com outro endpoint. Aqui ela só sustenta a lista de baixo. -->
    <div v-if="!editing" class="flex flex-col gap-1.5">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.MEMBERS') }}
      </span>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="user in selectableUsers"
          :key="user.id"
          type="button"
          class="px-2 py-1 text-xs border rounded-full"
          :class="
            form.memberIds.includes(user.id)
              ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
              : 'border-n-weak text-n-slate-11 hover:border-n-slate-7'
          "
          @click="toggleMember(user.id)"
        >
          {{ user.name }}
        </button>
      </div>
    </div>

    <!-- Canal fixo e canal de aviso ficam depois dos membros de propósito: a
         lista de quem escreve só faz sentido depois de saber quem está no
         canal. -->
    <label class="flex items-start gap-2 cursor-pointer">
      <input v-model="form.pinned" type="checkbox" class="m-0 mt-0.5" />
      <span class="flex flex-col gap-0.5 min-w-0">
        <span class="text-sm text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PINNED') }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PINNED_HINT') }}
        </span>
      </span>
    </label>

    <fieldset class="flex flex-col gap-1.5 p-0 m-0 border-0">
      <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.WHO_CAN_POST') }}
      </legend>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <input
          v-model="form.postingPolicy"
          type="radio"
          :value="EVERYONE"
          class="m-0"
        />
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.POST_EVERYONE') }}
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <input
          v-model="form.postingPolicy"
          type="radio"
          :value="MODERATORS"
          class="m-0"
        />
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.POST_MODERATORS') }}
      </label>
    </fieldset>

    <div
      v-if="form.postingPolicy === MODERATORS"
      class="flex flex-col gap-1.5 min-w-0"
    >
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.AUTHORIZED') }}
      </span>
      <!-- O administrador não aparece aqui: ele escreve sempre, e oferecer a
           marca sugeriria que sem ela ficaria de fora. -->
      <p class="m-0 text-xs text-n-slate-10">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.AUTHORIZED_HINT') }}
      </p>
      <p v-if="!membrosDoCanal.length" class="m-0 text-xs text-n-slate-10">
        {{ t('INTERNAL_CHAT.CREATE_CHANNEL.AUTHORIZED_EMPTY') }}
      </p>
      <div v-else class="flex flex-wrap gap-1.5">
        <button
          v-for="user in membrosDoCanal"
          :key="user.id"
          type="button"
          class="px-2 py-1 text-xs border rounded-full"
          :class="
            form.moderatorIds.includes(user.id)
              ? 'border-n-teal-8 bg-n-teal-3 text-n-teal-11'
              : 'border-n-weak text-n-slate-11 hover:border-n-slate-7'
          "
          @click="toggleModerator(user.id)"
        >
          {{ user.name }}
        </button>
      </div>
    </div>
  </div>
</template>
