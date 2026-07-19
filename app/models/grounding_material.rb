class GroundingMaterial < ApplicationRecord
  # PDF/image files delivered to the LLM as base64 image_url parts (see
  # Llm::Request.encode_pdf_part). No text extraction — matches the statement PDF.
  ALLOWED_CONTENT_TYPES = %w[application/pdf image/png image/jpeg image/webp].freeze

  # Coarse token proxy for a binary PDF/image sent as an image_url part:
  # ~1 page ≈ 100 KB ≈ 258 tokens on Gemini, so ~1 token per 400 bytes.
  # Deliberately approximate; a pdf-reader page count is a deferred upgrade.
  BYTES_PER_PROXY_TOKEN = 400

  has_and_belongs_to_many :problems
  has_many_attached :files

  validates :title, presence: true
  validate :files_are_pdf_or_image

  after_commit :recompute_estimated_tokens

  # Text contribution to the LLM message: the typed body under a heading the
  # model can recognize. nil when there is no typed text.
  def grounding_text
    return nil if body.blank?
    "## Grounding Material\n\n#{body}"
  end

  # One image_url content-part per attached PDF/image, using the shared encoder.
  def grounding_file_parts
    files.filter_map { |f| Llm::Request.encode_pdf_part(f) }
  end

  def compute_estimated_tokens
    text_tokens = (body.to_s.length / 4.0).ceil
    file_tokens = files.sum { |f| (f.byte_size.to_f / BYTES_PER_PROXY_TOKEN).round }
    text_tokens + file_tokens
  end

  private

  # update_column bypasses callbacks, so this after_commit does not re-fire.
  def recompute_estimated_tokens
    fresh = compute_estimated_tokens
    update_column(:estimated_tokens, fresh) if fresh != estimated_tokens
  end

  def files_are_pdf_or_image
    files.each do |f|
      next if ALLOWED_CONTENT_TYPES.include?(f.content_type)
      errors.add(:files, "#{f.filename} must be a PDF or image (got #{f.content_type})")
    end
  end
end
