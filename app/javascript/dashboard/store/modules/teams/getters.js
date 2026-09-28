// Team names are stored lowercased (see Team#downcase_name in the backend),
// so every getter capitalizes the first letter for display purposes only.
const withCapitalizedName = team =>
  team.name
    ? { ...team, name: team.name.charAt(0).toUpperCase() + team.name.slice(1) }
    : team;

export const getters = {
  getTeams($state) {
    return Object.values($state.records)
      .sort((a, b) => a.id - b.id)
      .map(withCapitalizedName);
  },
  getTeamById: $state => id => {
    const team = Object.values($state.records).find(
      record => record.id === Number(id)
    );
    return team ? withCapitalizedName(team) : {};
  },
  // The "Times" group in the Conversations sidebar - a team that never talks
  // to customers (handles_conversations: false) has nothing to show there.
  getMyTeams($state, $getters) {
    return $getters.getTeams.filter(team => {
      const { is_member: isMember, handles_conversations: handlesConversations } = team;
      return isMember && handlesConversations !== false;
    });
  },
  // The Equipe filter on Projects and the Mesa picker on Novo Projeto - a team
  // that doesn't run Projects (handles_projects: false) shouldn't be offered.
  getProjectTeams($state, $getters) {
    return $getters.getTeams.filter(team => team.handles_projects !== false);
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getTeam: $state => id => {
    const team = $state.records[id];
    return team ? withCapitalizedName(team) : {};
  },
};
