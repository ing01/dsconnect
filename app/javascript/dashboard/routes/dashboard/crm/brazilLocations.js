/**
 * Lista de UFs do Brasil + busca de cidades por UF via API publica do IBGE
 * (sem manter uma lista de ~5570 municipios dentro do bundle do frontend).
 * Usado nos campos de UF/Cidade do cadastro de cliente (CrmClientsPage.vue)
 * e da geracao de contrato (CrmContractsPage.vue): ao escolher a UF, a
 * cidade passa a oferecer sugestoes (via <datalist>) so' daquele estado.
 */
export const BRAZIL_STATES = [
  { uf: 'AC', name: 'Acre' },
  { uf: 'AL', name: 'Alagoas' },
  { uf: 'AP', name: 'Amapá' },
  { uf: 'AM', name: 'Amazonas' },
  { uf: 'BA', name: 'Bahia' },
  { uf: 'CE', name: 'Ceará' },
  { uf: 'DF', name: 'Distrito Federal' },
  { uf: 'ES', name: 'Espírito Santo' },
  { uf: 'GO', name: 'Goiás' },
  { uf: 'MA', name: 'Maranhão' },
  { uf: 'MT', name: 'Mato Grosso' },
  { uf: 'MS', name: 'Mato Grosso do Sul' },
  { uf: 'MG', name: 'Minas Gerais' },
  { uf: 'PA', name: 'Pará' },
  { uf: 'PB', name: 'Paraíba' },
  { uf: 'PR', name: 'Paraná' },
  { uf: 'PE', name: 'Pernambuco' },
  { uf: 'PI', name: 'Piauí' },
  { uf: 'RJ', name: 'Rio de Janeiro' },
  { uf: 'RN', name: 'Rio Grande do Norte' },
  { uf: 'RS', name: 'Rio Grande do Sul' },
  { uf: 'RO', name: 'Rondônia' },
  { uf: 'RR', name: 'Roraima' },
  { uf: 'SC', name: 'Santa Catarina' },
  { uf: 'SP', name: 'São Paulo' },
  { uf: 'SE', name: 'Sergipe' },
  { uf: 'TO', name: 'Tocantins' },
];

// Mesmo formato {value, label} que o componente `Select` do design system
// espera (`dashboard/components-next/select/Select.vue`).
export const BRAZIL_STATE_OPTIONS = BRAZIL_STATES.map(({ uf }) => ({
  value: uf,
  label: uf,
}));

// Cache em memoria (dura so' a navegacao na pagina) - evita rebuscar a mesma
// UF varias vezes quando ela aparece em mais de um campo da tela (cliente e
// representante, por exemplo).
const cityCache = {};

export const fetchCitiesByUf = async uf => {
  if (!uf) return [];
  if (cityCache[uf]) return cityCache[uf];
  try {
    const response = await fetch(
      `https://servicodados.ibge.gov.br/api/v1/localidades/estados/${uf}/municipios`
    );
    const data = await response.json();
    const names = data
      .map(city => city.nome)
      .sort((a, b) => a.localeCompare(b, 'pt-BR'));
    cityCache[uf] = names;
    return names;
  } catch {
    // Sem internet ou API do IBGE fora do ar - o campo de cidade continua
    // funcionando como texto livre, so' sem sugestao.
    return [];
  }
};
