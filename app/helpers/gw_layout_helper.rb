module GWLayoutHelper
  def main_nav_items
    [
      { label: "Builds", path: builds_path },
      { label: "Bot & Docs", path: bot_path },
      { label: "Archives", path: tournaments_path }
    ]
  end

  def gw_nav_active?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end
end
