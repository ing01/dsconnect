# Porta `compareValues` do painel: dado o resultado (hash de valores
# numéricos) do período atual e do período anterior de qualquer um dos outros
# builders, calcula delta/direção por chave. Usado só nos modos semanal/mensal,
# como no painel - quem decide isso é o controller, computando os dois hashes
# antes de chamar este builder.
class V2::Reports::Implementation::PeriodComparisonBuilder
  pattr_initialize [:current!, :previous!]

  def build
    current.each_with_object({}) do |(key, value), result|
      previous_value = previous[key]
      result[key] = {
        value: value,
        previous_value: previous_value,
        delta: delta(value, previous_value),
        direction: direction(value, previous_value)
      }
    end
  end

  private

  def delta(value, previous_value)
    return nil unless value.is_a?(Numeric) && previous_value.is_a?(Numeric)

    value - previous_value
  end

  def direction(value, previous_value)
    return 'flat' unless value.is_a?(Numeric) && previous_value.is_a?(Numeric)
    return 'up' if value > previous_value
    return 'down' if value < previous_value

    'flat'
  end
end
