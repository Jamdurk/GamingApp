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

      test "should create clip with valid data and redirect" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip",
            start_time: "00:01:10",  
            end_time: "00:01:40"     
          }
        }
        
        assert_response :redirect 
        assert_redirected_to recording_path(recording)
        assert_match "Clip is being processed in the background.", flash[:notice]
      end

      test "should not create clip with blank title" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "",
            start_time: "00:01:10",  
            end_time: "00:01:40"     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Title can't be blank"  
      end

      
      test "should not create clip with no start time" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip",
            start_time: "",  
            end_time: "00:01:40"     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Start time can't be blank"  
      end

      
      test "should not create clip with no end time" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip",
            start_time: "00:01:10",  
            end_time: ""     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "End time can't be blank"  
      end

      test "should not create clip with start time thats after end time" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip",
            start_time: "00:01:10",  
            end_time: "00:01:05"     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Start time must be before end time"  
      end 
      
      test "should not create clip with start time thats equal to end time" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip",
            start_time: "00:01:10",  
            end_time: "00:01:10"     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Start time must be before end time"  
      end

      test "should not create clip with invalid time format" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip Invalid Time",
            start_time: "99:99:99",  
            end_time: "00:01:10"     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Start time must be before end time"
      end

    

      test "should not create clip with title exceeding 30 characters" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Test Test Test Test Test Test Clip",
            start_time: "00:01:10",  
            end_time: "00:01:30"     
          }
        }
      
        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Title is too long (maximum is 30 characters)"  
      end

      test "should not create clip with dupilcate title" do
        recording = recordings(:for_clips) 
        attach_video(recording)
        
        post recording_clips_path(recording), params: {
          clip: {
            title: "Test Clip Dup",
            start_time: "00:01:10",  
            end_time: "00:01:30"     
          }
        }
        assert_response :redirect
      
        recording_dup = recordings(:lethal_company)
        attach_video(recording_dup)
        post recording_clips_path(recording_dup), params: {
          clip: {
            title: "Test Clip Dup",
            start_time: "00:02:10",  
            end_time: "00:03:30"     
          }
        }

        assert_response :unprocessable_entity
        assert_select "#error_explanation"
        assert_select "#error_explanation li", "Title has already been taken"  
      end

      test "should handle missing recording for new action" do
        get new_recording_clip_path(999999)  
        
        assert_redirected_to recordings_path
        assert_match "Recording not found", flash[:alert]
      end
      
      test "should handle missing recording for create action" do
        post recording_clips_path(999999), params: {
          clip: {
            title: "Test Clip",
            start_time: "00:01:10",
            end_time: "00:01:40"
          }
        }
        
        assert_redirected_to recordings_path
        assert_match "Recording not found", flash[:alert]
      end

      

end
