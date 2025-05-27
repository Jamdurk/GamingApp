require "test_helper"

class ClipsControllerTest < ActionDispatch::IntegrationTest

    test "should get new clip page" do
        recording = recordings(:lethal_company)
        get new_recording_clip_path(recording)     
        assert_response :success
      end

      test "should get clips on recording show page" do
        recording = recordings(:for_clips)
        
        get recording_path(recording)
        assert_response :success
        
        assert_select ".clip-name", "Vort Supreme"  
      end

      test "clip ui should have proper attributes" do
        recording = recordings(:lethal_company)
        get new_recording_clip_path(recording)
        assert_response :success

        assert_select ".clip-form-label", "Title"
        assert_select ".clip-form-label", "Start Time"
        assert_select ".clip-form-label", "End Time"
      end

      

end
