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
end
