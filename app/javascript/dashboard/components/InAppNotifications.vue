<script setup>
/**
 * Avisos exibidos dentro da propria pagina, no canto inferior direito.
 *
 * A origem e a mesma notificacao push de sempre: o service worker decide, a
 * cada evento, se a janela esta em foco. Se estiver, ele manda o conteudo para
 * ca em vez de abrir a notificacao do sistema (veja `public/sw.js`).
 *
 * O aviso FICA ATE A PESSOA AGIR - nao some sozinho. Por isso o agrupamento por
 * assunto importa: sem ele, dez mensagens da mesma conversa virariam dez cards
 * parados na tela. O servidor manda uma etiqueta por conversa/sala, e a mensagem
 * seguinte substitui o aviso anterior.
 *
 * Nao reaproveita o `useAlert`/Snackbar porque aquele fica no topo centro, some
 * em segundos e serve para retorno de acao ("Salvo!"): aqui e o oposto disso.
 */
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

const router = useRouter();
const store = useStore();
const { t } = useI18n();

const notifications = ref([]);

const dismiss = tag => {
  notifications.value = notifications.value.filter(item => item.tag !== tag);
};

const push = notification => {
  const { title, body, tag, url, id } = notification;

  if (!title || !tag) {
    return;
  }

  // O payload vem do servidor em snake_case, direto do JSON do push - nao passa
  // por nenhuma camada que converta nomes, como acontece nas respostas da API.
  const item = {
    tag,
    title,
    body,
    url,
    id,
    primaryActorType: notification.primary_actor_type,
    primaryActorId: notification.primary_actor_id,
  };
  const index = notifications.value.findIndex(entry => entry.tag === tag);

  // Mesma conversa: substitui no lugar, para o card nao pular para o fim da
  // pilha e mover os botoes debaixo do cursor de quem ia clicar.
  if (index === -1) {
    notifications.value = [...notifications.value, item];
  } else {
    notifications.value = notifications.value.map((entry, position) =>
      position === index ? item : entry
    );
  }
};

const open = notification => {
  dismiss(notification.tag);

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

const markAsRead = async notification => {
  // Tira da tela antes da resposta: quem clicou ja decidiu, e deixar o card
  // parado esperando a rede passaria a impressao de que o clique falhou. A acao
  // do store engole o proprio erro e o aviso volta na proxima mensagem.
  dismiss(notification.tag);

  if (!notification.id) {
    return;
  }

  await store.dispatch('notifications/read', {
    id: notification.id,
    primaryActorType: notification.primaryActorType,
    primaryActorId: notification.primaryActorId,
  });
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
});
</script>

<template>
  <div
    class="fixed z-50 flex flex-col items-end gap-2 pointer-events-none bottom-4 right-4 max-w-[22rem] max-h-[70vh] overflow-y-auto"
  >
    <transition-group name="in-app-notification">
      <div
        v-for="notification in notifications"
        :key="notification.tag"
        class="flex flex-col w-full gap-3 px-4 py-3 border rounded-lg shadow-lg pointer-events-auto bg-n-solid-1 border-n-weak"
      >
        <div class="flex flex-col gap-1">
          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ notification.title }}
          </p>
          <p
            v-if="notification.body"
            class="m-0 text-sm whitespace-pre-line line-clamp-3 text-n-slate-11"
          >
            {{ notification.body }}
          </p>
        </div>
        <div class="flex items-center gap-2">
          <button
            class="px-3 py-1 text-sm font-medium rounded-md cursor-pointer text-n-slate-12 bg-n-alpha-2 hover:bg-n-alpha-3"
            @click="open(notification)"
          >
            {{ t('IN_APP_NOTIFICATION.OPEN') }}
          </button>
          <button
            class="px-3 py-1 text-sm font-medium rounded-md cursor-pointer text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            @click="markAsRead(notification)"
          >
            {{ t('IN_APP_NOTIFICATION.MARK_AS_READ') }}
          </button>
        </div>
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
