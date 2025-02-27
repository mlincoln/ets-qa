require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCreateCourseSitePage < CanvasSiteCreationPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      button(:maintenance_button, class: 'bc-template-canvas-maintenance-notice-button')
      div(:maintenance_notice, class: 'bc-template-canvas-maintenance-notice-details')
      link(:bcourses_service, xpath: '//a[contains(text(),"bCourses service page")]')
      button(:need_help, xpath: '//button[contains(.,"Need help deciding which official sections to select")]')
      div(:help, id: 'section-selection-help')

      button(:switch_mode, class: 'bc-page-create-course-site-admin-mode-switch')

      span(:switch_to_instructor, xpath: '//span[contains(.,"Switch to acting as instructor")]')
      button(:as_instructor_button, xpath: '//button[text()="As instructor"]')
      text_area(:instructor_uid, id: 'instructor-uid')

      span(:switch_to_ccn, xpath: '//span[contains(.,"Switch to CCN input")]')
      button(:review_ccns_button, xpath: '//button[text()="Review matching CCNs"]')
      text_area(:ccn_list, id: 'bc-page-create-course-site-ccn-list')

      button(:next_button, xpath: '//button[text()="Next"]')
      link(:cancel_link, text: 'Cancel')

      text_area(:site_name_input, id: 'siteName')
      text_area(:site_abbreviation, id: 'siteAbbreviation')

      button(:create_site_button, xpath: '//button[text()="Create Course Site"]')
      button(:go_back_button, xpath: '//button[text()="Go Back"]')

      # Loads the LTI tool in the Junction context
      def load_standalone_tool
        logger.info 'Loading standalone version of Create Course Site tool'
        navigate_to "#{Utils.junction_base_url}/canvas/create_course_site"
      end

      # Clicks the button for the test course's term. Uses JavaScript rather than WebDriver
      # @param course [Course]
      def choose_term(course)
        button_element(xpath: "//label[contains(.,'#{course.term}')]/preceding-sibling::input").when_visible Utils.long_wait
        wait_for_update_and_click_js button_element(xpath: "//label[contains(.,'#{course.term}')]/preceding-sibling::input")
      end

      # Searches for a course by instructor UID, by section ID list, or by neither depending on the workflow associated
      # with the test course.
      # @param course [Course]
      # @param instructor [User]
      # @param sections [Array<Section>]
      def search_for_course(course, instructor, sections)
        logger.debug "Searching for #{course.code} in #{course.term}"
        if course.create_site_workflow == 'uid'
          uid = instructor.uid
          logger.debug "Searching by instructor UID #{uid}"
          switch_mode unless switch_to_ccn?
          wait_for_element_and_type_js(instructor_uid_element, uid)
          wait_for_update_and_click_js as_instructor_button_element
          choose_term course
        elsif course.create_site_workflow == 'ccn'
          logger.debug 'Searching by CCN list'
          switch_mode unless switch_to_instructor?
          choose_term course
          sleep 1
          ccn_list = sections.map { |section| section.id }
          logger.debug "CCN list is '#{ccn_list}'"
          wait_for_element_and_type_js(ccn_list_element, ccn_list.join(', '))
          wait_for_update_and_click_js review_ccns_button_element
        else
          logger.debug 'Searching as the instructor'
          choose_term course
        end
      end

      # Clicks the 'need help' button
      def click_need_help
        button_element(xpath: '//button[contains(.,"Need help deciding which official sections to select")]').click
      end

      # Given a section ID, returns a hash of section data displayed on that row
      # @param driver [Selenium::WebDriver]
      # @param section_id [String]
      # @return [Hash]
      def section_data(driver, section_id)
        {
          code: section_course_code(section_id),
          label: section_label(section_id),
          id: section_id,
          schedules: section_schedules(driver, section_id),
          locations: section_locations(driver, section_id),
          instructors: section_instructors(driver, section_id)
        }
      end

      # Given an array of sections, selects the corresponding rows
      # @param sections [Array<Section>]
      def select_sections(sections)
        sections.each do |section|
          logger.debug "Selecting section ID #{section.id}"
          wait_for_update_and_click_js section_checkbox(section.id) unless section_checkbox(section.id).checked?
        end
      end

      # Returns the checkbox for a given section
      # @param section_id [String]
      # @return [PageObject::Elements::CheckBox]
      def section_checkbox(section_id)
        checkbox_element(xpath: "//input[contains(@id,'#{section_id}')]")
      end

      # Returns the course code for a section
      # @param section_id [String]
      # @return [String]
      def section_course_code(section_id)
        span_element(xpath: "//input[contains(@id,'#{section_id}')]/ancestor::tbody//td[contains(@class, 'course-code')]/span").text
      end

      # Returns the label for a section
      # @param section_id [String]
      # @return [String]
      def section_label(section_id)
        label_element(xpath: "//label[@for='cc-template-canvas-manage-sections-checkbox-#{section_id}']").text
      end

      # Returns the schedules for a section
      # @param driver [Selenium::WebDriver]
      # @param section_id [String]
      # @return [Array<String>]
      def section_schedules(driver, section_id)
        (e = div_element(xpath: "//input[contains(@id,'#{section_id}')]/../ancestor::tbody//td[contains(@class, 'section-timestamps')]/div")).exists? ?
            e.text : ''
      end

      # Returns the locations for a section
      # @param driver [Selenium::WebDriver]
      # @param section_id [String]
      # @return [Array<String>]
      def section_locations(driver, section_id)
        (e = div_element(xpath: "//input[contains(@id,'#{section_id}')]/../ancestor::tbody//td[contains(@class, 'section-locations')]/div")).exists? ?
            e.text : ''
      end

      # Returns the instructor names for a section
      # @param driver [Selenium::WebDriver]
      # @param section_id [String]
      # @return [Array<String>]
      def section_instructors(driver, section_id)
        (e = div_element(xpath: "//input[contains(@id,'#{section_id}')]/../ancestor::tbody//td[contains(@class, 'section-instructors')]/div")).exists? ?
            e.text : ''
      end

      # Returns the section IDs displayed under a course
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      # @return [Array<String>]
      def course_section_ids(driver, course)
        driver.find_elements(xpath: "//button[contains(.,'#{course.code}')]/following-sibling::div//td[@data-ng-bind='section.ccn']").map &:text
      end

      # Clicks the 'next' button once it is enabled
      def click_next
        wait_until(Utils.short_wait) { !next_button_element.attribute('disabled') }
        wait_for_update_and_click_js next_button_element
        site_name_input_element.when_visible Utils.medium_wait
      end

      # Enters a unique course site name and abbreviation and returns the abbreviation
      # @param course [Course]
      # @return [String]
      def enter_site_titles(course)
        site_abbreviation = "QA bCourses Test #{Utils.get_test_id}"
        wait_for_element_and_type_js(site_name_input_element, "#{site_abbreviation} - #{course.code}")
        wait_for_element_and_type_js(site_abbreviation_element, site_abbreviation)
        site_abbreviation
      end

      # Clicks the final create site button
      def click_create_site
        wait_for_update_and_click_js create_site_button_element
      end

      # Combines methods to search for a course, select sections, and create a new site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      # @param user [User]
      # @param sections [Array<Section>]
      def provision_course_site(driver, course, user, sections)
        load_embedded_tool(driver, user)
        click_create_course_site
        course.create_site_workflow = nil
        search_for_course(course, user, sections)
        expand_available_sections course.code
        select_sections sections
        click_next
        enter_site_titles course
        click_create_site
        wait_until(Utils.long_wait) { current_url.include? "#{Utils.canvas_base_url}/courses" }
        course.site_id = current_url.delete "#{Utils.canvas_base_url}/courses/"
        logger.info "Course site ID is #{course.site_id}"
      end

    end
  end
end
