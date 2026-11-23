/**
 * As três faixas do painel. Classes escritas por extenso (e não montadas por
 * template) para o Tailwind enxergá-las. Cor nunca é o único sinal: cada faixa
 * tem ícone e nome próprios.
 */
export const BANDS = {
  green: {
    key: 'green',
    i18n: 'GREEN',
    icon: 'i-lucide-headset',
    card: 'bg-n-teal-3 border-n-teal-6',
    cardActive: 'ring-2 ring-n-teal-9',
    iconWrap: 'bg-n-teal-9 text-white',
    number: 'text-n-teal-11',
    bar: 'bg-n-teal-9',
    row: 'border-l-n-teal-9',
  },
  orange: {
    key: 'orange',
    i18n: 'ORANGE',
    icon: 'i-lucide-hourglass',
    card: 'bg-n-amber-3 border-n-amber-6',
    cardActive: 'ring-2 ring-n-amber-9',
    iconWrap: 'bg-n-amber-9 text-white',
    number: 'text-n-amber-11',
    bar: 'bg-n-amber-9',
    row: 'border-l-n-amber-9',
  },
  red: {
    key: 'red',
    i18n: 'RED',
    icon: 'i-lucide-siren',
    card: 'bg-n-ruby-3 border-n-ruby-6',
    cardActive: 'ring-2 ring-n-ruby-9',
    iconWrap: 'bg-n-ruby-9 text-white',
    number: 'text-n-ruby-11',
    bar: 'bg-n-ruby-9',
    row: 'border-l-n-ruby-9',
  },
};

export const BAND_KEYS = ['green', 'orange', 'red'];
