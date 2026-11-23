import { toSearchParams } from '../ticketSearchParams';

describe('toSearchParams', () => {
  it('leva nicho, subnicho e nivel da empresa para a API', () => {
    const params = toSearchParams({
      companyNicheIds: [1, 2],
      companySubNicheIds: [9],
      companyLevels: [4, 5],
    });

    expect(params.company_niche_id).toEqual([1, 2]);
    expect(params.company_sub_niche_id).toEqual([9]);
    expect(params.company_classification_level).toEqual([4, 5]);
  });

  it('lista vazia e o mesmo que nenhum filtro', () => {
    const params = toSearchParams({
      companyNicheIds: [],
      companySubNicheIds: [],
      companyLevels: [],
    });

    expect(params.company_niche_id).toBeUndefined();
    expect(params.company_sub_niche_id).toBeUndefined();
    expect(params.company_classification_level).toBeUndefined();
  });
});
