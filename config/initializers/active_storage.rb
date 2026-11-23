# Allow audio attachments (call recordings, voice notes) to serve inline so the
# in-app <audio> player can stream them. Without this, ActiveStorage's blob model
# forces Content-Disposition: attachment for any MIME outside the default allowlist
# (images + PDF), which makes the browser download instead of play.
Rails.application.config.active_storage.content_types_allowed_inline += %w[
  audio/webm
  audio/ogg
  audio/mpeg
  audio/mp4
  audio/x-m4a
  audio/wav
  audio/x-wav
]

module ActiveStorageDirectUploadMetadataFilter
  INTERNAL_METADATA_KEYS = %w[identified analyzed composed].freeze

  private

  def blob_args
    super.tap do |args|
      args[:metadata]&.except!(*INTERNAL_METADATA_KEYS, *INTERNAL_METADATA_KEYS.map(&:to_sym))
    end
  end
end

module ActiveStorageProxyRangeLimit
  STREAMING_MAX_RANGES = 1
  STREAMING_CHUNK_MAX_SIZE = 100.megabytes

  private

  def send_blob_byte_range_data(blob, range_header, disposition: nil)
    ranges = Rack::Utils.get_byte_ranges(range_header, blob.byte_size)
    return head(:range_not_satisfiable) unless valid_ranges?(ranges)

    super
  end

  def valid_ranges?(ranges)
    ranges.present? &&
      ranges.any?(&:present?) &&
      ranges.length <= STREAMING_MAX_RANGES &&
      ranges.sum { |range| range.end - range.begin } < STREAMING_CHUNK_MAX_SIZE
  end
end

# Block the default Rails direct-upload route. Dashboard and widget uploads both go
# through the scoped, authenticated /api/v1/... endpoints, so the bare route has no
# legitimate caller; leaving it open allows anonymous blob creation. Scoped subclasses
# call super and are exempt via the instance_of? check.
module ActiveStorageBareDirectUploadGuard
  extend ActiveSupport::Concern

  included do
    before_action :reject_bare_direct_upload
  end

  private

  def reject_bare_direct_upload
    head :forbidden if instance_of?(ActiveStorage::DirectUploadsController)
  end
end

# O modo `proxy` (config.active_storage.resolve_model_to_route) serve o arquivo pelo proprio app, e o
# Rails o marca como `public` por 100 anos (`http_cache_forever public: true`). Aqui o anexo exige
# login (ActiveStorageAttachmentAccess), entao `public` deixaria uma CDN ou proxy entrega-lo a quem nao
# esta logado. O cache fica so' no navegador de quem esta logado (`private`): baixa uma vez e as
# aberturas seguintes saem do navegador. O endereco leva o id assinado do arquivo, que nunca muda
# (`immutable`); a validade de 7 dias limita por quanto tempo uma imagem ja baixada sobrevive a um
# acesso retirado. (O `http_cache_forever` e' o que o controller chama ANTES de transmitir o arquivo -
# um `after_action` chegaria tarde, com os cabecalhos ja enviados.)
module ActiveStoragePrivateCache
  PRIVATE_CACHE_DURATION = 7.days

  def http_cache_forever(public: false)
    expires_in PRIVATE_CACHE_DURATION, public: false
    # Diretiva solta (sem `chave=valor`): `expires_in` so' sabe escrever opcao como `chave=valor`.
    response.cache_control[:extras] = %w[immutable]
    yield if stale?(etag: request.fullpath, last_modified: Time.new(2011, 1, 1).utc, public: false)
  end
end

Rails.application.config.to_prepare do
  [ActiveStorage::Blobs::ProxyController, ActiveStorage::Representations::ProxyController].each do |controller|
    controller.prepend(ActiveStoragePrivateCache) unless controller < ActiveStoragePrivateCache
  end

  unless ActiveStorage::DirectUploadsController < ActiveStorageDirectUploadMetadataFilter
    ActiveStorage::DirectUploadsController.prepend(ActiveStorageDirectUploadMetadataFilter)
  end

  unless ActiveStorage::DirectUploadsController.include?(ActiveStorageBareDirectUploadGuard)
    ActiveStorage::DirectUploadsController.include(ActiveStorageBareDirectUploadGuard)
  end

  ActiveStorage::Streaming.prepend(ActiveStorageProxyRangeLimit) unless ActiveStorage::Streaming < ActiveStorageProxyRangeLimit

  # Baixar anexo exige login (ver ActiveStorageAttachmentAccess): o link assinado
  # do ActiveStorage, sozinho, deixava qualquer pessoa com o endereco baixar o
  # arquivo de um cliente.
  [
    ActiveStorage::Blobs::RedirectController, ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Representations::RedirectController, ActiveStorage::Representations::ProxyController,
    ActiveStorage::DiskController
  ].each do |controller|
    controller.include(ActiveStorageAttachmentAccess) unless controller.include?(ActiveStorageAttachmentAccess)
  end
end
