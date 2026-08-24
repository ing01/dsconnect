// Mesa (Team) names are stored lowercase - Team normalizes them before
// validation - so this is display-only capitalization for the Tickets screens.
// Never write the result back to the API.
export const formatMesaName = (name = '') =>
  String(name ?? '').replace(
    /\p{L}[\p{L}\p{M}'’-]*/gu,
    word => word.charAt(0).toUpperCase() + word.slice(1)
  );

export default formatMesaName;
