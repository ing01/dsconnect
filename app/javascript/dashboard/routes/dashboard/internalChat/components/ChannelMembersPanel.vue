<script setup>
/**
 * Quem está no canal, numa faixa lateral.
 *
 * O botão de membros no cabeçalho mostrava só a contagem e não abria nada. A
 * lista responde a pergunta que a contagem levanta: quem são as seis pessoas.
 *
 * Num canal de aviso ela responde a uma segunda: quem, dessas, pode escrever.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { presenceDotClass, presenceLabelKey } from '../helpers/presence';

const props = defineProps({
  room: { type: Object, required: true },
  users: { type: Array, default: () => [] },
});

defineEmits(['close']);

const { t } = useI18n();

// A ordem é a do diretório, não a de entrada no canal: é assim que as pessoas
// procuram um nome numa lista.
const members = computed(() =>
  props.users
    .filter(user => (props.room.memberIds || []).includes(user.id))
    .slice()
    .sort((a, b) => (a.name || '').localeCompare(b.name || ''))
);

// Só faz sentido distinguir quem escreve quando NÃO é todo mundo.
const mostraQuemEscreve = computed(
  () => props.room.postingPolicy === 'moderators'
);

const podeEscrever = user => (props.room.moderatorIds || []).includes(user.id);
</script>

<template>
  <aside
    class="flex flex-col flex-shrink-0 w-64 h-full min-h-0 border-s border-n-weak bg-n-solid-1"
  >
    <header
      class="flex items-center justify-between flex-shrink-0 gap-2 px-3 py-2.5 border-b border-n-weak"
    >
      <h3 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('INTERNAL_CHAT.MEMBERS_PANEL.TITLE', { count: members.length }) }}
      </h3>
      <button
        type="button"
        class="p-1 rounded text-n-slate-11 hover:bg-n-alpha-2"
        :title="t('INTERNAL_CHAT.MEMBERS_PANEL.CLOSE')"
        @click="$emit('close')"
      >
        <Icon icon="i-lucide-x" class="size-4" />
      </button>
    </header>

    <p
      v-if="mostraQuemEscreve"
      class="flex items-start gap-2 px-3 py-2 m-0 text-xs border-b text-n-slate-10 border-n-weak"
    >
      <Icon icon="i-lucide-lock" class="flex-shrink-0 mt-px size-3.5" />
      {{ t('INTERNAL_CHAT.MEMBERS_PANEL.RESTRICTED_HINT') }}
    </p>

    <ul class="flex flex-col gap-0.5 p-2 m-0 overflow-y-auto grow min-h-0">
      <li
        v-for="user in members"
        :key="user.id"
        class="flex items-center gap-2.5 px-2 py-1.5 rounded-md min-w-0"
      >
        <span class="relative flex-shrink-0">
          <Avatar :name="user.name || '?'" :src="user.thumbnail" :size="28" />
          <span
            class="absolute bottom-0 size-2.5 rounded-full border-2 border-n-solid-1 end-0"
            :class="presenceDotClass(user.status)"
          />
        </span>
        <span class="flex flex-col min-w-0 grow">
          <span class="text-sm truncate text-n-slate-12">
            {{ user.name }}
          </span>
          <span class="text-xs truncate text-n-slate-10">
            {{ t(presenceLabelKey(user.status)) }}
          </span>
        </span>
        <!-- A marca aparece só em canal restrito: num canal comum, todos
             escrevem, e marcar todos não distinguiria ninguém. -->
        <Icon
          v-if="mostraQuemEscreve && podeEscrever(user)"
          icon="i-lucide-pencil"
          class="flex-shrink-0 size-3.5 text-n-teal-11"
          :title="t('INTERNAL_CHAT.MEMBERS_PANEL.CAN_POST')"
        />
      </li>

      <li
        v-if="!members.length"
        class="px-2 py-6 text-sm text-center text-n-slate-10"
      >
        {{ t('INTERNAL_CHAT.MEMBERS_PANEL.EMPTY') }}
      </li>
    </ul>
  </aside>
</template>
