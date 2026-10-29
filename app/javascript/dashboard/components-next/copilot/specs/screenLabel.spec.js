import { humanizeRouteName, screenLabelKey } from '../screenLabel';

describe('screenLabelKey', () => {
  it.each([
    ['home', 'HOME'],
    ['agenda_index', 'AGENDA'],
    ['tickets_backlog', 'BACKLOG'],
    ['companies_dashboard_show', 'COMPANIES'],
    ['contacts_edit', 'CONTACTS'],
    ['crm_contracts_index', 'CONTRACTS'],
    ['crm_sales_index', 'COMMERCIAL'],
    ['internal_chat', 'INTERNAL_CHAT'],
    ['agent_reports_show', 'REPORTS'],
    ['settings_teams_list', 'SETTINGS'],
  ])('%s -> %s', (name, key) => {
    expect(screenLabelKey(name)).toBe(`CAPTAIN.COPILOT.SCREENS.${key}`);
  });

  it('devolve null para rota desconhecida e humaniza o nome', () => {
    expect(screenLabelKey('rota_nova_qualquer')).toBeNull();
    expect(humanizeRouteName('rota_nova_qualquer')).toBe('rota nova qualquer');
  });
});
