import {
  crmContractTokenLabel,
  CRM_LOCKED_CLIENT_TOKEN_KEYS,
  CRM_YES_NO_TOKEN_KEYS,
} from '../crmContractTokenLabels';

describe('crmContractTokenLabel', () => {
  it('devolve o rotulo curto de um token conhecido', () => {
    expect(crmContractTokenLabel('cliente_cep')).toBe('CEP do Cliente');
    expect(crmContractTokenLabel('representante_cpf')).toBe(
      'CPF do Representante'
    );
  });

  it('cai no proprio token (so com underline trocado por espaco) para um token desconhecido', () => {
    expect(crmContractTokenLabel('campo_customizado_do_modelo')).toBe(
      'campo customizado do modelo'
    );
  });
});

describe('CRM_LOCKED_CLIENT_TOKEN_KEYS', () => {
  it('tem exatamente os 5 tokens travados', () => {
    expect(CRM_LOCKED_CLIENT_TOKEN_KEYS).toEqual([
      'cliente_razao_social',
      'cliente_cnpj',
      'cliente_nome_fantasia',
      'cliente_email',
      'cliente_telefone',
    ]);
  });
});

// `renov_auto` e `reaj_anual_aut` sao marcadores DIFERENTES no modelo, nao o
// mesmo campo reaproveitado duas vezes - a confusao inicial (um unico token
// para as duas perguntas) foi corrigida depois que a Ingrid esclareceu.
describe('CRM_YES_NO_TOKEN_KEYS', () => {
  it('inclui os dois tokens de renovacao/reajuste como campos separados', () => {
    expect(CRM_YES_NO_TOKEN_KEYS).toContain('renov_auto');
    expect(CRM_YES_NO_TOKEN_KEYS).toContain('reaj_anual_aut');
  });

  it('tem exatamente os tokens que no modelo sao uma caixinha de Sim ou Nao', () => {
    expect(CRM_YES_NO_TOKEN_KEYS).toEqual([
      'renov_auto',
      'reaj_anual_aut',
      'impl_s_n',
      'impl_taxa_sn',
      'impl_trein_sn',
      'visitas_add_sn',
      'imp_dados_sn',
      'int_sn',
      'impl_cob_banc_sn',
    ]);
  });
});
