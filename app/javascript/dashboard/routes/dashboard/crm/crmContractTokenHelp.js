/**
 * Dicionario de referencia dos tokens `[[assim]]` usados nos modelos de
 * contrato - vem do mapeamento que a Ingrid fez a mao nos .docx. So' para
 * ajudar quem for mexer num modelo (ou criar um novo) a saber o que cada
 * marcador representa; o sistema em si nao depende deste arquivo para
 * funcionar - os tokens de verdade sao sempre os extraidos de cada modelo
 * (ver Crm::Contracts::TokenExtractorService no backend).
 *
 * Alguns tokens foram reaproveitados pela Ingrid para mais de um campo no
 * mesmo modelo (ex.: `cliente_endereco_num` serve tanto para "Numero do
 * endereco" quanto para "Bairro") - como e' o MESMO marcador, as duas
 * aparicoes no contrato saem com o mesmo texto. Isso fica anotado na
 * descricao de cada um desses.
 */
export const CRM_CONTRACT_TOKEN_HELP = {
  cliente_razao_social: 'Razão social do cliente',
  cliente_cnpj: 'CNPJ/CPF do cliente',
  cliente_nome_fantasia: 'Nome fantasia do cliente',
  cliente_inscricao_estadual: 'Inscrição estadual do cliente',
  cliente_endereco_rua: 'Endereço (rua/avenida) do cliente',
  cliente_endereco_num:
    'Número do endereço do cliente - ATENÇÃO: no modelo atual este mesmo token também aparece como "Bairro"; preencher aqui repete o mesmo texto nos dois lugares.',
  cliente_endereco_complemento: 'Complemento do endereço do cliente',
  cliente_cidade: 'Cidade do cliente',
  cliente_uf: 'UF do cliente',
  cliente_cep: 'CEP do cliente',
  cliente_telefone: 'Telefone do cliente',
  cliente_email: 'E-mail do cliente',
  representante_nome: 'Nome do representante legal',
  representante_cpf: 'CPF do representante legal',
  representante_dt_nasc:
    'Data de nascimento do representante - ATENÇÃO: no modelo atual este mesmo token também aparece como "Endereço do representante"; preencher aqui repete o mesmo texto nos dois lugares.',
  representante_end_num: 'Número do endereço do representante',
  representante_bairro: 'Bairro do representante',
  representante_end_complemento: 'Complemento do endereço do representante',
  representante_cidade: 'Cidade do representante',
  representante_uf: 'UF do representante',
  representante_cep: 'CEP do representante',
  representante_telefone:
    'Telefone do representante - ATENÇÃO: no modelo atual este mesmo token também aparece como "Celular do representante"; preencher aqui repete o mesmo texto nos dois lugares.',
  tipo_licenca: 'Tipo da licença: Anual ou Mensal',
  valor_licenca: 'Valor da licença',
  prazo_licenca: 'Prazo da licença',
  renov_auto:
    'Renovação automática (Sim/Não) - ATENÇÃO: no modelo atual este mesmo token também aparece como "Reajuste anual automático"; preencher aqui repete o mesmo texto nos dois lugares.',
  for_pag: 'Forma de pagamento',
  impl_s_n: 'Tem implantação? Sim ou Não',
  impl_prazo: 'Prazo previsto para a implantação',
  impl_taxa_sn: 'Tem taxa de implantação? Sim ou Não',
  impl_valor: 'Valor da taxa de implantação',
  impl_cond_pagto: 'Condição de pagamento da implantação',
  impl_trein_sn: 'Tem treino de uso do sistema? Sim ou Não',
  qtde_licencas: 'Quantidade de licenças',
  horas_trein: 'Horas de treinamento',
  visitas_add_sn: 'Tem visitas adicionais? Sim ou Não',
  vl_hr_add: 'Valor da hora de visita adicional',
  valor_km: 'Valor do km rodado',
  imp_dados_sn: 'Tem importação de dados? Sim ou Não',
  int_sn: 'Tem integrações? Sim ou Não',
  impl_cob_banc_sn:
    'Tem implantação de cobrança bancária? Sim ou Não - ATENÇÃO: no modelo atual este mesmo token também aparece como "Servidor em nuvem"; preencher aqui repete o mesmo texto nos dois lugares.',
};

export const crmContractTokenDescription = token =>
  CRM_CONTRACT_TOKEN_HELP[token] || null;
