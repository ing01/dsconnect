// Structured skeleton offered when a ticket has no description yet. Written as
// Markdown bold so it survives the ProseMirror round-trip the editor performs.
export const TICKET_DESCRIPTION_TEMPLATE = [
  '**DESCRIÇÃO:**',
  '',
  '**CAMINHO:**',
  '',
  '**CONFIGURAÇÃO:**',
  '',
  '**TELAS AFETADAS:**',
  '',
  '**BACKUP:**',
  '',
  '**PROCEDIMENTOS REALIZADOS:**',
  '',
  '**EVIDÊNCIAS:**',
  '',
].join('\n');
