export const hasPermissions = (
  requiredPermissions = [],
  availablePermissions = []
) => {
  return requiredPermissions.some(permission =>
    availablePermissions.includes(permission)
  );
};

export const getCurrentAccount = ({ accounts } = {}, accountId = null) => {
  return accounts.find(account => Number(account.id) === Number(accountId));
};

export const getUserPermissions = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  return currentAccount.permissions || [];
};

export const getUserRole = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  if (currentAccount.custom_role_id) {
    return 'custom_role';
  }

  return currentAccount.role || 'agent';
};

const CONVERSATION_MANAGE_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
];

// Uma funcao personalizada com "conversation_view" e nenhum "_manage" pode
// abrir e ler as conversas que ja enxerga (mesmo alcance de inbox/equipe de
// sempre), mas nao responder nem agir - a tela esconde a caixa de resposta e
// as acoes do cabecalho para quem cai neste caso.
export const isConversationViewOnly = (user, accountId) => {
  if (getUserRole(user, accountId) !== 'custom_role') return false;

  const permissions = getUserPermissions(user, accountId);
  const hasManagePermission = CONVERSATION_MANAGE_PERMISSIONS.some(permission =>
    permissions.includes(permission)
  );
  return permissions.includes('conversation_view') && !hasManagePermission;
};

/**
 * Filters and transforms items based on user permissions.
 *
 * @param {Object} items - An object containing items to be filtered.
 * @param {Array} userPermissions - Array of permissions the user has.
 * @param {Function} getPermissions - Function to extract required permissions from an item.
 * @param {Function} [transformItem] - Optional function to transform each item after filtering.
 * @returns {Array} Filtered and transformed items.
 */
export const filterItemsByPermission = (
  items,
  userPermissions,
  getPermissions,
  transformItem = (key, item) => ({ key, ...item })
) => {
  // Helper function to check if an item has the required permissions
  const hasRequiredPermissions = item => {
    const requiredPermissions = getPermissions(item);
    return (
      requiredPermissions.length === 0 ||
      hasPermissions(requiredPermissions, userPermissions)
    );
  };

  return Object.entries(items)
    .filter(([, item]) => hasRequiredPermissions(item)) // Keep only items with required permissions
    .map(([key, item]) => transformItem(key, item)); // Transform each remaining item
};
