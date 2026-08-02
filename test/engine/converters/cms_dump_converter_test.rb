require 'test_helper'

class CmsDumpConverterTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join('test/cms_bundles/eatingfish_mini')

  setup    { @tmp = Pathname.new(Dir.mktmpdir('cms_conv_test_')) }
  teardown { FileUtils.rm_rf(@tmp) }

  # Copy the fixture, optionally mutate its task.json, return the bundle dir.
  def bundle(mutate: nil)
    dir = @tmp + 'bundle'
    FileUtils.cp_r(FIXTURE, dir)
    if mutate
      path = dir + 'task.json'
      data = JSON.parse(File.read(path))
      mutate.call(data)
      File.write(path, JSON.generate(data))
    end
    dir
  end

  def convert(mutate: nil)
    @conv = Converters::CmsDumpConverter.new
    @staging = @tmp + 'staging'
    @result = @conv.convert(bundle(mutate: mutate), @staging)
  end

  def staging_cfg
    YAML.safe_load(File.read(@staging + 'config.yml'), symbolize_names: true)
  end

  test 'rejects wrong bundle_version' do
    convert(mutate: ->(d) { d['bundle_version'] = 2 })
    assert_match(/bundle_version/, @result[:errors].join)
  end

  test 'rejects wrong dump_version' do
    convert(mutate: ->(d) { d['dump_version'] = 40 })
    assert_match(/dump _version/, @result[:errors].join)
  end

  test 'clean fixture converts without errors and exposes problem_meta' do
    convert
    assert_equal [], @result[:errors]
    assert_equal({ name: 'eatingfish_mini', full_name: 'กินปลา mini',
                   live_dataset_name: 'main' }, @conv.problem_meta)
  end

  test 'root config carries problem and active dataset fields' do
    convert
    cfg = staging_cfg
    assert_equal 'eatingfish_mini', cfg[:name]
    assert_equal 'batch', cfg[:task_type]
    assert_equal 'with_managers', cfg[:compilation_type]
    assert_equal 'eatingfish.cpp', cfg[:submission_filename]
    assert_equal 'cpp', cfg[:permitted_lang]
    assert_equal 1.0, cfg[:time_limit]
    assert_equal 512, cfg[:memory_limit]
    assert_equal 'group_min', cfg[:score_type]
    assert_equal 'default', cfg[:evaluation_type]
    assert_equal 'grader.cpp', cfg[:main_filename]
    assert_equal ['grader.cpp'], cfg[:main]
  end

  test 'GroupMin integer params slice lexicographically sorted codenames' do
    convert
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'2-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'2-02'])
  end

  test 'testcase blobs land as codename.in/.sol' do
    convert
    assert_equal "1 2\n", File.read(@staging + 'testcases' + '1-01.in')
    assert_equal "3\n",   File.read(@staging + 'testcases' + '1-01.sol')
  end

  test 'managers copied; statement picks primary th; attachment direct' do
    convert
    assert File.exist?(@staging + 'managers' + 'grader.cpp')
    assert File.exist?(@staging + 'managers' + 'eatingfish.h')
    assert_equal File.read(FIXTURE + 'files' + 'dig-st-th'),
                 File.read(@staging + 'statement.pdf')
    assert File.exist?(@staging + 'attachment' + 'starter.zip')
    assert_match(/language 'th'/, @result[:log].join("\n"))
    assert_match(/statement language 'en' skipped/, @result[:warnings].join("\n"))
  end

  test 'non-active dataset becomes datasets/<name> fragment without problem keys' do
    convert
    assert_equal ['rev2'], staging_cfg[:additional_datasets]
    frag = YAML.safe_load(File.read(@staging + 'datasets' + 'rev2' + 'config.yml'),
                          symbolize_names: true)
    assert_equal 'rev2', frag[:ds_name]
    assert_equal 2.0, frag[:time_limit]
    assert_equal 256, frag[:memory_limit]
    assert_equal 'sum', frag[:score_type]
    assert_equal({ group: 1, group_name: '1', weight: 1 }, frag[:testcases][:'1-01'])
    assert File.exist?(@staging + 'datasets' + 'rev2' + 'testcases' + '1-01.in')
    refute frag.key?(:name)
    refute frag.key?(:compilation_type)
    refute frag.key?(:submission_filename)
  end

  test 'active dataset violation rejects the whole task' do
    convert(mutate: ->(d) { d['objects']['1414']['task_type'] = 'Communication' })
    assert_match(/active dataset .*task_type 'Communication'/, @result[:errors].join)
  end

  test 'file-IO active dataset rejects' do
    convert(mutate: ->(d) {
      d['objects']['1414']['task_type_parameters'] = ['grader', ['in.txt', 'out.txt'], 'diff']
    })
    assert_match(%r{file-I/O}, @result[:errors].join)
  end

  test 'GroupMinPrereq active dataset rejects' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type'] = 'GroupMinPrereq' })
    assert_match(/score_type 'GroupMinPrereq'/, @result[:errors].join)
  end

  test 'non-active dataset violation only skips that dataset' do
    convert(mutate: ->(d) { d['objects']['1418']['task_type'] = 'OutputOnly' })
    assert_equal [], @result[:errors]
    assert_match(/skipped non-active dataset 'rev2'/, @result[:warnings].join)
    refute File.exist?((@staging + 'datasets').to_s)
    refute staging_cfg.key?(:additional_datasets)
  end

  test 'GroupMin count mismatch rejects' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[30, 1], [70, 5]] })
    assert_match(/counts sum to 6 but dataset has 3/, @result[:errors].join)
  end

  test 'GroupMin regex params assign by anchored match' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[40, '1-.*'], [60, '2-.*']] })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 40 }, tcs[:'1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 60 }, tcs[:'2-01'])
    assert_equal({ group: 2, group_name: '2', weight: 60 }, tcs[:'2-02'])
  end

  test 'GroupMin regex leaving testcases uncovered rejects' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[40, '1-.*']] })
    assert_match(/match no GroupMin pattern: 2-01, 2-02/, @result[:errors].join)
  end

  test 'comparator eval maps to custom_cms and pulls the checker manager' do
    convert(mutate: lambda { |d|
      d['objects']['1414']['task_type_parameters'] = ['grader', ['', ''], 'comparator']
      d['objects']['1414']['managers'] = d['objects']['1414']['managers'].merge('checker' => '10097')
      d['objects']['10097'] = { '_class' => 'Manager', 'dataset' => '1414',
                                'filename' => 'checker', 'digest' => 'dig-header' }
    })
    assert_equal [], @result[:errors]
    assert_equal 'custom_cms', staging_cfg[:evaluation_type]
    assert File.exist?(@staging + 'checker' + 'checker')
    refute File.exist?(@staging + 'managers' + 'checker')
    assert_match(/prebuilt/, @result[:warnings].join)
  end

  test 'pdf attachment is wrapped in a zip to avoid root glob collision' do
    convert(mutate: lambda { |d|
      d['objects']['408']['attachments'] = { 'notes.pdf' => '1417' }
      d['objects']['1417']['filename'] = 'notes.pdf'
    })
    assert_equal [], @result[:errors]
    refute File.exist?(@staging + 'attachment' + 'notes.pdf')
    assert File.exist?(@staging + 'attachment' + 'eatingfish_mini-files.zip')
  end

  test 'missing blob rejects' do
    convert(mutate: ->(d) { d['objects']['20001']['input'] = 'dig-nonexistent' })
    assert_match(/blob missing: dig-nonexistent/, @result[:errors].join)
  end
end
