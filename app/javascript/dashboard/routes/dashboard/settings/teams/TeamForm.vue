<script>
import { mapGetters } from 'vuex';
import validations from './helpers/validations';
import FormInput from 'v3/components/Form/Input.vue';
import { reactive, ref, defineAsyncComponent } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { OnClickOutside } from '@vueuse/components';

import NextButton from 'dashboard/components-next/button/Button.vue';
import EmojiIcon from 'dashboard/components-next/emoji-icon-picker/EmojiIcon.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

export default {
  components: {
    NextButton,
    FormInput,
    OnClickOutside,
    EmojiIcon,
    Icon,
    EmojiIconPicker,
  },
  props: {
    onSubmit: {
      type: Function,
      default: () => {},
    },
    submitInProgress: {
      type: Boolean,
      default: false,
    },
    formData: {
      type: Object,
      default: () => {},
    },
    submitButtonText: {
      type: String,
      default: '',
    },
  },
  setup(props) {
    const formData = props.formData || {};
    const {
      description = '',
      name: title = '',
      allow_auto_assign: allowAutoAssign = true,
      icon = '',
      icon_color: iconColor = '',
      active = true,
      manager_id: managerId = null,
      assignee_levels_enabled: assigneeLevelsEnabled = false,
      assignee_levels_count: assigneeLevelsCount = 2,
      handles_conversations: handlesConversations = true,
      handles_projects: handlesProjects = true,
    } = formData;

    const state = reactive({
      description,
      title,
      allowAutoAssign,
      assigneeLevelsEnabled,
      assigneeLevelsCount,
      icon,
      iconColor,
      active,
      managerId,
      handlesConversations,
      handlesProjects,
    });

    const isIconPickerOpen = ref(false);

    const rules = validations;
    const v$ = useVuelidate(rules, state);
    return { state, v$, isIconPickerOpen };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    // Do minimo ao teto que o servidor sabe guardar (AssigneeLeveled::MAX_LEVEL):
    // uma Mesa "com niveis" de um nivel so seria a Mesa sem niveis.
    LEVEL_COUNTS() {
      return [2, 3, 4, 5];
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
  methods: {
    onSelectIcon({ type, value, color }) {
      this.state.icon = value;
      this.state.iconColor = type === 'icon' ? color : '';
      this.isIconPickerOpen = false;
    },
    onColorChange(color) {
      this.state.iconColor = color;
    },
    onRemoveIcon() {
      this.state.icon = '';
      this.state.iconColor = '';
      this.isIconPickerOpen = false;
    },
    handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }
      this.onSubmit({
        description: this.state.description,
        name: this.state.title,
        allow_auto_assign: this.state.allowAutoAssign,
        icon: this.state.icon,
        icon_color: this.state.iconColor,
        active: this.state.active,
        manager_id: this.state.managerId || null,
        assignee_levels_enabled: this.state.assigneeLevelsEnabled,
        assignee_levels_count: Number(this.state.assigneeLevelsCount),
        handles_conversations: this.state.handlesConversations,
        handles_projects: this.state.handlesProjects,
      });
    },
  },
};
</script>

<template>
  <div class="flex-shrink-0 w-full">
    <form class="mx-0 grid gap-4" @submit.prevent="handleSubmit">
      <div class="relative">
        <FormInput
          v-model="state.title"
          class="!ps-12"
          name="title"
          spacing="compact"
          :label="$t('TEAMS_SETTINGS.FORM.NAME.LABEL')"
          :placeholder="$t('TEAMS_SETTINGS.FORM.NAME.PLACEHOLDER')"
          :has-error="v$.title.$error"
          :error-message="v$.title.$error ? v$.title.$errors[0].$message : ''"
          @blur="v$.title.$touch"
        />
        <OnClickOutside
          class="absolute top-[1.75rem] start-0"
          @trigger="isIconPickerOpen = false"
        >
          <NextButton
            type="button"
            variant="ghost"
            color="slate"
            class="text-lg !size-[2.5rem] !p-0 ltr:!rounded-r-none rtl:!rounded-l-none"
            @click="isIconPickerOpen = !isIconPickerOpen"
          >
            <EmojiIcon
              v-if="state.icon"
              :value="state.icon"
              :color="state.iconColor"
              class="size-5 text-xl !leading-5"
            />
            <Icon v-else icon="i-lucide-smile-plus " class="size-4" />
          </NextButton>
          <EmojiIconPicker
            v-if="isIconPickerOpen"
            class="start-0 top-10"
            :value="state.icon"
            :color="state.iconColor"
            show-remove-button
            @select="onSelectIcon"
            @color-change="onColorChange"
            @remove="onRemoveIcon"
          />
        </OnClickOutside>
      </div>
      <FormInput
        v-model="state.description"
        name="description"
        spacing="compact"
        :label="$t('TEAMS_SETTINGS.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('TEAMS_SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
        :has-error="v$.description.$error"
        :error-message="
          v$.description.$error ? v$.description.$errors[0].$message : ''
        "
        @blur="v$.description.$touch"
      />
      <div class="w-full flex items-center gap-2">
        <input v-model="state.allowAutoAssign" type="checkbox" :value="true" />
        <label for="conversation_creation">
          {{ $t('TEAMS_SETTINGS.FORM.AUTO_ASSIGN.LABEL') }}
        </label>
      </div>
      <div class="w-full">
        <label>
          {{ $t('TEAMS_SETTINGS.FORM.MANAGER.LABEL') }}
          <select v-model="state.managerId" class="!mb-0">
            <option :value="null">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGER.NONE') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
      </div>
      <div class="w-full flex items-center gap-2">
        <input v-model="state.active" type="checkbox" :value="true" />
        <label for="team_active">
          {{ $t('TEAMS_SETTINGS.FORM.ACTIVE.LABEL') }}
        </label>
      </div>
      <!-- Nem toda Mesa conversa com cliente nem executa Projetos - desmarcar
           tira a Mesa da lista de Times em Conversas/do filtro de Projetos,
           sem apagar nada do que ela ja tem. -->
      <div class="w-full flex items-center gap-2">
        <input
          v-model="state.handlesConversations"
          type="checkbox"
          :value="true"
        />
        <label for="handles_conversations">
          {{ $t('TEAMS_SETTINGS.FORM.HANDLES_CONVERSATIONS.LABEL') }}
        </label>
      </div>
      <div class="w-full flex items-center gap-2">
        <input v-model="state.handlesProjects" type="checkbox" :value="true" />
        <label for="handles_projects">
          {{ $t('TEAMS_SETTINGS.FORM.HANDLES_PROJECTS.LABEL') }}
        </label>
      </div>
      <!-- Desligado, a Mesa segue com um responsavel so, como sempre foi. -->
      <div class="w-full flex flex-col gap-1">
        <div class="flex items-center gap-2">
          <input
            v-model="state.assigneeLevelsEnabled"
            type="checkbox"
            :value="true"
          />
          <label for="assignee_levels">
            {{ $t('TEAMS_SETTINGS.FORM.ASSIGNEE_LEVELS.LABEL') }}
          </label>
        </div>
        <p class="text-sm text-n-slate-10">
          {{ $t('TEAMS_SETTINGS.FORM.ASSIGNEE_LEVELS.HELP') }}
        </p>

        <!-- Quantos niveis. So aparece com a configuracao ligada, porque sem ela
             o numero nao significa nada. O teto e o do servidor: o ticket tem uma
             coluna de responsavel por nivel ate ali. -->
        <div
          v-if="state.assigneeLevelsEnabled"
          class="flex flex-col gap-1 mt-1 ltr:ml-6 rtl:mr-6 max-w-xs"
        >
          <label for="assignee_levels_count" class="text-sm">
            {{ $t('TEAMS_SETTINGS.FORM.ASSIGNEE_LEVELS.COUNT_LABEL') }}
          </label>
          <select
            id="assignee_levels_count"
            v-model="state.assigneeLevelsCount"
            class="mb-0 text-sm"
          >
            <option v-for="count in LEVEL_COUNTS" :key="count" :value="count">
              {{ $t('TEAMS_SETTINGS.FORM.ASSIGNEE_LEVELS.COUNT_OPTION', { count }) }}
            </option>
          </select>
          <p class="text-sm text-n-slate-10">
            {{ $t('TEAMS_SETTINGS.FORM.ASSIGNEE_LEVELS.COUNT_HELP') }}
          </p>
        </div>
      </div>
      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <div class="w-full">
          <NextButton
            type="submit"
            :label="submitButtonText"
            :disabled="v$.title.$invalid || submitInProgress"
            :is-loading="submitInProgress"
          />
        </div>
      </div>
    </form>
  </div>
</template>
