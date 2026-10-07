/**
 * Mascara simples de telefone/celular BR - formata "(11) 98888-7777" (ou
 * "(11) 8888-7777" pra fixo) enquanto a pessoa digita, e corta a quantidade
 * de numeros (11 pro celular, 10 pro fixo) pra nao dar pra digitar ou colar
 * um numero maior/menor que o formato certo.
 */
export const formatBrPhone = (value, { mobile = false } = {}) => {
  const digits = String(value || '')
    .replace(/\D/g, '')
    .slice(0, mobile ? 11 : 10);
  const ddd = digits.slice(0, 2);
  const rest = digits.slice(2);
  if (!ddd) return '';
  if (!rest) return `(${ddd}`;
  const splitAt = mobile ? 5 : 4;
  const first = rest.slice(0, splitAt);
  const second = rest.slice(splitAt);
  return second ? `(${ddd}) ${first}-${second}` : `(${ddd}) ${first}`;
};
