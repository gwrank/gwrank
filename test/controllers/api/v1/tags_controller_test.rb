require "test_helper"

module Api::V1
  class TagsControllerTest < ActionDispatch::IntegrationTest
    test "is public (no bearer token)" do
      get api_v1_tags_path
      assert_response :success
    end

    test "lists active tags ordered by position" do
      get api_v1_tags_path
      assert_equal %w[GvG HA RA TA AB FA JQ PvP PvE], response.parsed_body["tags"]
    end

    test "excludes deactivated tags" do
      teambuild_tags(:gvg).update!(active: false)
      get api_v1_tags_path
      assert_not_includes response.parsed_body["tags"], "GvG"
    end

    test "sets a short shared cache header" do
      get api_v1_tags_path
      assert_match "max-age=300", response.headers["Cache-Control"]
    end
  end
end
