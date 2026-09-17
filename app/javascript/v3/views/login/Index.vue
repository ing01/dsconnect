<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';
import AnalyticsHelper from 'dashboard/helper/AnalyticsHelper';
import { SESSION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    SessionLimitOverlay,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
      sessionsLimitReached: false,
      limitedSessions: [],
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          // Check if sessions limit reached
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (response?.errorCode === USER_NOT_CONFIRMED_ERROR_CODE) {
            this.loginApi.showLoading = false;
            this.$router.push({
              name: 'auth_verify_email',
              state: { email: credentials.email },
            });
            return;
          }

          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
    retryLoginWithParams(extraParams) {
      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        ...extraParams,
      };

      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.loginApi.showLoading = true;
      login(credentials)
        .then(result => {
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleSessionRevoke(sessionId) {
      this.retryLoginWithParams({ revoke_session_id: sessionId });
    },
    handleSessionRevokeAll() {
      this.retryLoginWithParams({ revoke_all_sessions: true });
    },
    handleSessionLimitCancel() {
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main class="login">
    <!-- Painel da marca. Escuro nos dois temas de proposito: e uma superficie
         de marca, nao de conteudo, e o degrade so fecha sobre o #221F20. -->
    <aside class="login__brand" aria-hidden="true">
      <div class="login__aurora" />
      <div class="login__grid" />

      <div class="login__brand-content">
        <div class="login__mark">
          <span class="login__halo" aria-hidden="true" />
          <span class="login__ring" aria-hidden="true" />
          <img
            :src="globalConfig.logoThumbnail || globalConfig.logo"
            :alt="globalConfig.installationName"
            class="login__brand-mark"
          />
        </div>
        <p class="login__tagline">
          {{ replaceInstallationName($t('LOGIN.BRAND_TAGLINE')) }}
        </p>
        <p class="login__subtitle">
          {{ replaceInstallationName($t('LOGIN.BRAND_SUBTITLE')) }}
        </p>
      </div>
    </aside>

    <!-- Coluna do formulario -->
    <section class="login__panel">
      <div class="login__panel-inner">
        <header class="login__header">
          <img
            :src="globalConfig.logo"
            :alt="globalConfig.installationName"
            class="login__logo dark:hidden"
          />
          <img
            v-if="globalConfig.logoDark"
            :src="globalConfig.logoDark"
            :alt="globalConfig.installationName"
            class="hidden login__logo dark:block"
          />
          <h1 class="login__title">
            {{ replaceInstallationName($t('LOGIN.TITLE')) }}
          </h1>
          <p v-if="showSignupLink" class="login__signup">
            {{ $t('COMMON.OR') }}
            <router-link to="auth/signup" class="login__link lowercase">
              {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
            </router-link>
          </p>
        </header>

        <!-- Session Limit Section -->
        <div v-if="sessionsLimitReached" class="login__card">
          <SessionLimitOverlay
            :sessions="limitedSessions"
            @revoke="handleSessionRevoke"
            @revoke-all="handleSessionRevokeAll"
            @cancel="handleSessionLimitCancel"
          />
        </div>

        <!-- MFA Verification Section -->
        <div v-else-if="mfaRequired" class="login__card">
          <MfaVerification
            :mfa-token="mfaToken"
            @verified="handleMfaVerified"
            @cancel="handleMfaCancel"
          />
        </div>

        <!-- Regular Login Section -->
        <div
          v-else
          class="login__card"
          :class="{ 'animate-wiggle': loginApi.hasErrored }"
        >
          <div v-if="!email">
            <div
              v-if="showGoogleOAuth || showSamlLogin"
              class="flex flex-col gap-4"
            >
              <GoogleOAuthButton v-if="showGoogleOAuth" />
              <router-link
                v-if="showSamlLogin"
                to="/app/login/sso"
                class="login__sso"
              >
                <Icon icon="i-lucide-lock-keyhole" class="size-5" />
                <span>{{ $t('LOGIN.SAML.LABEL') }}</span>
              </router-link>
              <SimpleDivider :label="$t('COMMON.OR')" class="uppercase" />
            </div>

            <form class="login__form" @submit.prevent="submitFormLogin">
              <FormInput
                v-model="credentials.email"
                name="email_address"
                type="text"
                data-testid="email_input"
                :tabindex="1"
                required
                :label="$t('LOGIN.EMAIL.LABEL')"
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                :has-error="v$.credentials.email.$error"
                @input="v$.credentials.email.$touch"
              />
              <FormInput
                v-model="credentials.password"
                type="password"
                name="password"
                data-testid="password_input"
                required
                :tabindex="2"
                :label="$t('LOGIN.PASSWORD.LABEL')"
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                :has-error="v$.credentials.password.$error"
                @input="v$.credentials.password.$touch"
              >
                <p v-if="!globalConfig.disableUserProfileUpdate">
                  <router-link
                    to="auth/reset/password"
                    class="login__link text-sm"
                    tabindex="4"
                  >
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </p>
              </FormInput>
              <NextButton
                lg
                type="submit"
                data-testid="submit_button"
                class="login__submit w-full"
                :tabindex="3"
                :label="$t('LOGIN.SUBMIT')"
                :disabled="loginApi.showLoading"
                :is-loading="loginApi.showLoading"
              />
            </form>
          </div>
          <div v-else class="flex items-center justify-center py-8">
            <Spinner color-scheme="primary" size="" />
          </div>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
/* Paleta pedida. O azul claro e o escuro sao tons derivados do #127bba, usados
   so para dar profundidade ao degrade - nao sao cores novas de marca. */
.login {
  --ink: #221f20;
  --slate: #3f3b3d;
  --white: #ffffff;
  --brand: #127bba;
  --brand-bright: #1ea0e6;
  --brand-deep: #0b4f78;

  display: grid;
  grid-template-columns: 1fr;
  min-height: 100vh;
  min-height: 100dvh;
  background: var(--white);
}

/* O painel de conteudo acompanha o tema; o da marca nao. */
.login:where(.dark, .dark *) {
  background: var(--ink);
}

/* ---------- Painel da marca ---------- */

.login__brand {
  position: relative;
  display: none;
  overflow: hidden;
  background: var(--ink);
  isolation: isolate;
}

/* Manchas de luz que respiram devagar. Duas camadas em tamanhos diferentes
   evitam o efeito de "pulsacao" uniforme, que denuncia animacao barata. */
.login__aurora {
  position: absolute;
  inset: -30%;
  /* As manchas ficam fora do caminho da marca, que se apoia no canto superior
     esquerdo do conteudo. Antes a mais clara nascia exatamente ali (22% 28%) e a
     logo, sendo azul, se dissolvia nela. Agora a luz mora a direita e embaixo, e
     o traco azul aparece contra o proprio #221F20 do painel - que e o fundo em
     que ele foi desenhado para render. */
  background: radial-gradient(
      42% 46% at 82% 22%,
      color-mix(in srgb, var(--brand-bright) 82%, transparent) 0%,
      transparent 70%
    ),
    radial-gradient(
      48% 48% at 92% 62%,
      color-mix(in srgb, var(--brand) 88%, transparent) 0%,
      transparent 72%
    ),
    radial-gradient(
      55% 52% at 38% 104%,
      color-mix(in srgb, var(--brand-deep) 92%, transparent) 0%,
      transparent 76%
    );
  filter: blur(34px);
  animation: aurora 14s ease-in-out infinite alternate;
}

/* Textura: uma grade fina que some nas bordas. Da materialidade sem competir
   com a logo. */
.login__grid {
  position: absolute;
  inset: 0;
  background-image: linear-gradient(
      to right,
      color-mix(in srgb, var(--white) 6%, transparent) 1px,
      transparent 1px
    ),
    linear-gradient(
      to bottom,
      color-mix(in srgb, var(--white) 6%, transparent) 1px,
      transparent 1px
    );
  background-size: 46px 46px;
  mask-image: radial-gradient(70% 60% at 50% 45%, #000 0%, transparent 100%);
}

.login__brand-content {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: center;
  height: 100%;
  padding: 4rem;
  max-width: 34rem;
  margin-inline: auto;
}

/* A logo ganha profundidade por camadas: um halo que pulsa, um anel que gira
   devagar, e a marca flutuando por cima. Separado em tres elementos porque cada
   um precisa de um tempo proprio - juntos num so, a animacao fica mecanica. */
.login__mark {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  align-self: flex-start;
  margin-bottom: 3.5rem;
  isolation: isolate;
}

/* Brilho azul que respira atras da marca. */
.login__halo {
  position: absolute;
  z-index: -2;
  width: 215%;
  aspect-ratio: 1;
  border-radius: 50%;
  background: radial-gradient(
    circle,
    transparent 0%,
    transparent 34%,
    color-mix(in srgb, var(--brand-bright) 88%, transparent) 50%,
    color-mix(in srgb, var(--brand) 40%, transparent) 62%,
    transparent 74%
  );
  filter: blur(30px);
  animation: halo 4.5s ease-in-out infinite;
}

/* Anel de luz girando: da movimento continuo sem mexer na logo em si. */
.login__ring {
  position: absolute;
  z-index: -1;
  width: 165%;
  aspect-ratio: 1;
  border-radius: 50%;
  background: conic-gradient(
    from 0deg,
    transparent 0deg,
    color-mix(in srgb, var(--brand-bright) 90%, transparent) 60deg,
    transparent 150deg,
    transparent 360deg
  );
  mask: radial-gradient(
    circle,
    transparent 58%,
    #000 60%,
    #000 66%,
    transparent 68%
  );
  opacity: 0.85;
  animation: spin 9s linear infinite;
}

.login__brand-mark {
  position: relative;
  z-index: 1;
  width: auto;
  height: clamp(9.5rem, 16vw, 17rem);
  /* A propria marca fica mais viva, em vez de depender de um fundo atras dela:
     um pouco mais de saturacao e brilho no traco, uma sombra escura curta que a
     descola do painel, e um halo azul largo que a faz existir no escuro. */
  filter: saturate(1.2) brightness(1.12) drop-shadow(0 3px 8px rgb(0 0 0 / 60%))
    drop-shadow(0 0 34px rgb(18 123 186 / 55%));
  animation:
    rise 700ms cubic-bezier(0.22, 1, 0.36, 1) both,
    float 5s ease-in-out 700ms infinite;
}

.login__tagline {
  margin: 0;
  font-size: clamp(1.75rem, 2.4vw, 2.5rem);
  font-weight: 600;
  line-height: 1.2;
  text-wrap: balance;
  color: var(--white);
  animation: rise 700ms cubic-bezier(0.22, 1, 0.36, 1) 80ms both;
}

.login__subtitle {
  margin: 1rem 0 0;
  max-width: 28rem;
  font-size: 1rem;
  line-height: 1.6;
  color: color-mix(in srgb, var(--white) 68%, transparent);
  animation: rise 700ms cubic-bezier(0.22, 1, 0.36, 1) 160ms both;
}

/* ---------- Coluna do formulario ---------- */

.login__panel {
  display: flex;
  align-items: center;
  justify-content: center;
  /* O padding lateral fica aqui, num elemento so, para nao haver margem que
     colapse ou dobre nos filhos. */
  padding-inline: 1.5rem;
  padding-block: 3rem;
}

.login__panel-inner {
  width: 100%;
  max-width: 26rem;
  animation: rise 600ms cubic-bezier(0.22, 1, 0.36, 1) both;
}

.login__header {
  text-align: center;
  margin-bottom: 2rem;
}

.login__logo {
  width: auto;
  height: 5rem;
  filter: drop-shadow(0 6px 18px rgb(18 123 186 / 35%));
  margin-inline: auto;
  margin-bottom: 1.5rem;
}

/* No desktop a marca ja aparece no painel esquerdo; repetir a logo aqui seria
   redundante. */
@media (min-width: 1024px) {
  .login__logo {
    display: none;
  }

  .login .login__logo.dark\:block {
    display: none;
  }
}

.login__title {
  margin: 0;
  font-size: 1.75rem;
  font-weight: 600;
  line-height: 1.25;
  text-wrap: balance;
  color: var(--ink);
}

.login__title:where(.dark, .dark *) {
  color: var(--white);
}

.login__signup {
  margin: 0.75rem 0 0;
  font-size: 0.875rem;
  color: var(--slate);
}

.login__signup:where(.dark, .dark *) {
  color: color-mix(in srgb, var(--white) 60%, transparent);
}

.login__link {
  font-weight: 500;
  color: var(--brand);
  text-underline-offset: 2px;
}

.login__link:hover {
  text-decoration: underline;
}

/* ---------- Cartao ---------- */

.login__card {
  padding: 2rem;
  border-radius: 1rem;
  background: var(--white);
  border: 1px solid color-mix(in srgb, var(--slate) 14%, transparent);
  box-shadow:
    0 1px 2px rgb(34 31 32 / 4%),
    0 12px 32px -12px rgb(34 31 32 / 14%);
  transition:
    box-shadow 300ms ease,
    transform 300ms ease;
}

.login__card:focus-within {
  box-shadow:
    0 1px 2px rgb(34 31 32 / 4%),
    0 18px 44px -14px rgb(18 123 186 / 28%);
}

.login__card:where(.dark, .dark *) {
  background: color-mix(in srgb, var(--slate) 42%, var(--ink));
  border-color: color-mix(in srgb, var(--white) 10%, transparent);
  box-shadow: 0 18px 48px -20px rgb(0 0 0 / 70%);
}

.login__form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

/* Foco com halo na cor da marca, aplicado ao input de dentro do FormInput. */
.login__card :deep(input:focus) {
  box-shadow: 0 0 0 4px color-mix(in srgb, var(--brand) 18%, transparent);
}

.login__sso {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.75rem 1rem;
  border-radius: 0.5rem;
  font-weight: 500;
  color: var(--ink);
  border: 1px solid color-mix(in srgb, var(--slate) 20%, transparent);
  transition:
    border-color 200ms ease,
    background-color 200ms ease;
}

.login__sso:hover {
  border-color: var(--brand);
  background: color-mix(in srgb, var(--brand) 6%, transparent);
}

.login__sso:where(.dark, .dark *) {
  color: var(--white);
  border-color: color-mix(in srgb, var(--white) 16%, transparent);
}

/* Botao: degrade da marca, com um brilho que atravessa no hover. */
.login__submit {
  position: relative;
  overflow: hidden;
  background: linear-gradient(
    135deg,
    var(--brand) 0%,
    var(--brand-bright) 100%
  ) !important;
  border-color: transparent !important;
  color: var(--white) !important;
  box-shadow: 0 8px 20px -8px rgb(18 123 186 / 60%);
  transition:
    transform 180ms ease,
    box-shadow 180ms ease;
}

.login__submit:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 12px 26px -8px rgb(18 123 186 / 70%);
}

.login__submit:active:not(:disabled) {
  transform: translateY(0);
}

.login__submit::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(
    100deg,
    transparent 30%,
    rgb(255 255 255 / 28%) 50%,
    transparent 70%
  );
  transform: translateX(-100%);
}

.login__submit:hover:not(:disabled)::after {
  animation: shine 900ms ease;
}

/* ---------- Responsivo ---------- */

@media (min-width: 1024px) {
  .login {
    grid-template-columns: 1.05fr 1fr;
  }

  .login__brand {
    display: block;
  }

  .login__panel {
    padding-inline: 3rem;
  }
}

@media (min-width: 1536px) {
  .login {
    grid-template-columns: 1.2fr 1fr;
  }
}

/* ---------- Animacoes ---------- */

@keyframes aurora {
  0% {
    transform: translate3d(-9%, -5%, 0) scale(1);
  }
  50% {
    transform: translate3d(8%, 9%, 0) scale(1.18);
  }
  100% {
    transform: translate3d(-5%, 7%, 0) scale(1.08);
  }
}

@keyframes float {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-20px);
  }
}

@keyframes halo {
  0%,
  100% {
    opacity: 0.55;
    transform: scale(0.86);
  }
  50% {
    opacity: 1;
    transform: scale(1.24);
  }
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes shine {
  to {
    transform: translateX(100%);
  }
}

@media (prefers-reduced-motion: reduce) {
  .login__aurora,
  .login__halo,
  .login__ring,
  .login__brand-mark,
  .login__tagline,
  .login__subtitle,
  .login__panel-inner,
  .login__submit::after {
    animation: none;
  }

  .login__submit,
  .login__card {
    transition: none;
  }
}
</style>
