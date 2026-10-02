import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

/**
 * Logica de instalar o Portal do Cliente como PWA, compartilhada entre o
 * cabecalho do Portal (ClientLayout.vue) e o link publico de instalacao
 * (ClientInstallPage.vue) - o mesmo link pode ser mandado para alguem que
 * ainda nem tem sessao, so para instalar o app antes de entrar.
 *
 * O navegador so' dispara `beforeinstallprompt` quando a pagina passa nos
 * criterios de instalabilidade (manifest + service worker) - ate' la' fica
 * indisponivel, e nao' volta depois de instalado (`appinstalled`) ou quando
 * ja' esta' rodando como app (`display-mode: standalone`).
 *
 * Safari no iPhone/iPad NUNCA dispara esse evento (nao tem esse mecanismo) -
 * so' instala via Compartilhar > Adicionar a Tela de Inicio, manualmente.
 */
export function useAppInstallPrompt() {
  const installPromptEvent = ref(null);

  const isIosSafari =
    /iphone|ipad|ipod/i.test(window.navigator.userAgent) &&
    !window.navigator.standalone;

  const isStandaloneAlready =
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true;

  const isInstallable = computed(
    () =>
      !isStandaloneAlready && (Boolean(installPromptEvent.value) || isIosSafari)
  );

  const onBeforeInstallPrompt = event => {
    event.preventDefault();
    installPromptEvent.value = event;
  };

  const onAppInstalled = () => {
    installPromptEvent.value = null;
  };

  const instalarApp = async () => {
    if (installPromptEvent.value) {
      installPromptEvent.value.prompt();
      await installPromptEvent.value.userChoice;
      installPromptEvent.value = null;
      return true;
    }

    return false;
  };

  onMounted(() => {
    window.addEventListener('beforeinstallprompt', onBeforeInstallPrompt);
    window.addEventListener('appinstalled', onAppInstalled);
  });

  onBeforeUnmount(() => {
    window.removeEventListener('beforeinstallprompt', onBeforeInstallPrompt);
    window.removeEventListener('appinstalled', onAppInstalled);
  });

  return {
    isIosSafari,
    isStandaloneAlready,
    isInstallable,
    instalarApp,
  };
}
