export const AVAILABLE_CUSTOM_ROLE_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
  'conversation_view',
  'contact_manage',
  'report_manage',
  'knowledge_base_manage',
  'client_credentials_manage',
  'client_billing_manage',
  'department_manage',
  'queue_manage',
  'project_manage',
  'implementation_report_manage',
  'ticket_manage',
  'agenda_manage',
  'company_manage',
  'internal_chat_manage',
  'suggestion_manage',
  'commercial_manage',
];

export const COMMERCIAL_PERMISSIONS = 'commercial_manage';

export const CLIENT_CREDENTIALS_PERMISSIONS = 'client_credentials_manage';

export const ROLES = ['agent', 'administrator'];

export const CONVERSATION_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
];

export const MANAGE_ALL_CONVERSATION_PERMISSIONS = 'conversation_manage';

export const CONVERSATION_UNASSIGNED_PERMISSIONS =
  'conversation_unassigned_manage';

export const CONVERSATION_PARTICIPATING_PERMISSIONS =
  'conversation_participating_manage';

// So' abre e le as conversas que ja enxerga (mesmo alcance de inbox/equipe) -
// sem responder nem agir. Deliberadamente FORA de `CONVERSATION_PERMISSIONS`
// (que outras telas - Caixas, Macros, Respostas prontas, Chamadas, Captain -
// usam como "tem algum acesso a conversa"): essas telas são de gestão, e
// "visualização" não deveria destravá-las.
export const CONVERSATION_VIEW_PERMISSIONS = 'conversation_view';

export const CONTACT_PERMISSIONS = 'contact_manage';

export const REPORTS_PERMISSIONS = 'report_manage';

export const PORTAL_PERMISSIONS = 'knowledge_base_manage';

export const ASSIGNEE_TYPE_TAB_PERMISSIONS = {
  me: {
    count: 'mineCount',
    permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
  },
  queue: {
    count: 'queueCount',
    permissions: [
      ...ROLES,
      MANAGE_ALL_CONVERSATION_PERMISSIONS,
      CONVERSATION_UNASSIGNED_PERMISSIONS,
    ],
  },
  all: {
    count: 'allCount',
    permissions: [
      ...ROLES,
      MANAGE_ALL_CONVERSATION_PERMISSIONS,
      CONVERSATION_PARTICIPATING_PERMISSIONS,
      CONVERSATION_VIEW_PERMISSIONS,
    ],
  },
};
