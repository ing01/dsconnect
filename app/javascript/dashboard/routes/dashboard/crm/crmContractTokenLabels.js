/**
 * Rótulo CURTO de cada token `[[assim]]` - usado como label do campo na
 * tela de geração de contrato (ver `CrmContractsPage.vue`), formatado como
 * "CEP do Cliente (cliente_cep)". Vem direto dos nomes que a Ingrid deu a
 * cada campo quando listou os tokens do modelo.
 *
 * Diferente de `CRM_CONTRACT_TOKEN_HELP` (frases explicativas, usadas só no
 * diálogo de ajuda) - aqui é só o nome do campo, curto, para caber no
 * formulário.
 */
export const CRM_CONTRACT_TOKEN_LABELS = {
  cliente_razao_social: 'Razão Social',
  cliente_cnpj: 'CNPJ/CPF',
  cliente_nome_fantasia: 'Nome Fantasia',
  cliente_inscricao_estadual: 'Inscrição Estadual',
  cliente_endereco_rua: 'Endereço',
  cliente_endereco_num: 'Número do Endereço',
  cliente_endereco_complemento: 'Complemento',
  cliente_cidade: 'Cidade',
  cliente_uf: 'UF',
  cliente_cep: 'CEP do Cliente',
  cliente_telefone: 'Telefone do Cliente',
  cliente_email: 'E-mail do Cliente',
  representante_nome: 'Nome do Representante',
  representante_cpf: 'CPF do Representante',
  representante_dt_nasc: 'Data de Nascimento do Representante',
  representante_end_num: 'Número do Endereço do Representante',
  representante_bairro: 'Bairro do Representante',
  representante_end_complemento: 'Complemento do Endereço do Representante',
  representante_cidade: 'Cidade do Representante',
  representante_uf: 'UF do Representante',
  representante_cep: 'CEP do Representante',
  representante_telefone: 'Telefone/Celular do Representante',
  tipo_licenca: 'Tipo da Licença',
  valor_licenca: 'Valor da Licença',
  prazo_licenca: 'Prazo da Licença',
  renov_auto: 'Renovação/Reajuste Automático',
  for_pag: 'Forma de Pagamento',
  impl_s_n: 'Tem Implantação',
  impl_prazo: 'Prazo da Implantação',
  impl_taxa_sn: 'Tem Taxa de Implantação',
  impl_valor: 'Valor da Taxa de Implantação',
  impl_cond_pagto: 'Condição de Pagamento da Implantação',
  impl_trein_sn: 'Tem Treinamento',
  qtde_licencas: 'Quantidade de Licenças',
  horas_trein: 'Horas de Treinamento',
  visitas_add_sn: 'Tem Visitas Adicionais',
  vl_hr_add: 'Valor da Visita Adicional (hora)',
  valor_km: 'Valor do KM Rodado',
  imp_dados_sn: 'Tem Importação de Dados',
  int_sn: 'Tem Integrações',
  impl_cob_banc_sn: 'Implantação de Cobrança Bancária/Servidor em Nuvem',
};

// Cai no proprio token (so' mais legivel) se for um campo de um modelo
// customizado, sem entrada aqui - nunca quebra por um token desconhecido.
export const crmContractTokenLabel = token =>
  CRM_CONTRACT_TOKEN_LABELS[token] || token.replace(/_/g, ' ');

// Espelha Crm::ContractTokenMapper::LOCKED_CLIENT_TOKEN_KEYS no backend -
// esses 5 tokens sempre vem do cadastro do cliente selecionado e por isso
// nunca aparecem como campo editavel na tela de geração (ver
// `CrmContractsPage.vue`); o backend trava isso de verdade, isto aqui é só
// para não oferecer um campo que a edição nunca vai valer.
export const CRM_LOCKED_CLIENT_TOKEN_KEYS = [
  'cliente_razao_social',
  'cliente_cnpj',
  'cliente_nome_fantasia',
  'cliente_email',
  'cliente_telefone',
];
