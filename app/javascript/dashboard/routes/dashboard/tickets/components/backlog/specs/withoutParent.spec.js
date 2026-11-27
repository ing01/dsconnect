import { mount } from '@vue/test-utils';
import BacklogTicketRow from '../BacklogTicketRow.vue';
import TicketCard from '../../TicketCard.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const selo = '[data-testid="no-parent"]';
const global = {
  mocks: { $t: key => key },
  stubs: {
    Icon: true,
    Avatar: true,
    Checkbox: true,
    DropdownMenu: true,
    OnClickOutside: true,
  },
};
const ticket = parentId => ({
  id: 1,
  display_id: 38038,
  title: 'Erro na nota',
  status: 'open',
  parent_id: parentId,
});

describe('selo Sem ticket pai', () => {
  const linha = parentId =>
    mount(BacklogTicketRow, { props: { ticket: ticket(parentId) }, global });
  const cartao = (parentId, props = {}) =>
    mount(TicketCard, {
      props: { ticket: ticket(parentId), ...props },
      global,
    });

  it('aparece na linha do Backlog so de quem nao tem pai', () => {
    expect(linha(null).find(selo).exists()).toBe(true);
    expect(linha(9).find(selo).exists()).toBe(false);
  });

  it.each([false, true])(
    'aparece no cartao do Sprint ativo (compacto: %s)',
    compact => {
      const props = { markWithoutParent: true, compact };

      expect(cartao(null, props).find(selo).exists()).toBe(true);
      expect(cartao(9, props).find(selo).exists()).toBe(false);
    }
  );

  it('nao aparece nos outros quadros', () => {
    expect(cartao(null).find(selo).exists()).toBe(false);
  });
});
