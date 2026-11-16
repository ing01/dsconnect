// Estimativa original do ticket (Modulo de Desenvolvimento), em horas, dentro de
// `custom_attributes`. Aceita numero ou texto ("6", "2,5"); vazio ou invalido
// conta como zero, para nao derrubar a soma do grupo.
export const ticketEstimateHours = ticket => {
  const raw = ticket?.custom_attributes?.estimativa_original_horas;
  const hours = Number(String(raw ?? '').replace(',', '.'));
  return Number.isFinite(hours) && hours > 0 ? hours : 0;
};

export const sumEstimateHours = tickets =>
  (tickets || []).reduce(
    (total, ticket) => total + ticketEstimateHours(ticket),
    0
  );

// 6 -> "6", 2.5 -> "2,5", 0.1 + 0.2 -> "0,3" (ate 2 casas, sem zeros sobrando).
export const formatEstimateHours = hours =>
  String(Math.round(hours * 100) / 100).replace('.', ',');
