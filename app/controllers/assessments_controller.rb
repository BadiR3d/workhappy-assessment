class AssessmentsController < ApplicationController
  include ActionController::Live
  before_action :require_admin
  before_action :load_filters, only: [:index, :export]

  PAGE_SIZE = 25

  def index
    @page = params[:page].to_s.match?(/\A[1-9]\d{0,2}\z/) ? params[:page].to_i : 1
    @assessments = filtered_scope.order(created_at: :desc, id: :desc)
      .limit(PAGE_SIZE + 1).offset((@page - 1) * PAGE_SIZE).to_a
    @export_available = @assessments.any? || (@page > 1 && filtered_scope.exists?)
    @has_next = @assessments.length > PAGE_SIZE
    @assessments = @assessments.first(PAGE_SIZE)
    # Explicit company scope protects display even if old associations are inconsistent.
    @employees = current_user.company.employees.where(id: @assessments.map(&:employee_id)).index_by(&:id)
  end

  def show
    load_assessment
  end

  def update
    load_assessment
    unless params[:assessment].is_a?(ActionController::Parameters)
      render plain: "Choose an approved status.", status: :unprocessable_entity
      return
    end
    if @assessment.update(params.require(:assessment).permit(:status))
      redirect_to assessment_path(@assessment), notice: "Assessment status updated.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  def export
    unless ENV.fetch("ASSESSMENT_EXPORT_ENABLED", "true") == "true"
      render plain: "Exports are temporarily unavailable.", status: :service_unavailable
      return
    end
    company = current_user.company
    relation = filtered_scope.reorder(nil).select(:id, :employee_id, :created_at, :status, :responses_json)
    # Bound the traversal against later inserts without holding a long snapshot transaction.
    upper_id = relation.maximum(:id)
    serializer = AssessmentsCsv.new(timezone: company_timezone)
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["Last-Modified"] = Time.now.httpdate
    count = 0
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    send_stream(filename: "assessments.csv", type: "text/csv; charset=utf-8") do |stream|
      begin
        serializer.write_header(stream)
        if upper_id
          relation.where("assessments.id <= ?", upper_id).find_in_batches(batch_size: 500, error_on_ignore: true) do |batch|
            employees = company.employees.where(id: batch.map(&:employee_id)).pluck(:id, :name).to_h
            batch.each do |assessment|
              serializer.write_row(stream, assessment, employee_name: employees[assessment.employee_id])
              count += 1
            end
          end
        end
        Rails.logger.info(event: "assessment_export_completed", rows: count,
          duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
          request_id: request.request_id)
      rescue ActionController::Live::ClientDisconnected, IOError, Errno::EPIPE
        Rails.logger.info(event: "assessment_export_disconnected", request_id: request.request_id)
      rescue StandardError => error
        # Headers are committed: do not append an error payload or log database exception details.
        Rails.logger.error(event: "assessment_export_failed", error_class: error.class.name, request_id: request.request_id)
        response.stream.close
      end
    end
  end

  private

  def load_assessment
    @assessment = current_user.company.assessments.find(params[:id])
    @employee = current_user.company.employees.find_by(id: @assessment.employee_id)
  end

  def company_timezone
    ActiveSupport::TimeZone[current_user.company.timezone]
  end

  def load_filters
    # No client company selector or additional export filters are accepted.
    # Rails submit buttons send `commit`; it is form metadata, not a filter.
    supplied = params.to_unsafe_h.except("controller", "action", "format", "page", "commit")
    if (supplied.keys - %w[from to status]).any?
      @filter_errors = ["Only date range and status filters are supported."]
      render :invalid_filters, formats: [:html], status: :unprocessable_entity
      return
    end
    @filters = AssessmentFilters.new(supplied, timezone: company_timezone)
    return if @filters.valid?
    @filter_errors = @filters.errors
    render :invalid_filters, formats: [:html], status: :unprocessable_entity
  end

  def filtered_scope
    AssessmentsQuery.new(scope: current_user.company.assessments, filters: @filters).call
  end
end
