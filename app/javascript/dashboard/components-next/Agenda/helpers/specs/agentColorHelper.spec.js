import { colorForAgent, colorForEvent } from '../agentColorHelper';
import { EVENT_COLOR_OPTIONS, DEFAULT_EVENT_COLOR } from '../../constants';

const { holder } = vi.hoisted(() => ({ holder: { agents: [] } }));

vi.mock('dashboard/store', () => ({
  default: {
    getters: {
      get 'agents/getAgents'() {
        return holder.agents;
      },
    },
  },
}));

describe('agentColorHelper', () => {
  beforeEach(() => {
    holder.agents = [];
  });

  it('derives a stable color from the id when nothing was chosen', () => {
    expect(colorForAgent(8)).toBe(
      EVENT_COLOR_OPTIONS[8 % EVENT_COLOR_OPTIONS.length]
    );
    expect(colorForAgent(null)).toBe(DEFAULT_EVENT_COLOR);
  });

  it('uses the color the agent chose in the profile', () => {
    holder.agents = [{ id: 8, custom_attributes: { agenda_color: '#112233' } }];

    expect(colorForAgent(8)).toBe('#112233');
    expect(colorForEvent({ created_by_id: 8 })).toBe('#112233');
  });

  it('ignores an invalid stored color and other agents choices', () => {
    holder.agents = [
      { id: 8, custom_attributes: { agenda_color: 'red' } },
      { id: 9, custom_attributes: { agenda_color: '#112233' } },
    ];

    expect(colorForAgent(8)).toBe(
      EVENT_COLOR_OPTIONS[8 % EVENT_COLOR_OPTIONS.length]
    );
  });
});
