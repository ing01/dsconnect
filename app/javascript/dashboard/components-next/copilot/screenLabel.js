// Nome da tela, para o historico do DueBot ("Chat aberto na tela Agenda").
// Recebe o nome da rota (`route.name`) e devolve a chave de traducao da tela;
// nome que nao estiver na lista cai em `null` e quem chama mostra o proprio nome.
const RULES = [
  [/^(home|inbox_dashboard)$/, 'HOME'],
  [/^tickets_backlog$/, 'BACKLOG'],
  [/^tickets_triage$/, 'TRIAGE'],
  [/^(tickets_index|ticket_detail)$/, 'TICKETS'],
  [/^agenda/, 'AGENDA'],
  [/^companies_/, 'COMPANIES'],
  [/^contacts_/, 'CONTACTS'],
  [/^(contracts_|crm_contracts)/, 'CONTRACTS'],
  [/^crm_/, 'COMMERCIAL'],
  [/^internal_chat/, 'INTERNAL_CHAT'],
  [/^principal$/, 'PRINCIPAL'],
  [/^manifestation/, 'MANIFESTATIONS'],
  [/^project/, 'PROJECTS'],
  [/^campaigns_/, 'CAMPAIGNS'],
  [/^portals_/, 'HELP_CENTER'],
  [/^inbox_view/, 'NOTIFICATIONS'],
  [/^calls_/, 'CALLS'],
  [/^captain_/, 'AI'],
  [/report/, 'REPORTS'],
  [
    /^(settings_|ticket_.*settings|profile_settings)|_settings|_list$/,
    'SETTINGS',
  ],
];

export const screenLabelKey = routeName => {
  const name = String(routeName || '');
  const rule = RULES.find(([pattern]) => pattern.test(name));
  return rule ? `CAPTAIN.COPILOT.SCREENS.${rule[1]}` : null;
};

// "agenda_index" -> "agenda index": melhor que esconder a origem.
export const humanizeRouteName = routeName =>
  String(routeName || '')
    .replace(/_/g, ' ')
    .trim();
