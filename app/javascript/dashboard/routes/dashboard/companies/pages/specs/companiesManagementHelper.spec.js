import {
  CLEAR_VALUE,
  buildBulkChanges,
  buildFilterParams,
} from '../companiesManagementHelper';

const emptyBulk = () => ({
  status: '',
  classificationLevel: '',
  companyNicheId: '',
  companySubNicheId: '',
  specialistId: '',
  billingType: '',
  modules: [],
  modulesMode: 'add',
});

describe('companiesManagementHelper', () => {
  describe('buildBulkChanges', () => {
    it('nao manda nada quando nenhum campo foi escolhido', () => {
      expect(buildBulkChanges(emptyBulk())).toEqual({});
    });

    it('manda so os campos escolhidos', () => {
      const changes = buildBulkChanges({
        ...emptyBulk(),
        status: 'inactive',
        companyNicheId: 7,
        classificationLevel: 3,
      });

      expect(changes).toEqual({
        status: 'inactive',
        company_niche_id: 7,
        classification_level: 3,
      });
    });

    it('"limpar campo" vai como valor vazio, diferente de "nao alterar"', () => {
      const changes = buildBulkChanges({
        ...emptyBulk(),
        specialistId: CLEAR_VALUE,
        companySubNicheId: CLEAR_VALUE,
        classificationLevel: CLEAR_VALUE,
      });

      expect(changes).toEqual({
        specialist_id: '',
        company_sub_niche_id: '',
        classification_level: '',
      });
    });

    it('os modulos levam o modo (adicionar, remover ou substituir)', () => {
      expect(
        buildBulkChanges({
          ...emptyBulk(),
          modules: [1, 2],
          modulesMode: 'remove',
        })
      ).toEqual({ system_module_ids: [1, 2], modules_mode: 'remove' });
    });

    it('sem modulo marcado o modo nao e enviado', () => {
      expect(
        buildBulkChanges({ ...emptyBulk(), modulesMode: 'replace' })
      ).toEqual({});
    });

    it('envia o tipo de cobranca', () => {
      expect(
        buildBulkChanges({ ...emptyBulk(), billingType: 'annual' })
      ).toEqual({ billing_type: 'annual' });
    });
  });

  describe('buildFilterParams', () => {
    it('leva so os filtros preenchidos, no formato da API', () => {
      expect(
        buildFilterParams({
          q: ' acme ',
          status: 'active',
          classificationLevel: '',
          companyNicheId: 4,
          companySubNicheId: '',
          specialistId: '',
        })
      ).toEqual({ q: 'acme', status: 'active', company_niche_id: 4 });
    });

    it('sem filtro nenhum devolve objeto vazio', () => {
      expect(buildFilterParams({ q: '  ' })).toEqual({});
    });
  });
});
