# Matches an incoming reply against a `present_options` FlowStep's items, either by
# numeric position ("1", "2", ...) or by the option's title/value (case-insensitive).
# Returns the FlowStep to move to next, nil (branch has no next step configured), or
# the symbol :no_match when the reply doesn't correspond to any option.
class ConversationFlows::StepMatcherService
  pattr_initialize [:step!, :reply!]

  def perform
    return :no_match unless step.present_options?

    normalized = reply.to_s.strip.downcase
    return :no_match if normalized.blank?

    matched_item = match_by_index(normalized) || match_by_value(normalized)
    return :no_match if matched_item.blank?

    next_step_id = matched_item['next_step_id'] || step.next_step_id
    FlowStep.find_by(id: next_step_id)
  end

  private

  def items
    step.items
  end

  def match_by_index(normalized)
    return nil unless normalized.match?(/\A\d+\z/)

    items[normalized.to_i - 1]
  end

  def match_by_value(normalized)
    items.find { |item| item['value'].to_s.downcase == normalized || item['title'].to_s.downcase == normalized }
  end
end
