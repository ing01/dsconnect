import axios from 'axios';
import conversationQueueCount from '../../conversationQueueCount';
import types from '../../../mutation-types';

const { getters, actions, mutations } = conversationQueueCount;

global.axios = axios;
vi.mock('axios');

describe('conversationQueueCount', () => {
  describe('#getters', () => {
    it('getQueueCount returns the stored count', () => {
      expect(getters.getQueueCount({ queueCount: 5 })).toBe(5);
    });
  });

  describe('#mutations', () => {
    it('sets the count, coercing non-numeric values to 0', () => {
      const state = { queueCount: 0 };
      mutations[types.SET_CONVERSATION_QUEUE_COUNT](state, 7);
      expect(state.queueCount).toBe(7);

      mutations[types.SET_CONVERSATION_QUEUE_COUNT](state, undefined);
      expect(state.queueCount).toBe(0);
    });
  });

  describe('#actions', () => {
    const commit = vi.fn();

    beforeEach(() => {
      commit.mockClear();
      axios.get.mockReset();
    });

    it('commits the queue count when the API succeeds', async () => {
      axios.get.mockResolvedValue({ data: { meta: { queue_count: 3 } } });

      await actions.get({ commit });

      expect(commit).toHaveBeenCalledWith(
        types.SET_CONVERSATION_QUEUE_COUNT,
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
