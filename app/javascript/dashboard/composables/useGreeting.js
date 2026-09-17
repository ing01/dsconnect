import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';

export function useGreeting() {
  const { t } = useI18n();
  const getters = useStoreGetters();
  const globalConfig = computed(() => getters['globalConfig/get'].value);
  const currentUser = computed(() => getters.getCurrentUser.value);

  const greetingMessage = computed(() => {
    const hours = new Date().getHours();
    let translationKey;
    if (hours < 12) {
      translationKey = 'ONBOARDING.GREETING_MORNING';
    } else if (hours < 18) {
      translationKey = 'ONBOARDING.GREETING_AFTERNOON';
    } else {
      translationKey = 'ONBOARDING.GREETING_EVENING';
    }
    return t(translationKey, {
      name: currentUser.value.name,
      installationName: globalConfig.value.installationName,
    });
  });

  return { greetingMessage, globalConfig };
}
