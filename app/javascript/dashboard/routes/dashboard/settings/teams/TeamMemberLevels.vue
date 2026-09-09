<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  teamId: { type: [Number, String], required: true },
  members: { type: Array, default: () => [] },
});

const { t } = useI18n();
const store = useStore();

// Os niveis que existem. Espelha AssigneeLeveled::LEVELS no servidor: um Nivel
// 3 no futuro entra aqui e nos dois lugares do backend, sem coluna nova.
const LEVELS = [1, 2];

const isSaving = ref(false);
// Rascunho local: a tela so grava quando a pessoa confirma, entao marcar e
// desmarcar nao dispara requisicao a cada clique.
const draft = ref({});

// Recarrega o rascunho sempre que a lista muda - inclusive na primeira carga,
// quando ela chega vazia e so depois e preenchida.
watch(
  () => props.members,
  members => {
    draft.value = Object.fromEntries(
      members.map(member => [member.id, [...(member.levels || [])]])
    );
  },
  { immediate: true, deep: true }
);

const hasMembers = computed(() => props.members.length > 0);

const isChecked = (userId, level) => (draft.value[userId] || []).includes(level);

const toggle = (userId, level) => {
  const current = draft.value[userId] || [];
  draft.value = {
    ...draft.value,
    [userId]: current.includes(level)
      ? current.filter(item => item !== level)
      : [...current, level].sort(),
  };
};

const save = async () => {
  if (isSaving.value) return;

  isSaving.value = true;
  try {
    await store.dispatch('teamMembers/updateLevels', {
      teamId: props.teamId,
      levels: draft.value,
    });
    useAlert(t('TEAMS_SETTINGS.LEVELS.SAVED'));
  } catch (error) {
    useAlert(t('TEAMS_SETTINGS.LEVELS.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <section class="flex flex-col gap-3">
    <div>
      <h3 class="text-base font-medium text-n-slate-12">
        {{ t('TEAMS_SETTINGS.LEVELS.TITLE') }}
      </h3>
      <p class="text-sm text-n-slate-11">
        {{ t('TEAMS_SETTINGS.LEVELS.DESC') }}
      </p>
    </div>

    <p v-if="!hasMembers" class="text-sm text-n-slate-10">
      {{ t('TEAMS_SETTINGS.LEVELS.NO_MEMBERS') }}
    </p>

    <div v-else class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-xs text-n-slate-10">
            <th class="py-2 pr-3 font-medium">
              {{ t('TEAMS_SETTINGS.LEVELS.MEMBER') }}
            </th>
            <th
              v-for="level in LEVELS"
              :key="level"
              class="py-2 pr-3 font-medium"
            >
              {{ t('TEAMS_SETTINGS.LEVELS.LEVEL', { level }) }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="member in members"
            :key="member.id"
            class="border-t border-n-weak"
          >
            <td class="py-2 pr-3 text-n-slate-12">{{ member.name }}</td>
            <td v-for="level in LEVELS" :key="level" class="py-2 pr-3">
              <input
                type="checkbox"
                class="m-0"
                :checked="isChecked(member.id, level)"
                :aria-label="
                  t('TEAMS_SETTINGS.LEVELS.LEVEL', { level }) + ' - ' + member.name
                "
                @change="toggle(member.id, level)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="hasMembers" class="flex justify-end">
      <Button
        type="button"
        :label="t('TEAMS_SETTINGS.LEVELS.SAVE')"
        :is-loading="isSaving"
        @click="save"
      />
    </div>
  </section>
</template>
