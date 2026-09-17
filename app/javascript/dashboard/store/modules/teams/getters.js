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
  getMyTeams($state, $getters) {
    return $getters.getTeams.filter(team => {
      const { is_member: isMember } = team;
      return isMember;
    });
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getTeam: $state => id => {
    const team = $state.records[id];
    return team ? withCapitalizedName(team) : {};
  },
};
