require_relative '../../util/spec_helper'

describe 'bCourses E-Grades Export', order: :defined do

  include Logging

  # Load course test data
  test_course_data = Utils.load_test_courses.find { |course| course['tests']['e_grades_export'] }
  course = Course.new test_course_data
  teacher = User.new course.teachers.first
  sections = course.sections.map { |section_data| Section.new section_data }
  sections_for_site = sections.select { |section| section.include_in_site }
  primary_section = sections_for_site.first
  secondary_section = sections_for_site.last

  # Load user test data
  test_user_data = Utils.load_test_users.select { |user| user['tests']['e_grades_export'] }
  lead_ta = User.new test_user_data.find { |data| data['role'] == 'Lead TA' }
  ta = User.new test_user_data.find { |data| data['role'] == 'TA' }
  designer = User.new test_user_data.find { |data| data['role'] == 'Designer' }
  observer = User.new test_user_data.find { |data| data['role'] == 'Observer' }
  reader = User.new test_user_data.find { |data| data['role'] == 'Reader' }
  student = User.new test_user_data.find { |data| data['role'] == 'Student' }
  waitlist = User.new test_user_data.find { |data| data['role'] == 'Waitlist Student' }

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasActivitiesPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @e_grades_export_page = Page::JunctionPages::CanvasEGradesExportPage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @rosters_api = ApiAcademicsRosterPage.new @driver
    @academics_api = ApiAcademicsCourseProvisionPage.new @driver

    # Get roster and section data for the site
    @splash_page.load_page
    @splash_page.basic_auth teacher.uid
    @rosters_api.get_feed(@driver, course)
    @academics_api.get_feed(@driver)
    @current_semester = @academics_api.semester_name @academics_api.current_semester(@academics_api.all_teaching_semesters)
    @driver.manage.delete_all_cookies

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.masquerade_as(@driver, teacher)
  end

  after(:all) { Utils.quit_browser @driver }

  it 'offers an E-Grades Export button on the Gradebook' do
    @canvas.load_gradebook course
    @canvas.click_e_grades_export_button
    @e_grades_export_page.wait_until(Utils.medium_wait) { @e_grades_export_page.title == 'Download E-Grades' }
  end

  context 'when no grading scheme is enabled and an assignment is muted' do

    before(:all) do
      @canvas.disable_grading_scheme course
      @canvas.mute_assignment course
    end

    before(:each) { @e_grades_export_page.load_embedded_tool(@driver, course) }

    it 'prevents the user continuing while both problems remain' do
      @e_grades_export_page.continue_button_element.when_visible Utils.medium_wait
      expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true')
    end

    it 'offers a "How to mute assignments in Gradebook" link' do
      expect(@e_grades_export_page.external_link_valid?(@driver, @e_grades_export_page.how_to_mute_link_element, 'How do I mute or unmute an assignment in the Gradebook? | Canvas Instructor Guide | Canvas Guides')).to be true
    end

    it 'offers a "See in Gradebook" link' do
      @e_grades_export_page.wait_for_load_and_click @e_grades_export_page.see_gradebook_button_element
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url == "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook" }
    end

    it 'offers a "How to set a Grading Scheme" link' do
      expect(@e_grades_export_page.external_link_valid?(@driver, @e_grades_export_page.how_to_set_scheme_link_element, 'How do I enable a grading scheme for a course? | Canvas Instructor Guide | Canvas Guides')).to be true
    end

    it 'offers a "Course Settings" link' do
      @e_grades_export_page.wait_for_load_and_click @e_grades_export_page.course_settings_button_element
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url.include? "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings" }
    end

    it 'allows the user to Cancel' do
      @e_grades_export_page.wait_for_load_and_click_js @e_grades_export_page.cancel_button_element
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url == "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook" }
    end

    it 'prevents the user continuing while only "Unmute All" is checked' do
      @e_grades_export_page.click_un_mute_all
      expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true')
    end

    it 'prevents the user continuing while only "Enable default" grading scheme is checked' do
      @e_grades_export_page.click_set_default_scheme
      expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true')
    end

    it 'allows the user to proceed if both "Unmute All" and "Enable default" grading scheme are checked' do
      @e_grades_export_page.click_un_mute_all
      @e_grades_export_page.click_set_default_scheme
      @e_grades_export_page.click_continue
      @e_grades_export_page.sections_select_element.when_visible Utils.medium_wait
    end
  end

  context 'when a grading scheme is enabled but an assignment is muted' do

    before(:all) do
      @canvas.mute_assignment course
      @e_grades_export_page.load_embedded_tool(@driver, course)
    end

    it('offers a "How to mute assignments in Gradebook" link') { expect(@e_grades_export_page.how_to_mute_link_element.when_present Utils.medium_wait).to be_truthy }
    it('offers a "See in Gradebook" link') { expect(@e_grades_export_page.see_gradebook_button_element.when_present Utils.medium_wait).to be_truthy }
    it('prevents the user continuing while the problem remains') { expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true') }
    it('shows no "Set Grading Scheme" elements') { expect(@e_grades_export_page.set_scheme_cbx_element.visible?).to be false }

    it 'allows the user to proceed if "Unmute All" is checked' do
      @e_grades_export_page.click_un_mute_all
      @e_grades_export_page.click_continue
      @e_grades_export_page.sections_select_element.when_visible Utils.medium_wait
    end
  end

  context 'when no assignment is muted but no grading scheme is enabled' do

    before(:all) do
      @canvas.disable_grading_scheme course
      @e_grades_export_page.load_embedded_tool(@driver, course)
    end

    it('offers a "How to set a Grading Scheme" link') { expect(@e_grades_export_page.how_to_set_scheme_link_element.when_present Utils.medium_wait).to be_truthy }
    it('offers a "Course Settings" link') { expect(@e_grades_export_page.course_settings_button_element.when_present Utils.medium_wait).to be_truthy }
    it('prevents the user continuing while the problem remains') { expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true') }
    it('shows no "Unmute Assignments" elements') { expect(@e_grades_export_page.un_mute_all_cbx_element.visible?).to be false }

    it 'allows the user to proceed if "Enable default" grading scheme is checked' do
      @e_grades_export_page.click_set_default_scheme
      @e_grades_export_page.click_continue
      @e_grades_export_page.sections_select_element.when_visible Utils.medium_wait
    end
  end

  # Canvas and BCS test environments are on different refresh schedules, so their enrollment data can differ in the current term.
  # Only compare their enrollment data if the term is in the past and no longer changing.

  context 'when no assignment is muted and a grading scheme is enabled' do

    it 'loads the Download page' do
      @e_grades_export_page.load_embedded_tool(@driver, course)
      @e_grades_export_page.sections_select_element.when_visible Utils.medium_wait
    end

    it 'allows the user the select any section on the course site' do
      expected_options = @rosters_api.section_names.sort
      expect(@e_grades_export_page.sections_select_options.sort).to eql(expected_options)
    end

    it 'allows the user to download current grades for a primary section' do
      csv = @e_grades_export_page.grades_to_hash @e_grades_export_page.download_current_grades(course, primary_section)
      if course.term == @current_semester
        expect(csv.any?).to be true
      else
        expected_sids = @rosters_api.student_ids @rosters_api.section_students("#{primary_section.course} #{primary_section.label}")
        actual_sids = csv.map { |k| k[:id] }
        expect(actual_sids.sort).to eql(expected_sids.sort)
      end
    end

    it 'allows the user to download current grades for a secondary section' do
      csv = @e_grades_export_page.grades_to_hash @e_grades_export_page.download_current_grades(course, secondary_section)
      if course.term == @current_semester
        expect(csv.any?).to be true
      else
        expected_sids = @rosters_api.student_ids @rosters_api.section_students("#{secondary_section.course} #{secondary_section.label}")
        actual_sids = csv.map { |k| k[:id] }
        expect(actual_sids.sort).to eql(expected_sids.sort)
      end
    end

    it 'allows the user to download final grades for a primary section' do
      csv = @e_grades_export_page.grades_to_hash @e_grades_export_page.download_final_grades(course, primary_section)
      if course.term == @current_semester
        expect(csv.any?).to be true
      else
        expected_sids = @rosters_api.student_ids @rosters_api.section_students("#{primary_section.course} #{primary_section.label}")
        actual_sids = csv.map { |k| k[:id] }
        expect(actual_sids.sort).to eql(expected_sids.sort)
      end
    end

    it 'allows the user to download final grades for a secondary section' do
      csv = @e_grades_export_page.grades_to_hash @e_grades_export_page.download_current_grades(course, secondary_section)
      if course.term == @current_semester
        expect(csv.any?).to be true
      else
        expected_sids = @rosters_api.student_ids @rosters_api.section_students("#{secondary_section.course} #{secondary_section.label}")
        actual_sids = csv.map { |k| k[:id] }
        expect(actual_sids.sort).to eql(expected_sids.sort)
      end
    end
  end

  describe 'CSV export' do

    before(:all) do
      section_name = "#{primary_section.course} #{primary_section.label}"
      @students = @rosters_api.section_students section_name
      @csv = @e_grades_export_page.download_final_grades(course, primary_section)
      @csv_parsed = @e_grades_export_page.grades_to_hash @csv
    end

    it 'has the right column headers' do
      expected_header = %w(id name grade grading_basis comments).map { |h| h.to_sym }
      actual_header = @csv.headers
      expect(actual_header).to eql(expected_header)
    end

    it 'has the right SIDs' do
      expected_sids = @rosters_api.student_ids @students
      actual_sids = @csv_parsed.map { |s| s[:id] }
      expect(actual_sids.any? &:empty?).to be false
      expect(actual_sids.sort).to eql(expected_sids.sort)
    end

    it 'has the right names' do
      # Compare last names only, since preferred names can cause mismatches
      expected_names = @rosters_api.student_last_names @students
      actual_names = @csv_parsed.map { |n| n[:name].split(',')[0].strip }
      expect(actual_names.any? &:empty?).to be false
      expect(actual_names.sort).to eql(expected_names)
    end

    it 'has reasonable grades' do
      expected_grades = %w(A A- B+ B B- C+ C C- D+ D D- F)
      actual_grades = @csv_parsed.map { |g| g[:grade] }
      expect(actual_grades.any? &:empty?).to be false
      expect((actual_grades - expected_grades).any?).to be false
    end

    it 'has reasonable grading bases' do
      expected_grading_bases = %w(GRD EPN)
      actual_grading_bases = @csv_parsed.map { |b| b[:grading_basis] }
      expect(actual_grading_bases.any? &:empty?).to be false
      expect((actual_grading_bases - expected_grading_bases).any?).to be false
    end

    it 'includes a comment if the user is taking the class Pass/No Pass' do
      @csv_parsed.each do |g|
        logger.error "SID #{g[:id]} is missing a Grading Basis comment" if g[:grading_basis] == 'EPN' && g[:comments].nil?
        logger.error "SID #{g[:id]} has an unexpected Grading Basis comment" if %w(GRD EPN).include? g[:grading_basis] && !g[:comments].nil?
        (g[:grading_basis] == 'EPN') ? (expect(g[:comments]).to eql('Opted for P/NP Grade')) : ((expect(g[:comments].empty?).to be true))
      end
    end
  end

  describe 'user role restrictions' do

    before(:all) do
      [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|
        @course_add_user_page.load_embedded_tool(@driver, course)
        @course_add_user_page.search(user.uid, 'CalNet UID')
        @course_add_user_page.add_user_by_uid(user, primary_section)
      end
    end

    [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|
      it "allows a course #{user.role} to access the tool if permitted to do so" do
        @canvas.masquerade_as(@driver, user, course)
        logger.debug "Checking a #{user.role}'s access to the tool"
        @e_grades_export_page.load_embedded_tool(@driver, course)

        if ['Lead TA', 'TA', 'Reader'].include? user.role
          @canvas.load_gradebook course
          @canvas.click_e_grades_export_button
          @e_grades_export_page.switch_to_canvas_iframe @driver
          @e_grades_export_page.not_auth_msg_element.when_visible Utils.medium_wait

        elsif ['Designer', 'Student', 'Waitlist Student', 'Observer'].include? user.role
          @e_grades_export_page.load_embedded_tool(@driver, course)
          @e_grades_export_page.not_auth_msg_element.when_visible Utils.medium_wait
        end
      end
    end
  end
end
