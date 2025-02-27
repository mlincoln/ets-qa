require_relative '../../util/spec_helper'

describe 'Asset Library', order: :defined do

  test_id = Utils.get_test_id
  category_id = "#{Time.now.to_i}"
  timeout = Utils.short_wait

  # Get test users
  user_test_data = Utils.load_test_users.select { |data| data['tests']['assetLibraryCategorySearch'] }
  users = user_test_data.map { |data| User.new(data) if ['Teacher', 'Designer', 'Lead TA', 'TA', 'Observer', 'Reader', 'Student'].include? data['role'] }
  teacher = users.find { |user| user.role == 'Teacher' }
  students = users.select { |user| user.role == 'Student' }
  student_1 = students[0]
  student_2 = students[1]
  student_3 = students[2]
  student_1_upload = Asset.new student_1.assets.find { |asset| asset['type'] == 'File' }
  student_2_upload = Asset.new student_2.assets.find { |asset| asset['type'] == 'File' }
  student_3_link = Asset.new student_3.assets.find { |asset| asset['type'] == 'Link' }
  
  category_1 = "Category 1 #{category_id}"
  category_2 = "Category 2 #{category_id}"

  before(:all) do
    @course = Course.new({title: "Asset Library Search #{test_id}", site_id: ENV['COURSE_ID']})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

    # Create course site if necessary, disabling the Impact Studio if it is present
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::WHITEBOARDS])
    @canvas.disable_tool(@course, SuiteCTools::IMPACT_STUDIO)
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @whiteboards_url = @canvas.click_tool_link(@driver, SuiteCTools::WHITEBOARDS)

    @canvas.masquerade_as(@driver, student_1, @course)
    @canvas.load_course_site(@driver, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    student_1_upload.title = "Student 1 upload - #{test_id}"
    @asset_library.upload_file_to_library student_1_upload
    student_1_upload.id = @asset_library.list_view_asset_ids.first
  end

  after(:all) { @driver.quit }

  describe 'categories' do

    users.each do |user|
      it "can be managed by a course #{user.role} if the user has permission to do so" do
        @canvas.masquerade_as(@driver, user, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.search_input_element.when_visible timeout
        (['Teacher', 'Lead TA', 'TA', 'Designer', 'Reader'].include? user.role) ?
            (expect(@asset_library.manage_assets_link?).to be true) :
            (expect(@asset_library.manage_assets_link?).to be false)
      end
    end

    context 'when created' do

      before(:all) do
        @canvas.masquerade_as(@driver, teacher, @course)
      end

      it 'require a title' do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.click_manage_assets_link
        @asset_library.wait_for_update_and_click_js @asset_library.custom_category_input_element
        expect(@asset_library.add_custom_category_button_element.attribute('disabled')).to eql('true')
      end

      it 'required a title under 256 characters' do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.click_manage_assets_link
        @asset_library.wait_for_element_and_type_js(@asset_library.custom_category_input_element, "#{'A loooooong title' * 15}?")
        expect(@asset_library.add_custom_category_button_element.attribute('disabled')).to eql('true')
      end

      it 'are added to the list of available categories' do
        @asset_library.add_custom_categories(@driver, @asset_library_url, [category_1, category_2])
        @asset_library.wait_until(timeout) { @asset_library.custom_category_titles.include? category_1 }
      end

      it 'can be added to existing assets' do
        student_1_upload.category = category_1
        @asset_library.load_asset_detail(@driver, @asset_library_url, student_1_upload)
        @asset_library.edit_asset_details student_1_upload
        @asset_library.wait_until(timeout) do
          @asset_library.detail_view_asset_category_elements.any?
          sleep 1
          @asset_library.detail_view_asset_category_elements[0].text == student_1_upload.category
        end
      end

      it 'show how many assets with which they are associated' do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.click_manage_assets_link
        index = @asset_library.custom_category_index category_1
        expect(@asset_library.custom_category_asset_count index).to eql('Used by 1 item')
      end

      it 'appear on the asset detail of associated assets as links to the asset library filtered for that category' do
        @asset_library.go_back_to_asset_library
        @asset_library.click_asset_link_by_id student_1_upload
        @asset_library.click_asset_category 0
        @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.first.include? student_1_upload.id }
        @asset_library.wait_until(timeout) { @asset_library.keyword_search_input.empty? }
        @asset_library.wait_until(timeout) { @asset_library.category_select == category_1 }
        @asset_library.wait_until(timeout) { @asset_library.uploader_select == 'Uploader' }
        @asset_library.wait_until(timeout) { @asset_library.asset_type_select == 'Asset type' }
        @asset_library.wait_until(timeout) { @asset_library.sort_by_select == 'Most recent' }
      end
    end

    context 'when edited' do

      before(:all) do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.click_manage_assets_link
        @index = @asset_library.custom_category_index category_1
      end

      before(:each) do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.click_manage_assets_link
        @asset_library.wait_until(timeout) { @asset_library.custom_category_titles.include? category_1 }
      end

      it 'can be canceled' do
        @asset_library.click_edit_custom_category @index
        @asset_library.click_cancel_custom_category_edit @index
        @asset_library.wait_until(timeout) { @asset_library.edit_category_form_elements.empty? }
      end

      it 'require a title' do
        @asset_library.click_edit_custom_category @index
        @asset_library.enter_edited_category_title(@index, '')
        @asset_library.category_title_error_msg_element.when_visible timeout
      end

      it 'are updated on assets with which they are associated' do
        @asset_library.click_edit_custom_category @index
        @asset_library.enter_edited_category_title(@index, category_1 = "#{category_1} - Edited")
        @asset_library.click_save_custom_category_edit @index
        @asset_library.wait_until(timeout) { @asset_library.custom_category_titles[@index] == category_1 }
      end
    end

    context 'when deleted' do

      it 'no longer appear in the list of categories' do
        @asset_library.delete_custom_category category_1
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.click_manage_assets_link
        @asset_library.wait_until(timeout) { !@asset_library.custom_category_titles.include?(category_1) }
      end

      it 'no longer appear in search options' do
        @asset_library.go_back_to_asset_library
        @asset_library.wait_for_update_and_click_js @asset_library.advanced_search_button_element
        @asset_library.category_select_element.when_visible timeout
        expect(@asset_library.category_select_options).not_to include(category_1)
      end

      it 'no longer appear on asset detail' do
        @asset_library.click_asset_link_by_id student_1_upload
        @asset_library.detail_view_asset_no_category_element.when_present timeout
      end
    end
  end

  describe 'search' do

    before(:all) do

      # Upload a file asset
      student_2_upload.title = "Student 2 upload - #{test_id}"
      student_2_upload.category = category_2
      student_2_upload.description = "Description for uploaded file #{test_id}"
      @canvas.masquerade_as(@driver, student_2, @course)
      @canvas.load_course_site(@driver, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.upload_file_to_library student_2_upload

      # Add a link asset
      student_3_link.title = "Student 3 link - #{test_id}"
      student_3_link.category = category_2
      student_3_link.description = "#BetterTogether#{test_id}"
      @canvas.masquerade_as(@driver, student_3, @course)
      @canvas.load_course_site(@driver, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.add_site student_3_link

      # Create a whiteboard, export it, and add two comments
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboard = Whiteboard.new({owner: student_3, title: "Whiteboard #{test_id}", collaborators: [student_1, student_2]})
      @whiteboards.create_whiteboard @whiteboard
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @whiteboards.add_existing_assets [student_2_upload]
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? student_2_upload.id }
      @whiteboard_asset = @whiteboards.export_to_asset_library @whiteboard
      @asset_library.load_page(@driver, @asset_library_url)
      @whiteboard_asset.id = @asset_library.list_view_asset_ids.first
      @asset_library.load_asset_detail(@driver, @asset_library_url, @whiteboard_asset)
      @asset_library.add_comment 'Comment from asset owner'
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.any? }
      @asset_library.reply_to_comment(0, 'Reply from asset owner')
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 2 }

      # Add a comment to an asset and like it
      @asset_library.load_asset_detail(@driver, @asset_library_url, student_2_upload)
      @asset_library.add_comment '#BadHombre'
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.any? }
      @asset_library.toggle_detail_view_item_like

      # View an asset and like it
      @canvas.masquerade_as(@driver, student_2, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, student_3_link)
      @asset_library.toggle_detail_view_item_like

      # View an asset and like it, then view another
      @canvas.masquerade_as(@driver, student_1, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, student_3_link)
      @asset_library.toggle_detail_view_item_like
      @asset_library.load_asset_detail(@driver, @asset_library_url, student_2_upload)
      @asset_library.go_back_to_asset_library
    end

    # By default, Asset Library "simple search" filters results by string or hashtag.

    it 'lets a user perform a simple search by a string in the title' do
      @asset_library.simple_search "link - #{test_id}"
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id] }
    end

    it 'lets a user perform a simple search by a string in the description' do
      @asset_library.simple_search "uploaded file #{test_id}"
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'lets a user perform a simple search by a hashtag in the description' do
      @asset_library.simple_search "#BetterTogether#{test_id}"
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id] }
    end

    it 'lets a user perform an advanced search by a string in the title, sorted by Most Recent' do
      @asset_library.advanced_search("link - #{test_id}", nil, nil, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id] }
    end

    it 'lets a user perform an advanced search by a string in the description, sorted by Most Recent' do
      @asset_library.advanced_search("uploaded file #{test_id}", nil, nil, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by a hashtag in the description, sorted by Most Recent' do
      @asset_library.advanced_search("#BetterTogether #{test_id}", nil, nil, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id] }
    end

    it 'lets a user perform an advanced search by category, sorted by Most Recent' do
      @asset_library.advanced_search(nil, category_2, nil, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id, student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by uploader, sorted by Most Recent' do
      @asset_library.advanced_search(nil, nil, student_3, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.include?(@whiteboard_asset.id && student_3_link.id) }
    end

    it 'lets a user perform an advanced search by type, sorted by Most Recent' do
      @asset_library.advanced_search(nil, nil, nil, 'Whiteboard')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.include? @whiteboard_asset.id }
    end

    it 'lets a user perform an advanced search by keyword and category, sorted by Most Recent' do
      @asset_library.advanced_search('upload', category_2, nil, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Recent' do
      @asset_library.advanced_search('link', nil, student_3, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.include? student_3_link.id }
    end

    it 'lets a user perform an advanced search by keyword, category, and uploader, sorted by Most Recent' do
      @asset_library.advanced_search('#BetterTogether', category_2, student_3, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id] }
    end

    it 'lets a user perform an advanced search by keyword and type, sorted by Most Recent' do
      @asset_library.advanced_search("#{test_id}", nil, nil, 'File')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id, student_1_upload.id] }
    end

    it 'lets a user perform an advanced search by category and uploader, sorted by Most Recent' do
      @asset_library.advanced_search(nil, category_2, student_3, nil)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id] }
    end

    it 'lets a user perform an advanced search by uploader and type, sorted by Most Recent' do
      @asset_library.advanced_search(nil, nil, student_2, 'Whiteboard')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.include? @whiteboard_asset.id }
    end

    it 'lets a user perform an advanced search by category and type, sorted by Most Recent' do
      @asset_library.advanced_search(nil, category_2, nil, 'File')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'returns a no results message for an advanced search by a hashtag in a comment, sorted by Most Recent' do
      @asset_library.advanced_search('#BadHombre', nil, nil, nil)
      @asset_library.wait_until(timeout) { @asset_library.no_search_results? }
    end

    it 'lets a user perform an advanced search by keyword, category, and type, sorted by Most Recent' do
      @asset_library.advanced_search('Description', category_2, nil, 'File')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by keyword, uploader, and type, sorted by Most Recent' do
      @asset_library.advanced_search('3', nil, student_3, 'Link')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.include? student_3_link.id }
    end

    it 'lets a user perform an advanced search by keyword, category, uploader, and type, sorted by Most Recent' do
      @asset_library.advanced_search('for', category_2, student_2, 'File')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by keyword, sorted by Most Likes' do
      @asset_library.advanced_search(test_id, nil, nil, nil, 'Most likes')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_3_link.id, student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by keyword, sorted by Most Comments' do
      @asset_library.advanced_search(test_id, nil, nil, nil, 'Most comments')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [@whiteboard_asset.id, student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by keyword, sorted by Most Views' do
      @asset_library.advanced_search(test_id, nil, nil, nil, 'Most views')
      @asset_library.wait_until(timeout) do
        @asset_library.list_view_asset_ids == [student_1_upload.id, student_3_link.id, student_2_upload.id]
      end
    end

    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Likes' do
      @asset_library.advanced_search(test_id, nil, student_1, nil, 'Most likes')
      @asset_library.no_search_results_element.when_visible timeout
    end

    it 'lets a user perform an advanced search by keyword and category, sorted by Most Comments' do
      @asset_library.advanced_search(test_id, category_2, nil, nil, 'Most comments')
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == [student_2_upload.id] }
    end

    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Views' do
      @asset_library.advanced_search(test_id, nil, student_1, nil, 'Most views')
      @asset_library.wait_until(timeout) do
        @asset_library.list_view_asset_ids == [student_1_upload.id]
      end
    end

    it 'lets a user click a commenter name to view the asset gallery filtered by the commenter\'s submissions' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, student_2_upload)
      @asset_library.wait_for_update_and_click_js @asset_library.commenter_link(0)
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids.first.include? @whiteboard_asset.id }
      expect(@asset_library.keyword_search_input).to be_empty
      expect(@asset_library.category_select).to eql('Category')
      expect(@asset_library.uploader_select).to eql(student_3.full_name)
      expect(@asset_library.asset_type_select).to eql('Asset type')
    end

    context 'when there is no Impact Studio' do

      before(:all) do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.open_advanced_search
        @asset_library.sort_by_select_element.when_visible timeout
      end

      it('allows sorting by "Most recent", "Most likes", "Most views", and "Most comments"') do
        expect(@asset_library.sort_by_select_options).to eql(['Most recent', 'Most likes', 'Most views', 'Most comments'])
      end
    end

    context 'when there is an Impact Studio' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @canvas.add_suite_c_tool(@course, SuiteCTools::IMPACT_STUDIO)
        @canvas.click_tool_link(@driver, SuiteCTools::IMPACT_STUDIO)
        @all_assets = [student_1_upload, student_2_upload, student_3_link, @whiteboard_asset]
        @all_assets.each { |asset| asset.impact_score = DBUtils.get_asset_impact_score(asset) }
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.open_advanced_search
      end

      it('allows sorting by "Most recent", "Most likes", "Most views", "Most comments", and "Most impactful"') do
        expect(@asset_library.sort_by_select_options).to eql(['Most recent', 'Most likes', 'Most views', 'Most comments', 'Most impactful'])
      end

      it('lets a user perform an advanced search by keyword, sorted by Most Impactful') do
        @asset_library.advanced_search(test_id, nil, nil, nil, 'Most impactful')
        @asset_library.wait_until(timeout) { @asset_library.list_view_asset_ids == @asset_library.impactful_asset_ids(@all_assets) }
      end

    end
  end
end
