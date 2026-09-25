/* global axios */
import ApiClient from './ApiClient';

class AttendanceWindows extends ApiClient {
  constructor() {
    super('attendance_windows', { accountScoped: true });
  }

  bulkUpdate(attendanceWindows) {
    return axios.post(`${this.url}/bulk_update`, {
      attendance_windows: attendanceWindows,
    });
  }
}

export default new AttendanceWindows();
