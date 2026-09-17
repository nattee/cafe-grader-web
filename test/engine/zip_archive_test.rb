require "test_helper"
require "tmpdir"
require "open3"

# ZIP/archive grading on the judge worker: how a multi-file Digital project
# (the lib/language/digital/Demo.zip fixture: Demo.dig + MyAndOr.dig +
# MANIFEST.TXT) is extracted, how the main circuit is picked, and — when a
# JVM is present — that the whole flow reproduces the 1.sol answer through
# the real Digital.jar exactly as the grader's run.sh would.
class ZipArchiveTest < ActiveSupport::TestCase
  DIGITAL_DIR = Rails.root.join("lib", "language", "digital")
  DEMO_ZIP = DIGITAL_DIR.join("Demo.zip")
  DEMO_TC = Rails.root.join("test", "problem_examples", "digital_demo", "testcases")
  JAVA = "java"

  def setup
    @zip_helper = Class.new { include ZipArchive }.new
  end

  # build a zip whose first entry is named exactly `name`
  def zip_with_entry(name, content, dest)
    Zip::OutputStream.open(dest) do |io|
      io.put_next_entry(name)
      io.write(content)
    end
  end

  test "submitted_archive? is true exactly when binary is present" do
    assert Submission.new(binary: "PK\x03\x04bytes").submitted_archive?
    refute Submission.new(binary: nil).submitted_archive?
  end

  test "archive_filename? accepts zip/jar and rejects single-file uploads" do
    assert Submission.archive_filename?("Demo.zip")
    assert Submission.archive_filename?("solution.jar")
    assert Submission.archive_filename?("UPPER.CASE.ZIP")
    refute Submission.archive_filename?("Demo.dig")
    refute Submission.archive_filename?("main.cpp")
    refute Submission.archive_filename?(nil)
  end

  test "extract_archive flattens the demo project into the destination" do
    Dir.mktmpdir do |dir|
      entries = @zip_helper.extract_archive(DEMO_ZIP, dir)
      assert_equal %w[Demo.dig MANIFEST.TXT MyAndOr.dig], entries
      assert File.file?(File.join(dir, "Demo.dig"))
      assert File.file?(File.join(dir, "MyAndOr.dig"))
      assert_empty Dir.glob("#{dir}/*/"),
                   "extraction must be flat (Digital resolves components by bare name)"
    end
  end

  test "archive_main_file prefers the MANIFEST main circuit" do
    Dir.mktmpdir do |dir|
      @zip_helper.extract_archive(DEMO_ZIP, dir)
      assert_equal "Demo.dig", @zip_helper.archive_main_file(dir, ext: "dig")
    end
  end

  test "archive_main_file falls back to the lone matching file" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "solo.dig"), "<circuit/>")
      assert_equal "solo.dig", @zip_helper.archive_main_file(dir, ext: "dig")
    end
  end

  test "archive_main_file raises on ambiguity and on missing manifest file" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.dig"), "<circuit/>")
      File.write(File.join(dir, "b.dig"), "<circuit/>")
      err = assert_raises(GraderError) { @zip_helper.archive_main_file(dir, ext: "dig") }
      assert_match(/Cannot determine archive main file/, err.message)

      File.write(File.join(dir, "MANIFEST.TXT"), "Main-Circuit: ghost.dig\n")
      err = assert_raises(GraderError) { @zip_helper.archive_main_file(dir, ext: "dig") }
      assert_match(/missing main file 'ghost\.dig'/, err.message)
    end
  end

  test "extract_archive never lets a traversal entry escape the destination" do
    Dir.mktmpdir do |dir|
      evil = File.join(dir, "evil.zip")
      zip_with_entry("../escape.txt", "escape", evil)
      dest = File.join(dir, "dest")

      begin
        @zip_helper.extract_archive(evil, dest)
      rescue GraderError
        # rejected outright is fine; the invariant is nothing lands outside
      end

      refute File.exist?(File.join(dir, "escape.txt")), "traversal entry must not escape"
      assert File.directory?(dest), "dest still holds an (empty) extraction dir"
    end
  end

  test "end-to-end: Demo.zip extracted, main selected, graded via Digital.jar matches 1.sol" do
    skip "java not available" unless system(JAVA, "-version", out: File::NULL, err: File::NULL)

    Dir.mktmpdir do |sim|
      mybin = File.join(sim, "mybin")
      assert_equal %w[Demo.dig MANIFEST.TXT MyAndOr.dig],
                   @zip_helper.extract_archive(DEMO_ZIP, mybin)

      # grader Compiler::Digital#post_compile picks the manifest main circuit
      # and copies it to submitted.dig; in the real worker the jar is mounted
      # at /my_lib and the testcase input at /input, here we use absolute
      # sim paths (equivalent command line).
      main = @zip_helper.archive_main_file(mybin, ext: "dig")
      FileUtils.cp(File.join(mybin, main), File.join(mybin, "submitted.dig"))

      FileUtils.mkdir_p(File.join(sim, "input"))
      FileUtils.cp(DEMO_TC.join("1.in"), File.join(sim, "input", "input.txt"))

      run_line = "#{JAVA} -cp #{DIGITAL_DIR.join('Digital.jar')} CLI test " \
                 "-circ #{mybin}/submitted.dig -tests #{File.join(sim, 'input', 'input.txt')}"
      File.write(File.join(mybin, "run.sh"), "#!/bin/sh\n#{run_line}\n")

      # the checker default for the testcase is `diff -q -b -B -Z`
      output, status = Open3.capture2("sh", File.join(mybin, "run.sh"), chdir: mybin)
      assert status.success?, "digital CLI test should pass, got #{output.inspect}"
      assert_equal File.read(DEMO_TC.join("1.sol")), output.strip,
                   "stdout should be the pass marker (modulo trailing whitespace)"

      out_file = File.join(mybin, "out.txt")
      File.write(out_file, output)
      diff_ok = system("diff", "-q", "-b", "-B", "-Z", out_file,
                       DEMO_TC.join("1.sol").to_s, out: File::NULL, err: File::NULL)
      assert diff_ok, "default diff checker must accept stdout vs 1.sol"
    end
  end
end
