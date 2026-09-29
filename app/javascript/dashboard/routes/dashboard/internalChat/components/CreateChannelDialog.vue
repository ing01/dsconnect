<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
});

const emit = defineEmits(['create']);

const { t } = useI18n();

const dialogRef = ref(null);
const name = ref('');
const description = ref('');
// Os mesmos valores do enum `ChatChannel#visibility`. Com 'public'/'private' o
// servidor recusa a criacao inteira com 'is not a valid visibility'.
const PUBLIC = 'public_channel';
const PRIVATE = 'private_channel';

const visibility = ref(PUBLIC);
const memberIds = ref([]);
// Canal fixo sobe para o topo da barra lateral: e onde mora o que todos precisam
// ver, e ordenar por ultima mensagem o empurrava para baixo sozinho.
const pinned = ref(false);
// `moderators` separa ler de escrever: todos leem, so os autorizados escrevem. O
// administrador escreve sempre, e por isso nao entra nesta lista.
const EVERYONE = 'everyone';
const MODERATORS = 'moderators';
const postingPolicy = ref(EVERYONE);
const moderatorIds = ref([]);

const isValid = computed(() => !!name.value.trim());

const selectableUsers = computed(() =>
  props.users.filter(user => user.id !== props.currentUserId)
);

const open = () => {
  name.value = '';
  description.value = '';
  visibility.value = PUBLIC;
  memberIds.value = [];
  pinned.value = false;
  postingPolicy.value = EVERYONE;
  moderatorIds.value = [];
  dialogRef.value?.open();
};

const toggleMember = id => {
  const index = memberIds.value.indexOf(id);
  if (index === -1) memberIds.value.push(id);
  else memberIds.value.splice(index, 1);
  // Quem sai do canal nao pode continuar na lista de quem escreve nele.
  if (index !== -1) {
    moderatorIds.value = moderatorIds.value.filter(item => item !== id);
  }
};

const toggleModerator = id => {
  const index = moderatorIds.value.indexOf(id);
  if (index === -1) moderatorIds.value.push(id);
  else moderatorIds.value.splice(index, 1);
};

// Só quem está no canal pode ser autorizado a escrever nele.
const membrosEscolhidos = computed(() =>
  selectableUsers.value.filter(user => memberIds.value.includes(user.id))
);

const submit = () => {
  if (!isValid.value) return;

  emit('create', {
    // O nome do canal segue a convenção de handle: minúsculo e sem espaço.
    name: name.value.trim().toLowerCase().replace(/\s+/g, '-'),
    description: description.value.trim(),
    visibility: visibility.value,
    memberIds: [...new Set([props.currentUserId, ...memberIds.value])],
    pinned: pinned.value,
    postingPolicy: postingPolicy.value,
    // Só faz sentido enviar quando a escrita é restrita; com `everyone` a lista
    // não tem efeito nenhum e mandá-la sugeriria o contrário.
    moderatorIds:
      postingPolicy.value === MODERATORS ? [...moderatorIds.value] : [],
  });
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('INTERNAL_CHAT.CREATE_CHANNEL.TITLE')"
    :confirm-button-label="t('INTERNAL_CHAT.CREATE_CHANNEL.CONFIRM')"
    :disable-confirm-button="!isValid"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.NAME') }}
          <span class="text-n-ruby-11">*</span>
        </span>
        <input
          v-model="name"
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
          v-model="description"
          type="text"
          class="w-full mb-0"
          :placeholder="
            t('INTERNAL_CHAT.CREATE_CHANNEL.DESCRIPTION_PLACEHOLDER')
          "
        />
      </label>

      <fieldset class="flex flex-col gap-1.5 p-0 m-0 border-0">
        <legend class="p-0 mb-1 text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.VISIBILITY') }}
        </legend>
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="visibility"
            type="radio"
            :value="PUBLIC"
            class="m-0"
          />
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PUBLIC') }}
        </label>
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="visibility"
            type="radio"
            :value="PRIVATE"
            class="m-0"
          />
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.PRIVATE') }}
        </label>
      </fieldset>

      <div class="flex flex-col gap-1.5">
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
              memberIds.includes(user.id)
                ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                : 'border-n-weak text-n-slate-11 hover:border-n-slate-7'
            "
            @click="toggleMember(user.id)"
          >
            {{ user.name }}
          </button>
        </div>
      </div>

      <!-- Canal fixo e canal de aviso ficam depois dos membros de proposito: a
           lista de quem escreve so faz sentido depois de saber quem esta no
           canal. -->
      <label class="flex items-start gap-2 cursor-pointer">
        <input v-model="pinned" type="checkbox" class="m-0 mt-0.5" />
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
            v-model="postingPolicy"
            type="radio"
            :value="EVERYONE"
            class="m-0"
          />
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.POST_EVERYONE') }}
        </label>
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="postingPolicy"
            type="radio"
            :value="MODERATORS"
            class="m-0"
          />
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.POST_MODERATORS') }}
        </label>
      </fieldset>

      <div
        v-if="postingPolicy === MODERATORS"
        class="flex flex-col gap-1.5 min-w-0"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.AUTHORIZED') }}
        </span>
        <!-- O administrador nao aparece aqui: ele escreve sempre, e oferecer a
             marca sugeriria que sem ela ficaria de fora. -->
        <p class="m-0 text-xs text-n-slate-10">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.AUTHORIZED_HINT') }}
        </p>
        <p v-if="!membrosEscolhidos.length" class="m-0 text-xs text-n-slate-10">
          {{ t('INTERNAL_CHAT.CREATE_CHANNEL.AUTHORIZED_EMPTY') }}
        </p>
        <div v-else class="flex flex-wrap gap-1.5">
          <button
            v-for="user in membrosEscolhidos"
            :key="user.id"
            type="button"
            class="px-2 py-1 text-xs border rounded-full"
            :class="
              moderatorIds.includes(user.id)
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
  </Dialog>
</template>
