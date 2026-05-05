require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # System tests must not run in parallel: each test needs its own server
  # thread sharing the same DB connection as the test thread, and SQLite
  # write-lock contention makes parallelism unreliable here.
  parallelize(workers: 1)

  # Puma must also run single-threaded so that every HTTP request the browser
  # makes is handled on the same OS thread that owns the test DB connection.
  # With multiple threads, a lagging request from the previous test can arrive
  # on a different thread that has no access to the open test transaction,
  # causing intermittent "session not found → redirect to sign-in" failures.
  Capybara.server = :puma, { Threads: "1:1" }

  # Signs in via the real sign-in form so the full auth path is exercised.
  # Raises if sign-in does not succeed (e.g. wrong fixture credentials).
  def sign_in(email: "admin@example.com", password: "password")
    visit new_session_path
    # Set values and submit entirely via JS to bypass Selenium's coordinate-based
    # click and any browser-state issue where fill_in values get cleared before
    # submission (reproducibly happens after certain navigation sequences in tests).
    execute_script(<<~JS)
      var f = document.querySelector('input[name="email_address"]').closest('form');
      f.querySelector('input[name="email_address"]').value = #{email.to_json};
      f.querySelector('input[name="password"]').value = #{password.to_json};
      f.submit();
    JS
    assert_no_current_path new_session_path, wait: 5
  end

  # Disables HTML5 built-in form validation so server-side errors can be tested.
  def disable_html5_validation
    execute_script("document.querySelectorAll('form').forEach(f => f.setAttribute('novalidate', ''))")
  end

  # Sets a datetime-local input value reliably across platforms.
  def set_datetime(field_name, value)
    execute_script(
      "document.querySelector('input[name=\"#{field_name}\"]').value = '#{value}'"
    )
  end
end
