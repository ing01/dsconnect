<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, url } from '@vuelidate/validators';
import router from '../../../../index';
import NextButton from 'dashboard/components-next/button/Button.vue';

import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';

export default {
  components: {
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
      phoneNumber: '',
      baseUrl: '',
      instanceName: '',
      token: '',
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
  },
  validations: {
    inboxName: { required },
    phoneNumber: { required, isPhoneE164OrEmpty },
    baseUrl: { required, url },
    instanceName: { required },
    token: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const whatsappChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.inboxName?.trim(),
            channel: {
              type: 'whatsapp',
              phone_number: this.phoneNumber,
              provider: 'expxwhats',
              provider_config: {
                base_url: this.baseUrl?.trim().replace(/\/$/, ''),
                instance_name: this.instanceName?.trim(),
                token: this.token?.trim(),
              },
            },
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: whatsappChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
    <p class="text-sm text-n-slate-11">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.HELP') }}
    </p>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.PLACEHOLDER')"
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.baseUrl.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.BASE_URL.LABEL') }}
        <input
          v-model="baseUrl"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.BASE_URL.PLACEHOLDER')
          "
          @blur="v$.baseUrl.$touch"
        />
        <span v-if="v$.baseUrl.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.BASE_URL.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.instanceName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.INSTANCE_NAME.LABEL') }}
        <input
          v-model="instanceName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.INSTANCE_NAME.PLACEHOLDER')
          "
          @blur="v$.instanceName.$touch"
        />
        <span v-if="v$.instanceName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.INSTANCE_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.token.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.TOKEN.LABEL') }}
        <input
          v-model="token"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.TOKEN.PLACEHOLDER')"
          @blur="v$.token.$touch"
        />
        <span v-if="v$.token.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EXPXWHATS.TOKEN.ERROR') }}
        </span>
      </label>
    </div>

    <div class="w-full">
      <NextButton
        type="submit"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.SUBMIT_BUTTON')"
        :is-loading="uiFlags.isCreating"
      />
    </div>
  </form>
</template>
