abort "Demo seeds are restricted to development/test." unless Rails.env.development? || Rails.env.test?
require_relative "demo_assessments"

ActiveRecord::Base.transaction do
  DemoAssessments::PROFILES.each do |slug, profile|
    company = Company.find_or_create_by!(name: profile[:name]) { |record| record.timezone = "London" }
    User.find_or_create_by!(email: "admin@#{slug}.example") do |user|
      user.company = company
      user.role = "admin"
      user.password = "Demo-assessment-2026!"
    end
    profile[:names].each_with_index do |name, employee_index|
      employee = company.employees.find_or_create_by!(email: "person#{employee_index + 1}@#{slug}.example") do |record|
        record.name = name
      end
      if slug == "fieldwork" && employee.name == DemoAssessments::PROFILES["northstar"][:names][employee_index]
        employee.update!(name: name)
      end
      existing = company.assessments.where(employee_id: employee.id).order(created_at: :desc, id: :desc).to_a
      # Upgrade only the known one- or four-record old fixture sets. Do not touch
      # unmarked histories, benchmark data, or already-upgraded examples/edits.
      upgradeable = [1, 4].include?(existing.length) && existing.all? do |record|
        record.responses_json.is_a?(Hash) && DemoAssessments::OLD_MARKERS.include?(record.responses_json["comments"])
      end
      next if existing.any? && !upgradeable

      latest_at = existing.first&.created_at ||
        (Time.zone.now.beginning_of_day - (employee_index + profile[:status_offset]).days + 10.hours)
      rows = DemoAssessments.history(slug: slug, employee_index: employee_index, latest_at: latest_at)
      rows.each_with_index do |attributes, visit|
        attributes = attributes.merge(company_id: company.id, employee_id: employee.id, employee_email: employee.email)
        # Fixture-only bypass represents historical values predating validation.
        # Existing IDs survive; a reduced one-record set receives three new visits.
        if existing[visit]
          existing[visit].update_columns(attributes)
        else
          Assessment.insert_all!([attributes])
        end
      end
    end
  end
end
puts "Seeded fictional workspaces: four distinct assessments per employee. See README.md for sign-in details."
