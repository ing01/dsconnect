import { startOfDay, addHours, addMinutes, parseISO, differenceInMinutes, max, min } from 'date-fns';
import { MIN_EVENT_DURATION_MINUTES } from '../constants';

// Converts an event's start/end into a top/height (px) position within a
// single day's column, clipping to that day's [dayStartHour, dayEndHour)
// window - this is what makes an event crossing midnight render (clipped)
// in both the day-before and day-after columns without splitting the
// underlying data.
export const eventToPosition = (event, day, { hourHeight, dayStartHour, dayEndHour }) => {
  const dayStart = addHours(startOfDay(day), dayStartHour);
  const dayEnd = addHours(startOfDay(day), dayEndHour);

  const eventStart = parseISO(event.start_at);
  const eventEnd = parseISO(event.end_at);

  const clippedStart = max([eventStart, dayStart]);
  const clippedEnd = min([eventEnd, dayEnd]);

  const pxPerMinute = hourHeight / 60;
  const minutesFromDayStart = differenceInMinutes(clippedStart, dayStart);
  const minutesDuration = Math.max(
    differenceInMinutes(clippedEnd, clippedStart),
    MIN_EVENT_DURATION_MINUTES
  );

  return {
    event,
    top: minutesFromDayStart * pxPerMinute,
    height: minutesDuration * pxPerMinute,
    clippedAtStart: clippedStart.getTime() !== eventStart.getTime(),
    clippedAtEnd: clippedEnd.getTime() !== eventEnd.getTime(),
  };
};

// Classic calendar column-packing: events that overlap in time are grouped
// into a cluster, each event claims the first column whose previous
// occupant has already ended, and the cluster's columns split the width
// evenly. Returns the same items with `left`/`width` (percent) added.
export const computeOverlapLayout = positionedEvents => {
  const sorted = [...positionedEvents].sort((a, b) => a.top - b.top);

  const clusters = [];
  let currentCluster = [];
  let clusterMaxEnd = -Infinity;

  sorted.forEach(item => {
    const itemStart = item.top;
    const itemEnd = item.top + item.height;

    if (currentCluster.length === 0 || itemStart < clusterMaxEnd) {
      currentCluster.push(item);
      clusterMaxEnd = Math.max(clusterMaxEnd, itemEnd);
    } else {
      clusters.push(currentCluster);
      currentCluster = [item];
      clusterMaxEnd = itemEnd;
    }
  });
  if (currentCluster.length) clusters.push(currentCluster);

  const results = [];

  clusters.forEach(cluster => {
    const columnEnds = [];

    cluster.forEach(item => {
      const itemStart = item.top;
      const itemEnd = item.top + item.height;

      let columnIndex = columnEnds.findIndex(colEnd => colEnd <= itemStart);
      if (columnIndex === -1) {
        columnIndex = columnEnds.length;
        columnEnds.push(itemEnd);
      } else {
        columnEnds[columnIndex] = itemEnd;
      }
      item.columnIndex = columnIndex;
    });

    const columnCount = columnEnds.length;

    cluster.forEach(item => {
      results.push({
        ...item,
        left: (item.columnIndex / columnCount) * 100,
        width: (1 / columnCount) * 100,
      });
    });
  });

  return results;
};

// Snaps a click offset (px from the top of a day column) to the nearest
// 15-minute mark and returns the resulting Date for that day/column.
export const slotClickToDate = (day, offsetY, { hourHeight, dayStartHour }) => {
  const minutesFromDayStart = Math.floor(offsetY / (hourHeight / 60));
  const snapped = Math.round(minutesFromDayStart / 15) * 15;
  return addMinutes(addHours(startOfDay(day), dayStartHour), snapped);
};
