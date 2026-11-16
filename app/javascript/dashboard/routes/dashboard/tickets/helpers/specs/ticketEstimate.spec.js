import {
  formatEstimateHours,
  sumEstimateHours,
  ticketEstimateHours,
} from '../ticketEstimate';

const withEstimate = value => ({
  custom_attributes: { estimativa_original_horas: value },
});

describe('ticketEstimate', () => {
  it('reads numbers and text, and treats anything else as zero', () => {
    expect(ticketEstimateHours(withEstimate(6))).toBe(6);
    expect(ticketEstimateHours(withEstimate('2,5'))).toBe(2.5);
    expect(ticketEstimateHours(withEstimate('abc'))).toBe(0);
    expect(ticketEstimateHours(withEstimate(null))).toBe(0);
    expect(ticketEstimateHours({})).toBe(0);
    expect(ticketEstimateHours(undefined)).toBe(0);
  });

  it('sums only what the list contains', () => {
    const tickets = [withEstimate(6), withEstimate('2,5'), {}];

    expect(sumEstimateHours(tickets)).toBe(8.5);
    expect(sumEstimateHours([])).toBe(0);
    expect(sumEstimateHours(undefined)).toBe(0);
  });

  it('formats without trailing zeros and with a decimal comma', () => {
    expect(formatEstimateHours(6)).toBe('6');
    expect(formatEstimateHours(2.5)).toBe('2,5');
    expect(formatEstimateHours(0.1 + 0.2)).toBe('0,3');
    expect(formatEstimateHours(0)).toBe('0');
  });
});
