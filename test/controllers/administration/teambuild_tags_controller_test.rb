require "test_helper"

module Administration
  class TeambuildTagsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @admin = create_player(is_admin: true)
      @player = create_player
    end

    test "redirects non-admin players" do
      sign_in @player
      get administration_teambuild_tags_path
      assert_redirected_to root_path
    end

    test "admin lists tags" do
      sign_in @admin
      get administration_teambuild_tags_path
      assert_response :success
      assert_select "body", text: /Teambuild tags/
      assert_select 'input[name="teambuild_tag[name]"][value="GvG"]'
      assert_select "code", text: "gvg"
    end

    test "admin creates a tag from its name" do
      sign_in @admin
      assert_difference "TeambuildTag.count", 1 do
        post administration_teambuild_tags_path, params: { teambuild_tag: { name: "Tombs" } }
      end
      assert_redirected_to administration_teambuild_tags_path
      assert_equal "tombs", TeambuildTag.find_by(name: "Tombs").slug
    end

    test "admin updates name, position and toggles active" do
      sign_in @admin
      tag = teambuild_tags(:gvg)
      patch administration_teambuild_tag_path(tag),
            params: { teambuild_tag: { name: "GvG", position: 42, active: false } }
      assert_redirected_to administration_teambuild_tags_path
      assert_equal false, tag.reload.active
      assert_equal 42, tag.position
    end

    test "slug is immutable on update" do
      sign_in @admin
      tag = teambuild_tags(:gvg)
      patch administration_teambuild_tag_path(tag),
            params: { teambuild_tag: { name: "Renamed", position: 42, active: true } }
      assert_equal "gvg", tag.reload.slug
    end
  end
end
