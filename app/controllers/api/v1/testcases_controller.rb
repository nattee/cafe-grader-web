class Api::V1::TestcasesController < Api::V1::BaseController
  before_action :set_testcase
  before_action :authorize_testcase!

  # GET /api/v1/testcases/:id/input
  def input
    send_data @testcase.inp_file.download,
      type: "text/plain",
      filename: "#{@problem.name}.#{@testcase.num}.in"
  end

  # GET /api/v1/testcases/:id/sol
  def sol
    send_data @testcase.ans_file.download,
      type: "text/plain",
      filename: "#{@problem.name}.#{@testcase.num}.sol"
  end

  private

  def set_testcase
    @testcase = Testcase.find(params[:id])
    @problem = @testcase.dataset.problem
  rescue ActiveRecord::RecordNotFound
    render_not_found("Testcase")
  end

  def authorize_testcase!
    unless current_user.can_view_testcase?(@problem)
      render json: { error: "You are not allowed to view this testcase" }, status: :forbidden
    end
  end
end
