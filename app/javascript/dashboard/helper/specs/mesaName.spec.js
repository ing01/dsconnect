import { formatMesaName } from '../mesaName';

describe('formatMesaName', () => {
  it('capitalizes the stored lowercase Mesa name', () => {
    expect(formatMesaName('suporte')).toBe('Suporte');
  });

  it('capitalizes every word', () => {
    expect(formatMesaName('mesa de suporte')).toBe('Mesa De Suporte');
  });

  it('preserves accented characters', () => {
    expect(formatMesaName('implantação')).toBe('Implantação');
  });

  it('is safe with empty or missing input', () => {
    expect(formatMesaName('')).toBe('');
    expect(formatMesaName()).toBe('');
    expect(formatMesaName(null)).toBe('');
  });
});
