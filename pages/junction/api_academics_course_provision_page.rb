require_relative '../../util/spec_helper'

class ApiAcademicsCourseProvisionPage

  include PageObject
  include Logging

  def get_feed(driver)
    logger.info 'Parsing data from /api/academics/canvas/course_provision'
    navigate_to "#{Utils.junction_base_url}/api/academics/canvas/course_provision"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  # SEMESTERS

  def all_teaching_semesters
    @parsed['teachingSemesters']
  end

  def semesters_in_time_bucket(semesters, time_bucket)
    semesters.select { |semester| semester['timeBucket'] == time_bucket }
  end

  def current_semester(semesters)
    semesters && semesters_in_time_bucket(semesters, 'current')[0]
  end

  def future_semesters(semesters)
    semesters_in_time_bucket(semesters, 'future')
  end

  def semester_name(semester)
    semester['name']
  end

  # COURSES

  def semester_courses(semester)
    semester['classes']
  end

  def course_code(course)
    course['course_code']
  end

  def course_listing_course_codes(course)
    codes = []
    course['listings'].each { |listing| codes << listing['course_code'] }
    codes
  end

  def course_title(course)
    course['title'].nil? ? '' : (course['title'].gsub(/\s+/, ' ')).strip
  end

  # SECTIONS

  def section_course_code(section)
    section['courseCode']
  end

  def section_label(section)
    section['section_label']
  end

  def section_ccn(section)
    section['ccn']
  end

  def section_url(section)
    section['url']
  end

  def section_schedules_recurring(section)
    section['schedules'] && section['schedules']['recurring']
  end

  def section_recurring_schedule(section)
    section_schedules = section_schedules_recurring(section).map { |recurring| "#{recurring['schedule']}".gsub(/\s+/, ' ').strip }
    section_schedules.join("\n")
  end

  def section_locations(section)
    section_locations = section_schedules_recurring(section).map do |recurring|
      location = "#{recurring['buildingName']} #{recurring['roomNumber']}"
      location.gsub(/\s+/, ' ').strip
    end
    section_locations.join("\n")
  end

  def section_instructors(section)
    instructors = section['instructors'].map { |instructor| "#{instructor['name']}".gsub(/\s+/, ' ').strip }
    instructors.join("\n")
  end

  def section_data(section)
    {
      code: section_course_code(section),
      label: section_label(section),
      id: section_ccn(section),
      schedules: section_recurring_schedule(section),
      locations: section_locations(section),
      instructors: section_instructors(section)
    }
  end

  def course_sections(course)
    course['sections']
  end

  def course_section_teachers(sections)
    includes_primary_sections = (sections.select { |s| s['is_primary_section'] }).any?
    course_instructors = sections.map do |section|
      includes_primary_sections ?
          section['instructors'].select { |instructor| %w(PI ICNT APRX).include?(instructor['role']) && instructor['gradeRosterAccess'] != ' ' } :
          section['instructors']
    end
    course_instructors.flatten.uniq
  end

  def course_section_tas(sections)
    includes_primary_sections = (sections.select { |s| s['is_primary_section'] }).any?
    course_instructors = sections.map do |section|
      section['instructors'].select { |instructor| instructor['role'] == 'TNIC' if includes_primary_sections }
    end
    course_instructors.flatten.uniq
  end

  # COURSE SITES

  def section_side_ids(section)
    section['siteIds']
  end

  def course_sites(course)
    course['class_sites']
  end

  def course_site_id(course_site)
    course_site['id']
  end

  def course_site_url(course_site)
    course_site['site_url']
  end

  def course_site_name(course_site)
    course_site['name'] && course_site['name'].strip.gsub('  ', ' ')
  end

  def course_site_names(course)
    course_sites(course).map { |site| course_site_name(site) } unless course_sites(course).nil?
  end

  def semester_course_site_names(semester_courses)
    name = semester_courses.map { |course| course_site_names course }
    name.flatten.compact
  end

  def course_site_descrip(course_site)
    course_site['shortDescription'] && course_site['shortDescription'].strip.gsub('  ', ' ')
  end

  def course_site_descrips(course)
    descriptions = []
    unless course_sites(course).nil?
      course_sites(course).each do |site|
        unless course_site_descrip(site).nil? || course_site_descrip(site) == course_site_name(site) || course_site_descrip(site) == course_title(course)
          descriptions << course_site_descrip(site)
        end
      end
    end
    descriptions
  end

  def semester_course_site_descrips(semester_courses)
    descriptions = semester_courses.map { |course| course_site_descrips(course) }
    descriptions.flatten.compact
  end

  # OTHER SITE MEMBERSHIPS

  def other_site_memberships
    @parsed['otherSiteMemberships']
  end

  def other_sites(semester_name)
    sites = other_site_memberships && other_site_memberships.map { |memb| memb['sites'] if memb['name'] == semester_name }
    sites.to_a.flatten.compact
  end

  def other_site_names(sites)
    sites.map { |site| site['name'] }
  end

  def other_site_descriptions(sites)
    sites.map { |site| site['shortDescription'].gsub(/\s+/, ' ') }
  end

end
