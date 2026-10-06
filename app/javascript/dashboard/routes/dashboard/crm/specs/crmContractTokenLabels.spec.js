import {
  crmContractTokenLabel,
  CRM_LOCKED_CLIENT_TOKEN_KEYS,
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
