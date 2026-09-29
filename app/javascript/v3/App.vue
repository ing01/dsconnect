<script>
import SnackbarContainer from './components/SnackBar/Container.vue';
import {
  isOSOnDarkMode,
  preferredColorScheme,
  setColorTheme,
} from 'dashboard/helper/themeHelper';

export default {
  components: { SnackbarContainer },
  data() {
    return { theme: 'light' };
  },
  mounted() {
    this.setColorTheme();
    this.listenToThemeChanges();
    this.setLocale(window.chatwootConfig.selectedLocale);
  },
  methods: {
    // Antes esta tela olhava SO o sistema operacional, e ignorava a escolha de
    // quem usa: quem tinha escolhido escuro chegava ao login claro, porque o
    // aparelho estava no claro. Agora ela usa a mesma resolucao do painel -
    // escolha gravada neste navegador primeiro, sistema operacional so no
    // `auto`. O usuario nao existe aqui, entao `localStorage` e tudo o que ha.
    setColorTheme() {
      this.theme = setColorTheme(isOSOnDarkMode()) ? 'dark' : 'light';
    },
    listenToThemeChanges() {
      const mql = window.matchMedia('(prefers-color-scheme: dark)');

      // Mudanca no sistema operacional so vale quando a escolha e `auto`. Quem
      // pediu escuro nao quer que o amanhecer do celular acenda a tela.
      mql.onchange = event => {
        if (preferredColorScheme() !== 'auto') return;

        this.theme = setColorTheme(event.matches) ? 'dark' : 'light';
      };
    },
    setLocale(locale) {
      if (locale) {
        this.$root.$i18n.locale = locale;
      }
    },
  },
};
</script>

<template>
  <div class="h-full min-h-screen w-full antialiased" :class="theme">
    <router-view />
    <SnackbarContainer />
  </div>
</template>

<style lang="scss">
@tailwind base;
@tailwind components;
@tailwind utilities;

@import '../dashboard/assets/scss/next-colors';

html,
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
    Oxygen-Sans, Ubuntu, Cantarell, 'Helvetica Neue', sans-serif;
  @apply h-full w-full;

  input,
  select {
    outline: none;
  }
}

.text-link {
  @apply text-n-brand font-medium hover:text-n-blue-10;
}

.v-popper--theme-tooltip .v-popper__inner {
  background: black !important;
  font-size: 0.75rem;
  padding: 4px 8px !important;
  border-radius: 6px;
  font-weight: 400;
}

.v-popper--theme-tooltip .v-popper__arrow-container {
  display: none;
}
</style>
