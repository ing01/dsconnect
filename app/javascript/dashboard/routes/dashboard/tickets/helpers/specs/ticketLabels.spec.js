import {
  LABEL_COLORS,
  STATUS_LABEL_COLORS,
  PRIORITY_LABEL_COLORS,
  statusColor,
  priorityColor,
} from '../ticketLabels';

describe('ticketLabels', () => {
  // The regression this pins: `green` and `violet` were used for months and
  // rendered badges with no background at all, because Label.vue silently
  // ignores a colour outside its own allow-list.
  it('only uses colours the Label component accepts', () => {
    const used = [
      ...Object.values(STATUS_LABEL_COLORS),
      ...Object.values(PRIORITY_LABEL_COLORS),
    ];

    used.forEach(color => expect(LABEL_COLORS).toContain(color));
  });

  it('gives every status its own colour', () => {
    expect(new Set(Object.values(STATUS_LABEL_COLORS)).size).toBe(3);
  });

  it('escalates priority colour from calm to alarming', () => {
    expect(PRIORITY_LABEL_COLORS.low).toBe('slate');
    expect(PRIORITY_LABEL_COLORS.urgent).toBe('ruby');
  });

  it('falls back to slate for unknown values', () => {
    expect(statusColor('nonsense')).toBe('slate');
    expect(priorityColor(null)).toBe('slate');
    expect(priorityColor(undefined)).toBe('slate');
  });

  it('resolves the known values', () => {
    expect(statusColor('resolved')).toBe('teal');
    expect(priorityColor('high')).toBe('amber');
  });
});
