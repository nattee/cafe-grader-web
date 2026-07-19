class GroundingMaterialsController < ApplicationController
  before_action :admin_authorization
  before_action :set_grounding_material, only: %i[edit update destroy delete_file]

  def index
    @grounding_materials = GroundingMaterial.order(:title)
  end

  def new
    @grounding_material = GroundingMaterial.new
  end

  def edit; end

  def create
    @grounding_material = GroundingMaterial.new(gm_params)
    attach_files(@grounding_material)
    if @grounding_material.save
      redirect_to grounding_materials_path, notice: 'Grounding material created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @grounding_material.assign_attributes(gm_params)
    attach_files(@grounding_material)
    if @grounding_material.save
      refresh_estimated_tokens
      redirect_to grounding_materials_path, notice: 'Grounding material updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @grounding_material.destroy
    redirect_to grounding_materials_path, notice: 'Grounding material deleted.'
  end

  # DELETE /grounding_materials/:id/delete_file?blob_id=NN
  def delete_file
    blob = @grounding_material.files.find_by(id: params[:blob_id])
    blob&.purge
    refresh_estimated_tokens
    redirect_to edit_grounding_material_path(@grounding_material), notice: 'File removed.'
  end

  private

  def set_grounding_material
    @grounding_material = GroundingMaterial.find(params[:id])
  end

  # Append newly uploaded files (never replace); per-file removal is delete_file.
  def attach_files(gm)
    uploads = Array(params.dig(:grounding_material, :files)).reject(&:blank?)
    gm.files.attach(uploads) if uploads.any?
  end

  # files.attach and blob.purge bypass the model's after_commit callback, so
  # the cached estimated_tokens can go stale after a file-only change. Force
  # a recompute via update_column (no callbacks, no recursion).
  def refresh_estimated_tokens
    @grounding_material.reload
    @grounding_material.update_column(:estimated_tokens, @grounding_material.compute_estimated_tokens)
  end

  def gm_params
    params.require(:grounding_material).permit(:title, :description, :body)
  end
end
