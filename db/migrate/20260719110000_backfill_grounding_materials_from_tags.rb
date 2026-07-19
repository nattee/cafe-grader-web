class BackfillGroundingMaterialsFromTags < ActiveRecord::Migration[8.0]
  # Copy viva_grounding tags → GroundingMaterial. Non-destructive: original
  # tags and their attachments stay until the next migration.
  def up
    viva_grounding_kind = 3 # Tag.kinds[:viva_grounding] at time of writing
    Tag.where(kind: viva_grounding_kind).find_each do |tag|
      next if GroundingMaterial.exists?(title: tag.name) # idempotent guard
      gm = GroundingMaterial.create!(
        title:       tag.name,
        description: tag.description,
        body:        tag.params
      )
      tag.files.blobs.each { |blob| gm.files.attach(blob) } # share blobs, non-destructive
      gm.problems << tag.problems.to_a
      gm.reload.send(:recompute_estimated_tokens)
    end
  end

  def down
    # Best-effort: remove materials that mirror a still-present viva_grounding tag.
    GroundingMaterial.where(title: Tag.where(kind: 3).pluck(:name)).destroy_all
  end
end
