// Regras da tela de Gestao de clientes que nao dependem de tela: montar o que a
// API espera a partir do que foi escolhido no painel de alteracao em massa.

export const LEVELS = [1, 2, 3, 4, 5];

// Valor do <select> que significa "limpar o campo" (diferente de "nao alterar",
// que e' o vazio).
export const CLEAR_VALUE = '__clear__';

const asId = value => (value === CLEAR_VALUE ? '' : Number(value));

/**
 * Converte o painel em `changes` para a API. Campo em branco = nao mexer
 * (fica de fora); CLEAR_VALUE = limpar (vai vazio).
 */
export const buildBulkChanges = bulk => {
  const changes = {};

  if (bulk.status) changes.status = bulk.status;
  if (bulk.billingType) changes.billing_type = bulk.billingType;
  if (bulk.classificationLevel !== '') {
    changes.classification_level = asId(bulk.classificationLevel);
  }
  if (bulk.companyNicheId !== '') {
    changes.company_niche_id = asId(bulk.companyNicheId);
  }
  if (bulk.companySubNicheId !== '') {
    changes.company_sub_niche_id = asId(bulk.companySubNicheId);
  }
  if (bulk.specialistId !== '') {
    changes.specialist_id = asId(bulk.specialistId);
  }
  if (bulk.modules?.length) {
    changes.system_module_ids = bulk.modules;
    changes.modules_mode = bulk.modulesMode || 'add';
  }

  return changes;
};

/** Filtros da lista no formato da API, so os preenchidos (para `select_all`). */
export const buildFilterParams = filters => {
  const params = {
    q: filters.q?.trim(),
    status: filters.status,
    classification_level: filters.classificationLevel,
    company_niche_id: filters.companyNicheId,
    company_sub_niche_id: filters.companySubNicheId,
    specialist_id: filters.specialistId,
  };
  return Object.fromEntries(
    Object.entries(params).filter(([, value]) => value !== '' && value != null)
  );
};
