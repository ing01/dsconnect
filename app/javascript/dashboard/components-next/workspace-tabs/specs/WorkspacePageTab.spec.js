import { ref } from 'vue';
import { mount } from '@vue/test-utils';

import WorkspacePageTab from '../WorkspacePageTab.vue';

// O "!" na aba do topo: so nas telas de conversa e de chat interno, e so quando ha
// mensagem nao lida esperando.
const conversations = ref(false);
const internalChat = ref(false);

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useUnreadAlerts', () => ({
  useUnreadAlerts: () => ({ conversations, internalChat }),
}));

const montar = key =>
  mount(WorkspacePageTab, {
    props: { tab: { key, label: 'Aba', icon: 'i-lucide-inbox' } },
    global: { directives: { tooltip: () => {} } },
  });

const alerta = wrapper => wrapper.find('[data-testid="unread-alert"]');

describe('WorkspacePageTab, aviso de nao lida', () => {
  beforeEach(() => {
    conversations.value = false;
    internalChat.value = false;
  });

  it('sem aviso, a aba fica limpa', () => {
    expect(alerta(montar('home|[]')).exists()).toBe(false);
    expect(alerta(montar('internal_chat|[]')).exists()).toBe(false);
  });

  it('"Todas as conversas" mostra o ! quando ha conversa minha nao lida', () => {
    conversations.value = true;

    const wrapper = montar('home|[]');

    expect(alerta(wrapper).exists()).toBe(true);
    expect(alerta(wrapper).attributes('aria-label')).toBe(
      'SIDEBAR.UNREAD_ALERT.CONVERSATIONS'
    );
  });

  it('"Chat interno" mostra o ! quando ha mensagem nao lida', () => {
    internalChat.value = true;

    const wrapper = montar('internal_chat|[]');

    expect(alerta(wrapper).exists()).toBe(true);
    expect(alerta(wrapper).attributes('aria-label')).toBe(
      'SIDEBAR.UNREAD_ALERT.INTERNAL_CHAT'
    );
  });

  it('um aviso nao aparece na aba do outro', () => {
    conversations.value = true;

    expect(alerta(montar('internal_chat|[]')).exists()).toBe(false);

    conversations.value = false;
    internalChat.value = true;

    expect(alerta(montar('home|[]')).exists()).toBe(false);
  });

  it('outras telas nunca mostram o !', () => {
    conversations.value = true;
    internalChat.value = true;

    expect(alerta(montar('tickets_index|[]')).exists()).toBe(false);
  });
});
