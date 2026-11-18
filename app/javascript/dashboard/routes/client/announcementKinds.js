/**
 * Cor e ícone de cada tipo de aviso do Mural. As classes são escritas por
 * extenso (e não montadas por template) para o Tailwind enxergá-las no build.
 */
export const ANNOUNCEMENT_KINDS = {
  info: {
    icon: 'i-lucide-info',
    card: 'bg-n-blue-3 border-n-blue-6',
    iconWrap: 'bg-n-blue-9 text-white',
  },
  warning: {
    icon: 'i-lucide-triangle-alert',
    card: 'bg-n-amber-3 border-n-amber-6',
    iconWrap: 'bg-n-amber-9 text-white',
  },
  success: {
    icon: 'i-lucide-circle-check',
    card: 'bg-n-teal-3 border-n-teal-6',
    iconWrap: 'bg-n-teal-9 text-white',
  },
  urgent: {
    icon: 'i-lucide-siren',
    card: 'bg-n-ruby-3 border-n-ruby-6',
    iconWrap: 'bg-n-ruby-9 text-white',
  },
};

// "18/11/2026" - a data do aviso, no formato do Portal (sempre pt-BR).
export const formatAnnouncementDate = iso => {
  if (!iso) return '';
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('pt-BR');
};

export const announcementKind = kind =>
  ANNOUNCEMENT_KINDS[kind] || ANNOUNCEMENT_KINDS.info;
