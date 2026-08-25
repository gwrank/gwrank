module GWLayoutHelper
  def main_nav_items
    [
      { label: "Builds", path: builds_path },
      { label: "Archives", path: tournaments_path },
      { label: "Docs", path: build_doc_path }
    ]
  end

  def gw_nav_active?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end
end
