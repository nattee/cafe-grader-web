class DatasetsController < ApplicationController
  before_action :set_dataset, only: %i[ show edit update destroy
                                        file_delete file_view file_download
                                        testcase_input testcase_sol testcase_delete
                                        view set_as_live rejudge set_weight
                                      ]
  before_action :admin_authorization
  before_action :check_valid_login

  # GET /datasets/new
  def new
    @dataset = Dataset.new
  end

  # GET /datasets/1/edit
  def edit
  end

  # POST /datasets or /datasets.json
  def create
    @dataset = Dataset.new(dataset_params)

    respond_to do |format|
      if @dataset.save
        format.html { redirect_to dataset_url(@dataset), notice: "Dataset was successfully created." }
        format.json { render :show, status: :created, location: @dataset }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /datasets/1 or /datasets/1.json
  def update
    respond_to do |format|
      # file attachment
      @dataset.managers.attach params[:dataset][:managers] if params[:dataset][:managers]
      @dataset.data_files.attach params[:dataset][:data_files] if params[:dataset][:data_files]
      @dataset.initializers.attach params[:dataset][:initializers] if params[:dataset][:initializers]

      # since checker is downloaded and cached by WorkerDataset, we have to invalidate it
      # when it is updated
      if params[:dataset][:checker] || params[:dataset][:managers] || params[:dataset][:initializers] || params[:dataset][:data_files]
        WorkerDataset.where(dataset_id: @dataset).delete_all
      end

      if @dataset.update(dataset_params)
        flash.now[:notice] = "Updated successfully on #{Time.zone.now}"
        format.json { render :show, status: :ok, location: @dataset }
        format.turbo_stream
      else
        #format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
        format.turbo_stream
      end
    end
  end

  def file_delete
    att = ActiveStorage::Attachment.where(record: @dataset,id: params[:att_id]).first
    att.purge

    @dataset.reload
    @dataset.save if @dataset.update_main_filename

    @toast_body = "#{att.name.capitalize} file [#{att.filename}] is deleted"
    @toast_subtitle = Time.zone.now.to_s
    @toast_header = 'File deleted'
  end

  def file_view
    att = ActiveStorage::Attachment.where(record: @dataset,id: params[:att_id]).first
    render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: att.filename, body_msg: att.download}
  end

  def file_download
    att = ActiveStorage::Attachment.where(record: @dataset,id: params[:att_id]).first
    type = att.content_type
    filename = att.filename.to_s
    send_data att.download, disposition: 'inline', type: type, filename: filename
  end

  # as turbo
  def testcase_input
    tc = Testcase.find(params[:tc_id])
    render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'input', body_msg: tc.inp_file.download }

  end

  # as turbo
  def testcase_sol
    tc = Testcase.find(params[:tc_id])
    render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'answer', body_msg: tc.ans_file.download }
  end

  # as turbo
  def testcase_delete
    tc = Testcase.find(params[:tc_id])
    tc.destroy

    flash.now[:notice] = "Testcase ##{tc.num} is deleted"
    render :update
  end

  def set_weight
    begin
      config = JSON.parse(params[:weight_param])
      if config.is_a? Array
        @dataset.set_by_array(:weight,config)
      else
        @dataset.set_by_hash(config.symbolize_keys)
      end
      flash.now[:notice] = "Testcases' parameters are updated"
    rescue JSON::ParserError => e
      flash.now[:alert] = 'weight params is malformed'
    end
    render :update
  end

  def view
    @dataset = Dataset.find(params[:null][:dsid])
    render :update
  end

  def set_as_live
    @dataset.problem.update(live_dataset: @dataset)
    flash.now[:notice] = "Dataset #{@dataset.name} is live"
    render :update
  end

  def rejudge
    @dataset.problem.submissions.each do |sub|
      #mass rejudge, priority is very low
      sub.add_judge_job(@dataset,-50)
    end

  end

  # DELETE /datasets/1 or /datasets/1.json
  def destroy
    p = @dataset.problem
    if p.datasets.count == 1
      # can't delete last dataset
      flash.now[:alert] = 'Cannot delete the last dataset'
    elsif @dataset == p.live_dataset
      # can't delete the live dataset
      flash.now[:alert] = 'Cannot delete live dataset'
    else
      @dataset.destroy
      @dataset = p.datasets.first
      flash.now[:notice] = 'Dataset is deleted'
    end


    respond_to do |format|
      format.html { redirect_to datasets_url, notice: "Dataset was successfully destroyed." }
      format.json { head :no_content }
      format.turbo_stream { render :update }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dataset
      @dataset = Dataset.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def dataset_params
      params.fetch(:dataset, {})
      params.require(:dataset).permit(:name, :time_limit, :memory_limit, :score_type, :evaluation_type, :main_filename, 
                                      :checker, :initializer_filename)
    end

end
