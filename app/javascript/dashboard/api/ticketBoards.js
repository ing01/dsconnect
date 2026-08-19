/* global axios */

import ApiClient from './ApiClient';

class TicketBoardsAPI extends ApiClient {
  constructor() {
    super('ticket_boards', { accountScoped: true });
  }

  createColumn(boardId, data) {
    return axios.post(`${this.url}/${boardId}/ticket_columns`, {
      ticket_column: data,
    });
  }

  updateColumn(boardId, columnId, data) {
    return axios.patch(`${this.url}/${boardId}/ticket_columns/${columnId}`, {
      ticket_column: data,
    });
  }

  deleteColumn(boardId, columnId) {
    return axios.delete(`${this.url}/${boardId}/ticket_columns/${columnId}`);
  }

  reorderColumns(boardId, columnIds) {
    return axios.patch(`${this.url}/${boardId}/ticket_columns/reorder`, {
      column_ids: columnIds,
    });
  }
}

export default new TicketBoardsAPI();
