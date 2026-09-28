import { getters } from '../../teams/getters';
import teamsList from './fixtures';

describe('#getters', () => {
  it('getTeams', () => {
    const state = {
      records: teamsList,
    };
    expect(getters.getTeams(state)).toEqual([teamsList[1], teamsList[2]]);
  });

  it('getMyTeams', () => {
    const state = {
      records: teamsList,
    };
    expect(
      getters.getMyTeams(state, {
        getTeams: [teamsList[1], teamsList[2]],
      })
    ).toEqual([teamsList[1]]);
  });

  it('getMyTeams excludes a member team with handles_conversations: false', () => {
    const nonConversationTeam = { ...teamsList[1], handles_conversations: false };
    expect(
      getters.getMyTeams(
        {},
        { getTeams: [nonConversationTeam, teamsList[2]] }
      )
    ).toEqual([]);
  });

  it('getProjectTeams excludes a team with handles_projects: false', () => {
    const nonProjectTeam = { ...teamsList[1], handles_projects: false };
    expect(
      getters.getProjectTeams(
        {},
        { getTeams: [nonProjectTeam, teamsList[2]] }
      )
    ).toEqual([teamsList[2]]);
  });

  it('getTeam', () => {
    const state = {
      records: teamsList,
    };
    expect(getters.getTeam(state)(1)).toEqual({
      id: 1,
      account_id: 1,
      name: 'Test',
      description: 'Some team',
      is_member: true,
    });
  });

  it('getUIFlags', () => {
    const state = {
      uiFlags: {
        isFetching: false,
        isCreating: false,
        isUpdating: false,
        isDeleting: false,
      },
    };
    expect(getters.getUIFlags(state)).toEqual({
      isFetching: false,
      isCreating: false,
      isUpdating: false,
      isDeleting: false,
    });
  });
});
