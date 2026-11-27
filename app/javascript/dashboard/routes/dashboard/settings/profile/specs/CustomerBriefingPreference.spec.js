import { mount } from '@vue/test-utils';
import CustomerBriefingPreference from '../CustomerBriefingPreference.vue';

const settings = { value: {} };
const updateUISettings = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings: settings, updateUISettings }),
}));

const checkbox = () =>
  mount(CustomerBriefingPreference).find(
    '[data-testid="profile-briefing-auto-open"]'
  );

describe('Preferencia de abrir o Resumo do cliente', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    settings.value = {};
  });

  it('vem ligada', () => {
    expect(checkbox().element.checked).toBe(true);
  });

  it('mostra quando esta desligada', () => {
    settings.value = { customer_briefing_auto_open: false };

    expect(checkbox().element.checked).toBe(false);
  });

  it('permite ligar de novo', async () => {
    settings.value = { customer_briefing_auto_open: false };

    await checkbox().setValue(true);

    expect(updateUISettings).toHaveBeenCalledWith({
      customer_briefing_auto_open: true,
    });
  });
});
