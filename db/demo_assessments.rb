# Deterministic fictional histories; no Rails/database dependency.
module DemoAssessments
  MARKER = "SYNTHETIC_PRIVATE_NOTE_DO_NOT_EXPORT_HISTORY_V3".freeze
  OLD_MARKERS = %w[SYNTHETIC_PRIVATE_NOTE_DO_NOT_EXPORT SYNTHETIC_PRIVATE_NOTE_DO_NOT_EXPORT_FIELDWORK_V2].freeze
  QUESTIONS = %w[chair_support screen_position keyboard_mouse desk_space movement_breaks].freeze
  STATUSES = %w[completed pending in_progress needs_follow_up archived].freeze
  COMPLETED_ALIASES = ["completed", "comp", "done", " COMPLETE "].freeze
  PROFILES = {
    "northstar" => {
      name: "Northstar Studio",
      names: ["Alex Morgan", "Sam Patel", "Taylor Reed", "Robin Clarke", "Casey Adams", "Jordan Ellis", "Avery Brooks", "Drew Bennett"],
      totals: [8, 0, 20, 7, 14, 9, 12, 5], offsets: [0, 5, 10, 15], status_offset: 0
    },
    "fieldwork" => {
      name: "Fieldwork Collective",
      names: ["Priya Naidoo", "Liam Jacobs", "Zanele Dlamini", "Owen Williams", "Maya Singh", "Ethan Daniels", "Lerato Molefe", "Sofia Martins"],
      totals: [4, 13, 6, 10, 2, 17, 11, 3], offsets: [0, 4, 9, 14], status_offset: 3
    }
  }.freeze

  def self.history(slug:, employee_index:, latest_at:)
    profile = PROFILES.fetch(slug)
    4.times.map do |visit|
      total = (profile[:totals].fetch(employee_index) + profile[:offsets].fetch(visit)) % 21
      answers = Array.new(5) { |question| total / 5 + (question < total % 5 ? 1 : 0) }
      # Preserve the documented latest Alex example; historical visits still differ.
      answers = [2, 1, 3, 0, 2] if slug == "northstar" && employee_index.zero? && visit.zero?
      answers = answers.rotate((employee_index + visit) % 5)
      responses = QUESTIONS.zip(answers).to_h
      # Only one visit has each edge case, rather than repeating it across history.
      responses.delete("movement_breaks") if employee_index == 3 && visit.zero?
      responses["chair_support"] = "invalid-demo-answer" if employee_index == 4 && visit.zero?
      responses["comments"] = MARKER
      status = STATUSES[(employee_index + visit + profile[:status_offset]) % STATUSES.length]
      status = COMPLETED_ALIASES[employee_index % 4] if status == "completed"
      status = employee_index == 6 ? nil : "n/a" if employee_index >= 6 && visit.zero?
      # Separate visits by several weeks, with employee/company-specific spacing.
      age_days = visit * (21 + employee_index + profile[:status_offset])
      time = latest_at - age_days * 86_400
      { status: status, responses_json: responses, created_at: time, updated_at: time }
    end
  end
end
