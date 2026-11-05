import axios from 'axios';
import conversationPendingCount from '../../conversationPendingCount';
import types from '../../../mutation-types';

const { getters, actions, mutations } = conversationPendingCount;

global.axios = axios;
vi.mock('axios');

describe('conversationPendingCount', () => {
  describe('#getters', () => {
    it('getPendingCount returns the stored count', () => {
      expect(getters.getPendingCount({ pendingCount: 5 })).toBe(5);
    });
  });

  describe('#mutations', () => {
    it('sets the count, coercing non-numeric values to 0', () => {
      const state = { pendingCount: 0 };
      mutations[types.SET_CONVERSATION_PENDING_COUNT](state, 7);
      expect(state.pendingCount).toBe(7);

      mutations[types.SET_CONVERSATION_PENDING_COUNT](state, undefined);
      expect(state.pendingCount).toBe(0);
    });
  });

  describe('#actions', () => {
    const commit = vi.fn();

    beforeEach(() => {
      commit.mockClear();
      axios.get.mockReset();
    });

    it('commits the pending count when the API succeeds', async () => {
      axios.get.mockResolvedValue({ data: { meta: { all_count: 3 } } });

      await actions.get({ commit });

      expect(commit).toHaveBeenCalledWith(
        types.SET_CONVERSATION_PENDING_COUNT,
        3
      );
    });

    it('does not commit when the API fails', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });

      await actions.get({ commit });

      expect(commit).not.toHaveBeenCalled();
    });
  });
});
