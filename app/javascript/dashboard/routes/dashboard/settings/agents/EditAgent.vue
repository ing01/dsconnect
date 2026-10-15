<script setup>
import { ref, computed } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Auth from '../../../../api/auth';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    default: '',
  },
  type: {
    type: String,
    default: '',
  },
  availability: {
    type: String,
    default: '',
  },
  provider: {
    type: String,
    default: '',
  },
  customRoleId: {
    type: Number,
    default: null,
  },
  enforceQueueOrder: {
    type: Boolean,
    default: false,
  },
  lunchStartHour: {
    type: Number,
    default: null,
  },
  lunchStartMinutes: {
    type: Number,
    default: null,
  },
  lunchEndHour: {
    type: Number,
    default: null,
  },
  lunchEndMinutes: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { AVAILABILITY_STATUS_KEYS } = wootConstants;

const store = useStore();
const { t } = useI18n();

const agentName = ref(props.name);
const agentAvailability = ref(props.availability);
const selectedRoleId = ref(props.customRoleId || props.type);
const agentCredentials = ref({ email: props.email });
const enforceQueueOrder = ref(props.enforceQueueOrder);

// `<input type="time">` fala HH:MM - as 4 colunas (hora/minuto separados)
// sao so o formato de armazenamento, pensado pra bater com WorkingHour. Os
// dois campos vazios juntos = sem almoco cadastrado (o `payload` abaixo manda
// os 4 como null nesse caso, pra poder apagar um horario ja salvo).
const timeToHourMinutes = time => {
  if (!time) return [null, null];
  const [hour, minutes] = time.split(':').map(Number);
  return [hour, minutes];
};

const hourMinutesToTime = (hour, minutes) => {
  if (hour == null || minutes == null) return '';
  return `${String(hour).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
};

const lunchStart = ref(
  hourMinutesToTime(props.lunchStartHour, props.lunchStartMinutes)
);
const lunchEnd = ref(
  hourMinutesToTime(props.lunchEndHour, props.lunchEndMinutes)
);

const lunchBreakInvalid = computed(() => {
  // Um campo preenchido e o outro vazio - os dois juntos sao obrigatorios
  // (ou nenhum). Fim antes do inicio tambem e invalido.
  if (!lunchStart.value && !lunchEnd.value) return false;
  if (!lunchStart.value || !lunchEnd.value) return true;
  return lunchEnd.value <= lunchStart.value;
});

const rules = {
  agentName: { required, minLength: minLength(1) },
  selectedRoleId: { required },
  agentAvailability: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  selectedRoleId,
  agentAvailability,
});

const pageTitle = computed(
  () => `${t('AGENT_MGMT.EDIT.TITLE')} - ${props.name}`
);

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const statusList = computed(() => {
  return [
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
  ];
});

const availabilityStatuses = computed(() =>
  statusList.value.map((statusLabel, index) => ({
    label: statusLabel,
    value: AVAILABILITY_STATUS_KEYS[index],
    disabled: props.availability === AVAILABILITY_STATUS_KEYS[index],
  }))
);

const editAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid || lunchBreakInvalid.value) return;

  try {
    const [lunchStartHour, lunchStartMinutes] = timeToHourMinutes(
      lunchStart.value
    );
    const [lunchEndHour, lunchEndMinutes] = timeToHourMinutes(lunchEnd.value);

    const payload = {
      id: props.id,
      name: agentName.value,
      availability: agentAvailability.value,
      enforce_queue_order: enforceQueueOrder.value,
      lunch_start_hour: lunchStartHour,
      lunch_start_minutes: lunchStartMinutes,
      lunch_end_hour: lunchEndHour,
      lunch_end_minutes: lunchEndMinutes,
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
      payload.custom_role_id = null;
    }

    await store.dispatch('agents/update', payload);
    useAlert(t('AGENT_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
};

const resetPassword = async () => {
  try {
    await Auth.resetPassword(agentCredentials.value);
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="w-full" @submit.prevent="editAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.EDIT.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentAvailability.$error }">
          {{ $t('PROFILE_SETTINGS.FORM.AVAILABILITY.LABEL') }}
          <select
            v-model="agentAvailability"
            @change="v$.agentAvailability.$touch"
          >
            <option
              v-for="status in availabilityStatuses"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </select>
          <span v-if="v$.agentAvailability.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_AVAILABILITY.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label class="flex items-center gap-2">
          <input v-model="enforceQueueOrder" type="checkbox" class="!m-0" />
          <span>{{
            $t('AGENT_MGMT.EDIT.FORM.ENFORCE_QUEUE_ORDER.LABEL')
          }}</span>
        </label>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ $t('AGENT_MGMT.EDIT.FORM.ENFORCE_QUEUE_ORDER.HELP') }}
        </p>
      </div>

      <div class="w-full">
        <label>{{ $t('AGENT_MGMT.EDIT.FORM.LUNCH_BREAK.LABEL') }}</label>
        <div class="flex items-center gap-2">
          <input v-model="lunchStart" type="time" class="!mb-0" />
          <span>{{ $t('AGENT_MGMT.EDIT.FORM.LUNCH_BREAK.TO') }}</span>
          <input v-model="lunchEnd" type="time" class="!mb-0" />
        </div>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ $t('AGENT_MGMT.EDIT.FORM.LUNCH_BREAK.HELP') }}
        </p>
        <span v-if="lunchBreakInvalid" class="message">
          {{ $t('AGENT_MGMT.EDIT.FORM.LUNCH_BREAK.ERROR') }}
        </span>
      </div>

      <div class="flex flex-row justify-start w-full gap-2 px-0 py-2">
        <div class="w-[50%] ltr:text-left rtl:text-right">
          <Button
            v-if="provider !== 'saml'"
            ghost
            type="button"
            icon="i-lucide-lock-keyhole"
            class="!px-2"
            :label="$t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_RESET_BUTTON')"
            @click.prevent="resetPassword"
          />
        </div>
        <div class="w-[50%] flex justify-end items-center gap-2">
          <Button
            faded
            slate
            type="reset"
            :label="$t('AGENT_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="emit('close')"
          />
          <Button
            type="submit"
            :label="$t('AGENT_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="v$.$invalid || lunchBreakInvalid || uiFlags.isUpdating"
            :is-loading="uiFlags.isUpdating"
          />
        </div>
      </div>
    </form>
  </div>
</template>
