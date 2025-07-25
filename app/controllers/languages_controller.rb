class LanguagesController < ApplicationController
  before_action :set_language, only: %i[ show edit update destroy ]
  before_action :prevent_editing_read_only, only: %i[ update destroy ]

  # GET /languages or /languages.json
  def index
    @languages = Language.all
  end

  # GET /languages/1 or /languages/1.json
  def show
  end

  # GET /languages/new
  def new
    @language = Language.new
  end

  # GET /languages/1/edit
  def edit
  end

  # POST /languages or /languages.json
  def create
    @language = Language.new(language_params)

    respond_to do |format|
      if @language.save
        format.html { redirect_to @language, notice: "Language was successfully created." }
        format.json { render :show, status: :created, location: @language }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @language.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /languages/1 or /languages/1.json
  def update
    respond_to do |format|
      if @language.update(language_params)
        format.html { redirect_to @language, notice: "Language was successfully updated." }
        format.json { render :show, status: :ok, location: @language }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @language.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /languages/1 or /languages/1.json
  def destroy
    redirect_to(languages_path, alert: "Cannot delete pre-configured languages") and return if @system_language
    @language.destroy!

    respond_to do |format|
      format.html { redirect_to languages_path, status: :see_other, notice: "Language was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_language
      @language = Language.find(params.expect(:id))
      @system_language = @language.id < 20
    end

    # Only allow a list of trusted parameters through.
    def language_params
      params.require(:language).permit(:name, :pretty_name, :ext, :common_ext, :binary, :use_control_group)
    end

    def prevent_editing_read_only
      if @system_language
        redirect_to(languages_path, alert: "Cannot #{action_name} a pre-configured language")
      end
    end
end
