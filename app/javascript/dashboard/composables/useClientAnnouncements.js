import { ref } from 'vue';
import ClientAreaAPI from 'dashboard/api/clientArea';

// Estado compartilhado: o modal (ClientLayout) e o Mural (Principal) leem a
// mesma lista, e o servidor só é consultado uma vez por carga da página.
const announcements = ref([]);
const isLoaded = ref(false);
let inflight = null;

export const useClientAnnouncements = () => {
  const load = ({ force = false } = {}) => {
    if (isLoaded.value && !force) return Promise.resolve(announcements.value);
    if (inflight) return inflight;

    inflight = ClientAreaAPI.announcements()
      .then(({ data }) => {
        announcements.value = data.announcements || [];
        isLoaded.value = true;
        return announcements.value;
      })
      .catch(() => {
        // Falhar o Mural não pode travar o resto do Portal: segue sem avisos
        // e tenta de novo na próxima carga.
        announcements.value = [];
        return announcements.value;
      })
      .finally(() => {
        inflight = null;
      });
    return inflight;
  };

  return { announcements, isLoaded, load };
};
