<script setup>
/**
 * O modal do Mural de Avisos: a cada login, enquanto o aviso estiver dentro do
 * período, ele abre por cima da tela e a pessoa precisa fechá-lo ("Entendi")
 * antes de seguir. Com mais de um aviso, aparecem um de cada vez.
 *
 * "Visto" vale só para esta sessão (ver `clientSession.js`): entrar de novo
 * mostra o aviso outra vez, até o fim do período.
 *
 * Não fecha por Esc nem por clique fora, de propósito - o objetivo é garantir
 * que o aviso foi visto. O texto é renderizado como TEXTO (nunca HTML).
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useClientAnnouncements } from 'dashboard/composables/useClientAnnouncements';
import {
  getSeenAnnouncementIds,
  markAnnouncementSeen,
} from 'dashboard/helper/clientSession';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { announcementKind } from '../announcementKinds';

const { t } = useI18n({ useScope: 'global' });
const { announcements, load } = useClientAnnouncements();

// Os já vistos nesta sessão; reativo para a fila andar ao clicar em "Entendi".
const seenIds = ref(getSeenAnnouncementIds());

const queue = computed(() =>
  announcements.value.filter(item => !seenIds.value.includes(item.id))
);
const current = computed(() => queue.value[0] || null);
const style = computed(() => announcementKind(current.value?.kind));

// A lista em memória avança mesmo que o armazenamento do navegador esteja
// bloqueado (aí só não persiste entre telas recarregadas).
const onDismiss = () => {
  if (!current.value) return;
  markAnnouncementSeen(current.value.id);
  seenIds.value = [...seenIds.value, current.value.id];
};

onMounted(() => load());
</script>

<template>
  <Teleport to="body">
    <div
      v-if="current"
      class="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-n-slate-12/60"
      role="dialog"
      aria-modal="true"
      :aria-label="current.title"
      data-testid="announcement-dialog"
    >
      <div
        class="flex flex-col w-full max-w-lg gap-4 p-6 border shadow-xl rounded-2xl bg-n-solid-2 max-h-[90vh] overflow-y-auto"
        :class="style.card"
      >
        <div class="flex items-start gap-3">
          <span
            class="flex items-center justify-center flex-shrink-0 rounded-full size-10"
            :class="style.iconWrap"
          >
            <Icon :icon="style.icon" class="size-5" />
          </span>
          <div class="flex flex-col min-w-0 gap-1">
            <span class="text-xs font-medium uppercase text-n-slate-11">
              {{ t(`CLIENT_AREA.ANNOUNCEMENTS.KIND.${current.kind}`) }}
              <template v-if="queue.length > 1">
                ·
                {{
                  t('CLIENT_AREA.ANNOUNCEMENTS.REMAINING', {
                    count: queue.length - 1,
                  })
                }}
              </template>
            </span>
            <h2
              class="m-0 text-lg font-semibold break-words text-n-slate-12"
              data-testid="announcement-title"
            >
              {{ current.title }}
            </h2>
          </div>
        </div>

        <p
          v-if="current.body"
          class="m-0 text-sm break-words whitespace-pre-line text-n-slate-12"
        >
          {{ current.body }}
        </p>

        <div class="flex flex-wrap justify-end gap-2">
          <a
            v-if="current.link_url"
            :href="current.link_url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1 px-3 text-sm font-medium rounded-lg h-8 text-n-brand bg-n-alpha-2 hover:bg-n-alpha-3"
          >
            {{ current.link_label || t('CLIENT_AREA.ANNOUNCEMENTS.OPEN_LINK') }}
            <Icon icon="i-lucide-external-link" class="size-3.5" />
          </a>
          <Button
            size="sm"
            :label="
              queue.length > 1
                ? t('CLIENT_AREA.ANNOUNCEMENTS.NEXT')
                : t('CLIENT_AREA.ANNOUNCEMENTS.UNDERSTOOD')
            "
            data-testid="announcement-dismiss"
            @click="onDismiss"
          />
        </div>
      </div>
    </div>
  </Teleport>
</template>
