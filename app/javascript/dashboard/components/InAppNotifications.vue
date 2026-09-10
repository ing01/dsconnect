<script setup>
/**
 * Avisos exibidos dentro da propria pagina, no canto inferior direito.
 *
 * A origem e a mesma notificacao push de sempre: o service worker decide, a
 * cada evento, se a aba esta a vista. Se estiver, ele manda o conteudo para ca
 * em vez de abrir a notificacao do sistema (veja `public/sw.js`).
 *
 * Nao reaproveita o `useAlert`/Snackbar porque aquele fica no topo centro e
 * serve para retorno de acao ("Salvo!"): move-lo mudaria o app inteiro, e um
 * aviso de notificacao precisa de outra coisa - ser clicavel e levar ao assunto.
 */
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

const VISIBLE_DURATION = 6000;
// Acima disto o canto vira uma parede. Os mais antigos saem primeiro.
const MAX_VISIBLE = 3;

const router = useRouter();
const { t } = useI18n();

const notifications = ref([]);
const timers = new Map();

const clearTimer = id => {
  if (timers.has(id)) {
    clearTimeout(timers.get(id));
    timers.delete(id);
  }
};

const dismiss = id => {
  clearTimer(id);
  notifications.value = notifications.value.filter(item => item.id !== id);
};

const push = notification => {
  const { title, tag, url } = notification;

  if (!title) {
    return;
  }

  // O `tag` identifica o assunto: uma segunda mensagem da mesma conversa
  // substitui o aviso anterior em vez de empilhar mais um.
  const id = tag || `notification-${Date.now()}`;
  dismiss(id);

  notifications.value = [...notifications.value, { id, title, url }].slice(
    -MAX_VISIBLE
  );

  timers.set(
    id,
    setTimeout(() => dismiss(id), VISIBLE_DURATION)
  );
};

const open = notification => {
  dismiss(notification.id);

  if (!notification.url) {
    return;
  }

  try {
    const target = new URL(notification.url, window.location.origin);
    // Mesma instancia: navega pelo router, sem recarregar a aplicacao inteira.
    if (target.origin === window.location.origin) {
      router.push(`${target.pathname}${target.search}${target.hash}`);
      return;
    }
  } catch (error) {
    // URL malformada cai no desvio abaixo em vez de derrubar o clique.
  }

  window.location.href = notification.url;
};

const onServiceWorkerMessage = event => {
  if (event.data?.type === 'push_notification') {
    push(event.data.notification || {});
  }
};

onMounted(() => {
  if (!('serviceWorker' in navigator)) {
    return;
  }

  navigator.serviceWorker.addEventListener('message', onServiceWorkerMessage);
  // Sem isto nada chega: quem escuta por `addEventListener` (em vez de definir
  // `onmessage`) recebe as mensagens do service worker apenas enfileiradas, e e
  // o `startMessages` que abre a fila. Com `onmessage` a chamada e implicita -
  // mas ali so cabe um ouvinte, e o app perderia a chance de ter outro.
  navigator.serviceWorker.startMessages?.();
});

onBeforeUnmount(() => {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.removeEventListener(
      'message',
      onServiceWorkerMessage
    );
  }
  timers.forEach(timer => clearTimeout(timer));
  timers.clear();
});
</script>

<template>
  <div
    class="fixed z-50 flex flex-col items-end gap-2 pointer-events-none bottom-4 right-4 max-w-[22rem]"
  >
    <transition-group name="in-app-notification">
      <div
        v-for="notification in notifications"
        :key="notification.id"
        class="flex items-start w-full gap-3 px-4 py-3 border rounded-lg shadow-lg pointer-events-auto bg-n-solid-1 border-n-weak"
      >
        <button
          class="flex-1 text-sm font-medium text-left cursor-pointer text-n-slate-12 hover:text-n-brand"
          @click="open(notification)"
        >
          {{ notification.title }}
        </button>
        <button
          class="flex-shrink-0 cursor-pointer text-n-slate-10 hover:text-n-slate-12"
          :aria-label="t('IN_APP_NOTIFICATION.DISMISS')"
          :title="t('IN_APP_NOTIFICATION.DISMISS')"
          @click="dismiss(notification.id)"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </transition-group>
  </div>
</template>

<style scoped>
.in-app-notification-enter-active,
.in-app-notification-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

.in-app-notification-enter-from,
.in-app-notification-leave-to {
  opacity: 0;
  transform: translateY(0.5rem);
}

@media (prefers-reduced-motion: reduce) {
  .in-app-notification-enter-active,
  .in-app-notification-leave-active {
    transition: none;
  }
}
</style>
