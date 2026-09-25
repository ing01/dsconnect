<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import AttendanceWindowsAPI from 'dashboard/api/attendanceWindows';

import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

// 0=Domingo..6=Sabado, mesma convencao do WorkingHour (Time#wday) - nao
// inventa uma numeracao propria pra nao ter que converter em outro lugar.
const DAYS = [0, 1, 2, 3, 4, 5, 6];
const DEFAULT_OFFLINE_MESSAGE =
  'No momento estamos fora do horário de atendimento. Assim que retomarmos, vamos continuar por aqui.';

const scheduleEnabled = ref(false);
const offlineMessage = ref(DEFAULT_OFFLINE_MESSAGE);
// { [day_of_week]: [{ start: 'HH:MM', end: 'HH:MM' }, ...] } - varios
// periodos por dia (plantao de fim de semana com horario diferente do
// expediente normal, por exemplo), nao so um por dia.
const windowsByDay = ref(Object.fromEntries(DAYS.map(day => [day, []])));
const isLoading = ref(true);
const isSubmitting = ref(false);

const minutesToTime = minutes => {
  const hours = Math.floor(minutes / 60)
    .toString()
    .padStart(2, '0');
  const mins = (minutes % 60).toString().padStart(2, '0');
  return `${hours}:${mins}`;
};

const timeToMinutes = time => {
  const [hours, minutes] = time.split(':').map(Number);
  return (hours * 60) + minutes;
};

const loadSettings = () => {
  const settings = currentAccount.value?.settings || {};
  scheduleEnabled.value = settings.attendance_schedule_enabled ?? false;
  offlineMessage.value =
    settings.attendance_offline_message || DEFAULT_OFFLINE_MESSAGE;
};

const loadWindows = async () => {
  const grouped = Object.fromEntries(DAYS.map(day => [day, []]));
  try {
    const { data } = await AttendanceWindowsAPI.get();
    (data.payload || []).forEach(window => {
      grouped[window.day_of_week].push({
        start: minutesToTime(window.start_minute),
        end: minutesToTime(window.end_minute),
      });
    });
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.API.LOAD_ERROR'));
  }
  windowsByDay.value = grouped;
};

onBeforeMount(async () => {
  loadSettings();
  await loadWindows();
  isLoading.value = false;
});

const addWindow = day => {
  windowsByDay.value[day] = [
    ...windowsByDay.value[day],
    { start: '09:00', end: '18:00' },
  ];
};

const removeWindow = (day, index) => {
  windowsByDay.value[day] = windowsByDay.value[day].filter(
    (_, position) => position !== index
  );
};

const invalidWindows = computed(() => {
  return DAYS.some(day =>
    windowsByDay.value[day].some(
      window => !window.start || !window.end || window.start >= window.end
    )
  );
});

const offlineMessageInvalid = computed(
  () => scheduleEnabled.value && !offlineMessage.value.trim()
);

const handleSubmit = async () => {
  if (invalidWindows.value) {
    useAlert(t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.INVALID_RANGE'));
    return;
  }
  if (offlineMessageInvalid.value) {
    useAlert(t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.OFFLINE_MESSAGE.REQUIRED'));
    return;
  }

  isSubmitting.value = true;
  try {
    const flatWindows = DAYS.flatMap(day =>
      windowsByDay.value[day].map(window => ({
        day_of_week: day,
        start_minute: timeToMinutes(window.start),
        end_minute: timeToMinutes(window.end),
      }))
    );

    await AttendanceWindowsAPI.bulkUpdate(flatWindows);
    await updateAccount(
      {
        attendance_schedule_enabled: scheduleEnabled.value,
        attendance_offline_message: offlineMessage.value.trim() || null,
      },
      { silent: true }
    );
    useAlert(t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.TITLE')"
        :description="t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.DESCRIPTION')"
      />
    </template>

    <template #body>
      <form
        class="flex flex-col w-full max-w-2xl gap-5"
        @submit.prevent="handleSubmit"
      >
        <div
          class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
        >
          <div class="flex items-center justify-between gap-4 px-5 py-4">
            <div class="flex flex-col gap-1">
              <h3 class="text-heading-2 text-n-slate-12">
                {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.ENABLED.LABEL') }}
              </h3>
              <p class="mb-0 text-body-para text-n-slate-11">
                {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.ENABLED.HELP') }}
              </p>
            </div>
            <Switch v-model="scheduleEnabled" />
          </div>

          <div v-if="scheduleEnabled" class="flex flex-col gap-1 px-5 py-4">
            <label class="text-sm text-n-slate-12">
              {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.OFFLINE_MESSAGE.LABEL') }}
            </label>
            <textarea
              v-model="offlineMessage"
              rows="3"
              class="mb-0"
              :placeholder="
                t(
                  'TICKET.SETTINGS.ATTENDANCE_SCHEDULE.OFFLINE_MESSAGE.PLACEHOLDER'
                )
              "
            />
            <p
              v-if="offlineMessageInvalid"
              class="mb-0 text-xs text-n-ruby-11"
            >
              {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.OFFLINE_MESSAGE.REQUIRED') }}
            </p>
            <p v-else class="mb-0 text-xs text-n-slate-11">
              {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.OFFLINE_MESSAGE.HELP') }}
            </p>
          </div>

          <div
            v-if="scheduleEnabled && !isLoading"
            class="flex flex-col gap-2 px-5 py-4"
          >
            <h3 class="text-heading-2 text-n-slate-12">
              {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.TITLE') }}
            </h3>
            <p class="mb-2 text-body-para text-n-slate-11">
              {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.DESCRIPTION') }}
            </p>

            <div
              v-for="day in DAYS"
              :key="day"
              class="flex flex-col gap-2 py-3 border-t border-n-weak first:border-t-0 first:pt-0"
            >
              <div class="flex items-center justify-between gap-2">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t(`TICKET.SETTINGS.ATTENDANCE_SCHEDULE.DAYS.${day}`) }}
                </span>
                <NextButton
                  type="button"
                  slate
                  faded
                  xs
                  icon="i-lucide-plus"
                  :label="t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.ADD')"
                  @click="addWindow(day)"
                />
              </div>

              <p
                v-if="!windowsByDay[day].length"
                class="mb-0 text-xs text-n-slate-10"
              >
                {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.EMPTY') }}
              </p>

              <div
                v-for="(window, index) in windowsByDay[day]"
                :key="index"
                class="flex items-center gap-2"
              >
                <input
                  v-model="window.start"
                  type="time"
                  class="mb-0 max-w-[9rem]"
                />
                <span class="text-sm text-n-slate-11">
                  {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.UNTIL') }}
                </span>
                <input
                  v-model="window.end"
                  type="time"
                  class="mb-0 max-w-[9rem]"
                />
                <NextButton
                  type="button"
                  ruby
                  ghost
                  xs
                  icon="i-lucide-trash-2"
                  @click="removeWindow(day, index)"
                />
              </div>
            </div>

            <p v-if="invalidWindows" class="mb-0 text-xs text-n-ruby-11">
              {{ t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.WINDOW.INVALID_RANGE') }}
            </p>
          </div>
        </div>

        <div class="flex justify-end">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :disabled="isLoading"
            :label="t('TICKET.SETTINGS.ATTENDANCE_SCHEDULE.SAVE')"
          />
        </div>
      </form>
    </template>
  </SettingsLayout>
</template>
