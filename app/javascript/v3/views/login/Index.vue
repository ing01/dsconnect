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
import ClientAreaAPI from 'dashboard/api/clientArea';
import { setClientSession } from 'dashboard/helper/clientSession';
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
    // A mesma imagem serve a marca em tamanho normal e a textura gigante do
    // fundo. O thumbnail vem primeiro por ser o recorte quadrado da marca.
    brandMark() {
      return this.globalConfig.logoThumbnail || this.globalConfig.logo;
    },
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
        .catch(async response => {
          // Antes de declarar credencial invalida: pode ser um CONTATO com
          // acesso a Area do Cliente. O usuario interno nunca passa por aqui
          // quando acerta a senha - o fluxo dele termina no `then` acima.
          if (await this.tryClientLogin(credentials)) return;

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
    // Tenta a Area do Cliente com a mesma credencial. Devolve `true` quando
    // entrou - e ai a navegacao ja aconteceu.
    async tryClientLogin(credentials) {
      const { email: userEmail, password } = credentials;
      if (!userEmail || !password) return false;

      try {
        const { data } = await ClientAreaAPI.login({
          email: userEmail,
          password,
        });
        setClientSession(data);
        window.location = '/app/client/tickets';
        return true;
      } catch (error) {
        // 401 e a resposta esperada para "nao e um cliente": segue o erro do
        // login interno, que e de onde a pessoa mais provavelmente veio.
        // Qualquer outra coisa e defeito nosso e precisa aparecer - engolir
        // tudo foi o que escondeu a chamada que nem chegava a sair.
        if (error?.response?.status !== 401) {
          // eslint-disable-next-line no-console
          console.error('Falha ao tentar o acesso da Área do Cliente', error);
        }
        return false;
      }
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
      <img :src="brandMark" alt="" class="login__watermark" />
      <div class="login__depth" />

      <div class="login__brand-content">
        <div class="login__mark">
          <span class="login__ring" aria-hidden="true" />
          <img
            :src="brandMark"
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
        <!-- Sem logo aqui: a marca ja aparece na faixa acima (no celular) e no
             painel da esquerda (no desktop). -->
        <header class="login__header">
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
  /* No celular a marca e uma faixa em cima e o formulario embaixo; no desktop
     viram duas colunas (ver a consulta de 1024px). Antes a faixa simplesmente
     nao existia no celular: a tela abria branca, com a logo pequena e nada da
     identidade que o computador mostra. */
  grid-template-columns: 1fr;
  grid-template-rows: auto 1fr;
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
  overflow: hidden;
  background: var(--ink);
  isolation: isolate;
}

/* A propria marca e a textura do painel: uma copia gigante e quase apagada,
   girando muito devagar. O azul deixa de ser mancha solta e passa a ter forma -
   a forma da marca. Como e a mesma imagem, a identidade se repete em duas
   escalas em vez de competir consigo mesma. */
.login__watermark {
  position: absolute;
  top: 50%;
  left: 50%;
  width: auto;
  height: 260%;
  max-width: none;
  opacity: 0.09;
  filter: saturate(1.6) blur(1px);
  /* Centralizacao de base: a animacao repete este `translate` em cada quadro,
     entao ela sobrepoe sem conflito - e quando o movimento e desligado por
     `prefers-reduced-motion`, a marca continua no lugar certo em vez de saltar
     para o canto. */
  transform: translate(-50%, -50%);
  transform-origin: center;
  animation: drift 40s linear infinite;
  pointer-events: none;
}

/* Profundidade: o painel escurece nas bordas e ganha um respiro de azul no
   canto inferior direito - longe de onde a marca nitida se apoia. */
.login__depth {
  position: absolute;
  inset: 0;
  background: radial-gradient(
      60% 55% at 88% 82%,
      color-mix(in srgb, var(--brand) 42%, transparent) 0%,
      transparent 70%
    ),
    radial-gradient(
      120% 100% at 30% 35%,
      transparent 0%,
      color-mix(in srgb, var(--ink) 75%, transparent) 100%
    );
}

.login__brand-content {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2.25rem 1.5rem 2rem;
  max-width: 34rem;
  margin-inline: auto;
  text-align: center;
}

/* A logo ganha profundidade por camadas: um halo que pulsa, um anel que gira
   devagar, e a marca flutuando por cima. Separado em tres elementos porque cada
   um precisa de um tempo proprio - juntos num so, a animacao fica mecanica. */
.login__mark {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1.25rem;
  isolation: isolate;
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
  height: clamp(4.5rem, 20vw, 7rem);
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
  font-size: clamp(1.15rem, 5vw, 1.5rem);
  font-weight: 600;
  line-height: 1.2;
  text-wrap: balance;
  color: var(--white);
  animation: rise 700ms cubic-bezier(0.22, 1, 0.36, 1) 80ms both;
}

.login__subtitle {
  display: none;
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
    grid-template-rows: 1fr;
  }

  .login__watermark {
    height: 150%;
  }

  .login__brand-content {
    align-items: flex-start;
    height: 100%;
    padding: 4rem;
    text-align: start;
  }

  .login__mark {
    align-self: flex-start;
    margin-bottom: 3.5rem;
  }

  .login__brand-mark {
    height: clamp(9.5rem, 16vw, 17rem);
  }

  .login__tagline {
    font-size: clamp(1.75rem, 2.4vw, 2.5rem);
  }

  .login__subtitle {
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

/* Giro completo e lento. O `translate(-50%, -50%)` mora aqui, e nao no
   elemento, porque `transform` e uma propriedade so: se ficasse no CSS base, a
   animacao o sobrescreveria e a marca saltaria para fora do lugar. */
@keyframes drift {
  from {
    transform: translate(-50%, -50%) rotate(0deg) scale(1);
  }
  50% {
    transform: translate(-50%, -50%) rotate(180deg) scale(1.12);
  }
  to {
    transform: translate(-50%, -50%) rotate(360deg) scale(1);
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
  .login__watermark,
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
