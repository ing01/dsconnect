import { ROLES } from 'dashboard/constants/permissions.js';

// A aba de Notificacoes: administrador e agente sempre veem; uma funcao personalizada precisa da
// permissao `notification_view` (marcada por padrao nas funcoes novas e concedida as existentes).
// Fica num arquivo proprio, leve, para a lista poder ser testada sem montar as telas.
export const NOTIFICATION_VIEW_PERMISSION = 'notification_view';
export const INBOX_PERMISSIONS = [...ROLES, NOTIFICATION_VIEW_PERMISSION];
