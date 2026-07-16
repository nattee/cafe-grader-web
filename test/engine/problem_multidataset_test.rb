# test/engine/problem_multidataset_test.rb
require "test_helper"
require "tmpdir"

class ProblemMultidatasetTest < ActiveSupport::TestCase
  EXAMPLES = Rails.root.join("test", "problem_examples")

  def import_rich(name)
    pi = ProblemImporter.new
    pi.import_dataset_from_dir(EXAMPLES.join("rich").to_s, name, user: users(:admin))
    pi.problem.reload
  end

  def parsed_config(dir)
    YAML.safe_load(File.read(File.join(dir, "config.yml")), symbolize_names: true)
  end

  # relative paths of every file under `dir`, sorted
  def file_tree(dir)
    Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }
       .map { |f| f.sub("#{dir}/", "") }.sort
  end

  test "live-only export produces a config with the expected keys and file tree" do
    p = import_rich("md_char")
    Dir.mktmpdir do |dump|
      ProblemExporter.new.export_problem_to_dir(p, base_dir: dump, zip: false)
      dir = File.join(dump, p.name.parameterize)
      cfg = parsed_config(dir)

      # problem + dataset fields present, no multi-dataset key
      assert_equal "md_char", cfg[:name]
      assert_equal "with_managers", cfg[:compilation_type]
      assert_equal "group_min", cfg[:score_type]
      assert cfg.key?(:testcases), "testcases hash present"
      refute cfg.key?(:additional_datasets), "no additional_datasets in a live-only export"

      tree = file_tree(dir)
      assert_includes tree, "config.yml"
      assert(tree.any? { |f| f.start_with?("testcases/") }, "has testcases/")
      assert(tree.none? { |f| f.start_with?("datasets/") }, "no datasets/ dir in live-only")
    end
  end

  test "all_datasets export writes each non-live dataset under datasets/ with a fragment" do
    p = import_rich("md_all")
    # add a second, non-live dataset with its own testcase
    ds2 = Dataset.create!(problem: p, name: "Alt DS", time_limit: 3, memory_limit: 128, score_type: :sum)
    tc = Testcase.new(code_name: "9", num: 1, group: 1, weight: 5)
    tc.inp_file.attach(io: StringIO.new("9 9\n"), filename: "input.txt", content_type: "text/plain")
    tc.ans_file.attach(io: StringIO.new("18\n"), filename: "answer.txt", content_type: "text/plain")
    ds2.testcases << tc
    ds2.save!

    Dir.mktmpdir do |dump|
      ProblemExporter.new.export_problem_to_dir(p, base_dir: dump, zip: false, all_datasets: true)
      dir = File.join(dump, p.name.parameterize)
      cfg = parsed_config(dir)

      assert_equal ["alt-ds"], cfg[:additional_datasets]
      sub = File.join(dir, "datasets", "alt-ds")
      assert File.directory?(sub), "datasets/alt-ds/ exists"
      frag = YAML.safe_load(File.read(File.join(sub, "config.yml")), symbolize_names: true)
      assert_equal "Alt DS", frag[:ds_name]
      assert_equal 3.0, frag[:time_limit]
      assert frag[:testcases].key?("9".to_sym) || frag[:testcases].key?("9"), "fragment has the testcase weight entry"
      assert File.exist?(File.join(sub, "testcases", "9.in")), "additional dataset testcase exported"
      refute frag.key?(:name), "fragment carries no problem-level fields"
    end
  end

  test "all_datasets de-duplicates colliding parameterized dataset dir names" do
    p = import_rich("md_collide")
    ["Same Name", "same name"].each_with_index do |nm, i|
      ds = Dataset.create!(problem: p, name: nm, time_limit: 1, memory_limit: 64, score_type: :sum)
      tc = Testcase.new(code_name: "1", num: 1, group: 1, weight: 1)
      tc.inp_file.attach(io: StringIO.new("#{i}\n"), filename: "i", content_type: "text/plain")
      tc.ans_file.attach(io: StringIO.new("#{i}\n"), filename: "a", content_type: "text/plain")
      ds.testcases << tc; ds.save!
    end
    Dir.mktmpdir do |dump|
      ProblemExporter.new.export_problem_to_dir(p, base_dir: dump, zip: false, all_datasets: true)
      dir = File.join(dump, p.name.parameterize)
      subs = Dir.children(File.join(dir, "datasets")).sort
      assert_equal ["same-name", "same-name-2"], subs, "colliding names get distinct suffixed dirs"
      assert_equal ["same-name", "same-name-2"], parsed_config(dir)[:additional_datasets].sort
    end
  end
end
