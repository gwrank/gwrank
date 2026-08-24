module GWLayoutHelper
  MAIN_NAV_ITEMS = [
    { label: "Builds", path: "/builds" },
    { label: "Archives", path: "/tournaments" },
    { label: "Docs", path: "/build" }
  ].freeze

  def main_nav_items
    MAIN_NAV_ITEMS
  end
end
