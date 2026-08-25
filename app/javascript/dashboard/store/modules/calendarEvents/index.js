import { getters } from './getters';
import { actions } from './actions';
import { mutations } from './mutations';

const state = {
  records: {},
  // Keyed by ticket, kept separate from `records` (keyed by team) so the
  // calendar page's getEventsByTeam contract stays untouched.
  ticketRecords: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
