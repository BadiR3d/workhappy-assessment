require "test_helper"

class DemoSeedsTest < ActiveSupport::TestCase
  test "fresh seeds create four distinct assessments per employee and repeated runs preserve records" do
    load Rails.root.join("db/seeds.rb")
    companies = Company.where(name: ["Northstar Studio", "Fieldwork Collective"])
    companies.each do |company|
      assert_equal 32, company.assessments.count
      assert_equal [4], company.assessments.group(:employee_id).count.values.uniq
      company.employees.each do |employee|
        assert_equal 4, employee.assessments.map { |record| [record.score.state, record.score.value] }.uniq.length
      end
    end
    ids = companies.flat_map { |company| company.assessments.order(:id).pluck(:id) }
    load Rails.root.join("db/seeds.rb")
    assert_equal ids, companies.flat_map { |company| company.assessments.order(:id).pluck(:id) }
  end

  test "original fixture IDs are preserved with distinct visits while unmarked history survives" do
    company = Company.create!(name: "Northstar Studio", timezone: "London")
    employee = company.employees.create!(name: "Alex Morgan", email: "person1@northstar.example")
    records = 4.times.map do |i|
      create_assessment(company, employee, created_at: Time.utc(2026, 10, 19) - i.days,
        responses_json: { "comments" => "SYNTHETIC_PRIVATE_NOTE_DO_NOT_EXPORT" })
    end
    other = company.employees.create!(name: "Separate history", email: "history@example.invalid")
    historical = 4.times.map { create_assessment(company, other) }

    load Rails.root.join("db/seeds.rb")

    assert_equal records.map(&:id).sort, employee.assessments.order(:id).pluck(:id)
    assert_equal 4, employee.assessments.map { |record| record.score.value }.uniq.length
    assert_equal historical.map(&:id).sort, other.assessments.order(:id).pluck(:id)
  end

  test "a reduced fixture receives three additional visits without duplicating on another seed" do
    company = Company.create!(name: "Fieldwork Collective", timezone: "London")
    employee = company.employees.create!(name: "Priya Naidoo", email: "person1@fieldwork.example")
    retained = create_assessment(company, employee, responses_json: { "comments" => "SYNTHETIC_PRIVATE_NOTE_DO_NOT_EXPORT_FIELDWORK_V2" })
    load Rails.root.join("db/seeds.rb")
    assert_equal 4, employee.assessments.count
    assert_includes employee.assessments.pluck(:id), retained.id
    assert_equal [20, 40, 65, 90], employee.assessments.map { |record| record.score.value }.sort
    retained.reload.update!(status: "archived")
    snapshot = employee.assessments.order(:id).map(&:attributes)
    load Rails.root.join("db/seeds.rb")
    assert_equal snapshot, employee.assessments.order(:id).map(&:attributes)
  end

end
