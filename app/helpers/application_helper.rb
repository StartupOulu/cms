module ApplicationHelper
  # Renders inline markdown (bold, italic, links) as HTML.
  # Input is HTML-escaped first so no injection is possible.
  def inline_markdown(text)
    return "".html_safe if text.blank?

    result = ERB::Util.html_escape(text.to_s)
    result = result.gsub(/\*\*(.+?)\*\*/m) { "<strong>#{$1}</strong>" }
    result = result.gsub(/\*(.+?)\*/m)     { "<em>#{$1}</em>" }
    result = result.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
      label, url = $1, $2
      url.match?(/\Ahttps?:\/\/|\A\//) ? "<a href=\"#{url}\">#{label}</a>" : label
    end
    result.html_safe
  end
end
