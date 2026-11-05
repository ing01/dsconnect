<script setup>
import { reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';

import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PauseConfigFields from 'dashboard/components/widgets/PauseConfig/PauseConfigFields.vue';
import {
  pauseFromConfig,
  pauseToConfig,
} from 'dashboard/components/widgets/PauseConfig/pauseConfig';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();
const isUpdating = ref(false);

const state = reactive({
  nudgeAfter: '',
  inactivityMessage: '',
  closeAfter: '',
  resolveMessage: '',
  pause: pauseFromConfig(),
});

watch(
  () => props.inbox,
  inbox => {
    const config = inbox.inactivity_config || {};
    state.nudgeAfter = config.nudge_after || '';
    state.inactivityMessage = config.inactivity_message || '';
    state.closeAfter = config.close_after || '';
    state.resolveMessage = config.resolve_message || '';
    state.pause = pauseFromConfig(config);
  },
  { immediate: true }
);

const textareaClass =
  'w-full px-3 py-2 text-sm rounded-lg outline outline-1 -outline-offset-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-n-brand';

const save = async () => {
  isUpdating.value = true;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      inactivity_config: {
        nudge_after: state.nudgeAfter || null,
        inactivity_message: state.inactivityMessage,
        close_after: state.closeAfter || null,
        resolve_message: state.resolveMessage,
        ...pauseToConfig(state.pause),
      },
    });
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <div class="mx-6 max-w-4xl">
    <SettingsFieldSection
      :label="t('INBOX_MGMT.INACTIVITY.NUDGE_AFTER.LABEL')"
      :help-text="t('INBOX_MGMT.INACTIVITY.NUDGE_AFTER.HELP')"
    >
      <Input
        v-model="state.nudgeAfter"
        type="number"
        min="1"
        :placeholder="t('INBOX_MGMT.INACTIVITY.NUDGE_AFTER.PLACEHOLDER')"
      />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('INBOX_MGMT.INACTIVITY.INACTIVITY_MESSAGE.LABEL')"
      :help-text="t('INBOX_MGMT.INACTIVITY.INACTIVITY_MESSAGE.HELP')"
    >
      <textarea
        v-model="state.inactivityMessage"
        rows="3"
        :class="textareaClass"
        :placeholder="t('INBOX_MGMT.INACTIVITY.INACTIVITY_MESSAGE.PLACEHOLDER')"
      />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('INBOX_MGMT.INACTIVITY.CLOSE_AFTER.LABEL')"
      :help-text="t('INBOX_MGMT.INACTIVITY.CLOSE_AFTER.HELP')"
    >
      <Input
        v-model="state.closeAfter"
        type="number"
        min="1"
        :placeholder="t('INBOX_MGMT.INACTIVITY.CLOSE_AFTER.PLACEHOLDER')"
      />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('INBOX_MGMT.INACTIVITY.RESOLVE_MESSAGE.LABEL')"
      :help-text="t('INBOX_MGMT.INACTIVITY.RESOLVE_MESSAGE.HELP')"
    >
      <textarea
        v-model="state.resolveMessage"
        rows="3"
        :class="textareaClass"
        :placeholder="t('INBOX_MGMT.INACTIVITY.RESOLVE_MESSAGE.PLACEHOLDER')"
      />
    </SettingsFieldSection>

    <div class="mb-6">
      <PauseConfigFields v-model="state.pause" />
    </div>

    <NextButton
      :is-loading="isUpdating"
      :label="t('INBOX_MGMT.INACTIVITY.SAVE')"
      @click="save"
    />
  </div>
</template>
