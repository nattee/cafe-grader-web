require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  test "admin can access announcements index" do
    sign_in_as("admin", "admin")
    get announcements_path
    assert_response :success
  end

  test "admin can create announcement" do
    sign_in_as("admin", "admin")
    assert_difference("Announcement.count") do
      post announcements_path, params: {
        announcement: { title: "Test", body: "Hello", published: true, frontpage: false }
      }
    end
  end

  test "admin can destroy announcement" do
    sign_in_as("admin", "admin")
    announcement = Announcement.create!(title: "To delete", body: "test", published: false)
    assert_difference("Announcement.count", -1) do
      delete announcement_path(announcement)
    end
  end
end
