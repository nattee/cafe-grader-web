require "test_helper"

# The two text-rendering helpers behind the viva transcript. Students type C++
# there, so `<` and `>` must survive verbatim: the browser must never be
# allowed to read `vector<int>` as a tag (which the default sanitizer then
# strips, showing the student a history that is not what they typed).
class ApplicationHelperTest < ActionView::TestCase
  test "simple_format_escaped keeps template brackets literally" do
    html = simple_format_escaped("I used vector<int> v; and a<b && c>d\nsecond line")
    assert_includes html, "vector&lt;int&gt; v;"
    assert_includes html, "a&lt;b &amp;&amp; c&gt;d"
    assert_includes html, "<br />second line"
    assert_no_match %r{<int>|<b>}, html
    assert html.html_safe?
  end

  test "simple_format_escaped neutralizes script tags" do
    html = simple_format_escaped("x <script>alert(1)</script> y")
    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_no_match %r{<script}, html
  end

  test "simple_format_escaped still splits paragraphs" do
    html = simple_format_escaped("one\n\ntwo")
    assert_equal "<p>one</p>\n\n<p>two</p>", html
  end

  test "safe_markdown keeps template brackets in prose and code" do
    assert_includes safe_markdown("Use vector<int> here, or a < b."), "vector&lt;int&gt; here, or a &lt; b."
    assert_includes safe_markdown("Use `vector<pair<int,int>>` here."), "<code class=\"prettyprint\">vector&lt;pair&lt;int,int&gt;&gt;</code>"
  end

  test "safe_markdown escapes raw HTML instead of executing it, autolinks intact" do
    html = safe_markdown("before <script>alert(1)</script> after <http://example.com>")
    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_no_match %r{<script}, html
    assert_includes html, '<a href="http://example.com">http://example.com</a>'
  end
end
