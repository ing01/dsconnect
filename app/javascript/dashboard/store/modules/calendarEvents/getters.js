export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getEventsByTeam: $state => teamId => {
    return $state.records[teamId] || [];
  },
  getEventsByTicket: $state => ticketId => {
    return $state.ticketRecords[ticketId] || [];
  },
};
