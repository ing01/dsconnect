import {
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek,
  startOfDay,
  endOfDay,
  eachDayOfInterval,
  parseISO,
  format,
  max,
  min,
  differenceInCalendarDays,
} from 'date-fns';

const WEEK_STARTS_ON = 1;

const chunk = (array, size) => {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
};

export const buildMonthGrid = referenceDate => {
  const monthStart = startOfMonth(referenceDate);
  const monthEnd = endOfMonth(referenceDate);
  const gridStart = startOfWeek(monthStart, { weekStartsOn: WEEK_STARTS_ON });
  const gridEnd = endOfWeek(monthEnd, { weekStartsOn: WEEK_STARTS_ON });
  const days = eachDayOfInterval({ start: gridStart, end: gridEnd });
  return { days, gridStart, gridEnd, weeks: chunk(days, 7) };
};

export const buildWeekDays = referenceDate => {
  const weekStart = startOfWeek(referenceDate, { weekStartsOn: WEEK_STARTS_ON });
  const weekEnd = endOfWeek(referenceDate, { weekStartsOn: WEEK_STARTS_ON });
  return eachDayOfInterval({ start: weekStart, end: weekEnd });
};

// An event is treated as "all day" for layout purposes whenever it's
// explicitly all_day, or it spans more than one calendar day - either way it
// renders as a bar above the hour grid, never split across the timeline.
export const isAllDayEvent = event =>
  event.all_day || differenceInCalendarDays(parseISO(event.end_at), parseISO(event.start_at)) >= 1;

// For every day in [gridStart, gridEnd], collects the events that occupy
// that day (single-day events land on exactly one day; multi-day events
// repeat on every day they cover). `end_at` is inclusive (end of the last
// day), matching the backend's storage convention.
export const groupEventsByDay = (events, gridStart, gridEnd) => {
  const map = new Map();
  eachDayOfInterval({ start: gridStart, end: gridEnd }).forEach(day => {
    map.set(format(day, 'yyyy-MM-dd'), []);
  });

  events.forEach(event => {
    const eventStart = parseISO(event.start_at);
    const eventEnd = parseISO(event.end_at);

    const spanStart = max([eventStart, gridStart]);
    const spanEnd = min([eventEnd, gridEnd]);
    if (spanStart > spanEnd) return;

    eachDayOfInterval({ start: startOfDay(spanStart), end: startOfDay(spanEnd) }).forEach(day => {
      const key = format(day, 'yyyy-MM-dd');
      if (!map.has(key)) return;
      map.get(key).push(event);
    });
  });

  map.forEach(list => {
    list.sort((a, b) => {
      if (isAllDayEvent(a) !== isAllDayEvent(b)) return isAllDayEvent(a) ? -1 : 1;
      return parseISO(a.start_at) - parseISO(b.start_at);
    });
  });

  return map;
};

export const visibleRangeFor = (view, referenceDate) => {
  if (view === 'month') {
    const { gridStart, gridEnd } = buildMonthGrid(referenceDate);
    return { since: startOfDay(gridStart), until: endOfDay(gridEnd) };
  }
  if (view === 'week') {
    const days = buildWeekDays(referenceDate);
    return { since: startOfDay(days[0]), until: endOfDay(days[days.length - 1]) };
  }
  return { since: startOfDay(referenceDate), until: endOfDay(referenceDate) };
};
