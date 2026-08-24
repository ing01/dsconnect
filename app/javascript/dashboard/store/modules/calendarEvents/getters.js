export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getEventsByTeam: $state => teamId => {
    return $state.records[teamId] || [];
  },
};
