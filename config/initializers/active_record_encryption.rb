# Encrypts sensitive columns (e.g. CompanyCredential passwords) at rest using
# Rails' native ActiveRecord::Encryption. Keys can be pinned via env vars for
# independent rotation; otherwise they're derived from SECRET_KEY_BASE so this
# works out of the box. Rotating SECRET_KEY_BASE without ACTIVE_RECORD_ENCRYPTION_*
# set will make previously encrypted data undecryptable.
#
# ActiveRecord::Railtie's own "active_record_encryption.configuration" initializer
# already ran ActiveRecord::Encryption.configure(...) with blank keys by this point
# (its on_load(:active_record_encryption) hook fires as soon as the activerecord gem
# requires active_record/encryption, well before config/initializers/*.rb runs), so
# setting Rails.application.config.active_record.encryption.* here has no effect.
# Call .configure directly to override the config singleton for real.
key_generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)

ActiveRecord::Encryption.configure(
  primary_key: ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY', key_generator.generate_key('active_record_encryption_primary_key', 32)),
  deterministic_key: ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY', key_generator.generate_key('active_record_encryption_deterministic_key', 32)),
  key_derivation_salt: ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT', key_generator.generate_key('active_record_encryption_key_derivation_salt', 32))
)
