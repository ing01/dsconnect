class JsonbAttributesLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.empty?

    @attribute = attribute
    @record = record

    value.each do |key, attribute_value|
      validate_keys(key, attribute_value)
    end
  end

  def validate_keys(key, attribute_value)
    case attribute_value.class.name
    when 'String'
      limit = string_limit_for(key)
      @record.errors.add @attribute, "#{key} length should be < #{limit}" if attribute_value.length > limit
    when 'Integer'
      @record.errors.add @attribute, "#{key} value should be < 9999999999" if attribute_value > 9_999_999_999
    end
  end

  private

  DEFAULT_STRING_LIMIT = 1500
  DEFAULT_LONG_TEXT_LIMIT = 100_000

  # `long_text_keys:` libera um teto maior so' para as chaves que guardam texto
  # de verdade (ex.: a Analise do card do Jira), sem afrouxar o resto.
  def string_limit_for(key)
    return DEFAULT_STRING_LIMIT unless Array(options[:long_text_keys]).include?(key.to_s)

    options[:long_text_max] || DEFAULT_LONG_TEXT_LIMIT
  end
end
