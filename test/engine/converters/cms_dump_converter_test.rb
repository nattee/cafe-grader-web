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
    assert_equal 'managers', cfg[:managers_dir]
    assert_equal '*', cfg[:managers_pattern]
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
    assert_equal 'managers', frag[:managers_dir]
    assert_equal '*', frag[:managers_pattern]
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

  # Was: 'GroupMin count mismatch rejects' -- the converter used to hard
  # reject any mismatch between the declared param counts and the actual
  # testcase count. Real Chula tasks (may2022_bombs, may2023_robots,
  # oct2023_rescue) hit exactly this with off-by-one counts, so the rule
  # changed to CMS's own defensive-slicing semantics (see
  # build_group_min_int_plan). These params (declared sum 6, only 3
  # testcases exist) over-declare, but since the shortfall is absorbed by
  # the LAST group getting fewer testcases than declared rather than an
  # empty group, this succeeds silently (no warning) -- the "loud warning"
  # case is a group ending up with literally zero testcases, covered below.
  test 'GroupMin params over-declaring without an empty group succeeds, group gets fewer than declared' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[30, 1], [70, 5]] })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'2-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'2-02'])
  end

  test 'GroupMin params under-covering testcases: leftover lands in a weight-0 trailing group with a warning' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[30, 1], [70, 1]] })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'2-01'])
    # leftover testcase ('2-02', the ORIGINAL lexicographic last) -> new
    # trailing group 3, weight 0 (cafe's group_min normalizes by total
    # weight, so a weight-0 group scores exactly like CMS ignoring it).
    assert_equal({ group: 3, group_name: '3', weight: 0 }, tcs[:'2-02'])
    assert_match(/GroupMin params cover 2 of 3 testcases; the remaining 1 assigned to a weight-0 group/,
                 @result[:log].join("\n"))
  end

  test 'GroupMin params over-declaring so a trailing group is fully empty: group dropped with a loud warning' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[30, 3], [70, 2]] })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'1-01'])
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'2-01'])
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'2-02'])
    # group 2 wanted 2 testcases but none were left -- dropped entirely, not
    # emitted as a bogus zero-testcase group.
    refute(staging_cfg[:testcases].values.any? { |v| v[:group] == 2 })
    assert_match(/GroupMin params declare 5 testcases but only 3 exist; group 2 is empty and was dropped/,
                 @result[:log].join("\n"))
  end

  test 'GroupMin integer params producing zero usable groups still rejects' do
    convert(mutate: ->(d) {
      d['objects']['1414']['testcases'] = {}
      d['objects']['1414']['score_type_parameters'] = [[100, 3]]
    })
    assert_match(/no usable testcase groups/, @result[:errors].join)
  end

  # The under-declared/weight-0-tail path must still group/order on the
  # ORIGINAL (possibly slashed) codename and only translate to the
  # filesystem-safe name at emission -- same property the sanitization pass
  # guarantees elsewhere (see "directory-style codenames land as sanitized
  # staging files" above). Here the LEFTOVER testcase itself is slashed.
  test 'GroupMin under-count leftover with a slashed codename sanitizes correctly in the weight-0 group' do
    convert(mutate: ->(d) {
      tcs = d['objects']['1414']['testcases']
      d['objects']['1414']['testcases'] = {
        '1-01' => tcs['1-01'],
        '2-01' => tcs['2-01'],
        'result/2-02' => tcs['2-02']
      }
      d['objects']['1414']['score_type_parameters'] = [[30, 1], [70, 1]]
    })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'2-01'])
    # 'result/2-02' still sorts after '2-01' by its ORIGINAL codename, lands
    # in the weight-0 trailing group, and is written under its sanitized name.
    assert_equal({ group: 3, group_name: '3', weight: 0 }, tcs[:'result_2-02'])
    assert File.exist?(@staging + 'testcases' + 'result_2-02.in')
    assert_match(/GroupMin params cover 2 of 3 testcases; the remaining 1 assigned to a weight-0 group/,
                 @result[:log].join("\n"))
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

  # --- review round 1 additions -------------------------------------------

  test 'missing testcase object rejects cleanly, no exception' do
    convert(mutate: ->(d) { d['objects'].delete('20001') })
    assert_match(/missing id .*20001/, @result[:errors].join)
  end

  test 'missing non-active dataset object rejects the whole task, no exception' do
    convert(mutate: ->(d) { d['objects'].delete('1418') })
    assert_match(/missing id .*1418/, @result[:errors].join)
  end

  test 'null testcase input digest rejects cleanly, no EISDIR' do
    convert(mutate: ->(d) { d['objects']['20001']['input'] = nil })
    assert_match(/blob.*digest|digest.*blob/i, @result[:errors].join)
  end

  test 'GroupMin invalid regex pattern rejects with a clear message' do
    convert(mutate: ->(d) { d['objects']['1414']['score_type_parameters'] = [[40, '(unclosed']] })
    assert_match(/invalid regex/, @result[:errors].join)
  end

  test 'colliding dataset display name gets a deduped ds_name, no silent merge' do
    convert(mutate: ->(d) { d['objects']['1418']['description'] = 'main' })
    assert_equal [], @result[:errors]
    assert_equal 'main', staging_cfg[:ds_name]
    assert_equal ['main'], staging_cfg[:additional_datasets]
    frag = YAML.safe_load(File.read(@staging + 'datasets' + 'main' + 'config.yml'),
                          symbolize_names: true)
    assert_equal 'main-2', frag[:ds_name]
    assert_match(/renamed/, @result[:warnings].join)
  end

  # --- final review additions ---------------------------------------------

  test 'unsafe manager filename rejects, no file written outside staging' do
    convert(mutate: ->(d) {
      managers = d['objects']['1414']['managers']
      managers['../evil.h'] = managers.delete('eatingfish.h')
    })
    assert_match(/unsafe manager filename/, @result[:errors].join)
    refute Dir.glob(@tmp + '**' + '*evil*').any?
  end

  test 'unsafe attachment filename rejects, no file written outside staging' do
    convert(mutate: ->(d) {
      atts = d['objects']['408']['attachments']
      d['objects']['408']['attachments'] = { '../evil.zip' => atts.delete('starter.zip') }
    })
    assert_match(/unsafe attachment filename/, @result[:errors].join)
    refute Dir.glob(@tmp + '**' + '*evil*').any?
  end

  test 'bare checker attachment is wrapped in a zip to avoid the recursive checker glob' do
    convert(mutate: lambda { |d|
      d['objects']['408']['attachments'] = { 'checker' => '1417' }
      d['objects']['1417']['filename'] = 'checker'
    })
    assert_equal [], @result[:errors]
    refute File.exist?(@staging + 'attachment' + 'checker')
    assert File.exist?(@staging + 'attachment' + 'eatingfish_mini-files.zip')
  end

  test 'sibling dataset with different compilation than active gets a promotion warning' do
    convert
    assert_match(
      /dataset 'rev2': compilation 'alone' differs from the active dataset's 'grader'/,
      @result[:warnings].join("\n")
    )
  end

  # --- directory-style codename sanitization ------------------------------

  test 'safe_codename sanitizes directory-style codenames for filesystem use' do
    assert_equal 'result_01-01', Converters::CmsDumpConverter.safe_codename('result/01-01')
    assert_equal 'test_1a', Converters::CmsDumpConverter.safe_codename('test/1a')
  end

  test 'safe_codename never returns a path with a slash or a dot/dotdot segment' do
    safe = Converters::CmsDumpConverter.safe_codename('../tests/01-01')
    refute_match %r{[/\\]}, safe
    refute_equal '.', safe
    refute_equal '..', safe
  end

  test 'safe_codename handles degenerate input without a blank, . or .. result' do
    ['..', '.', '/', ''].each do |degenerate|
      safe = Converters::CmsDumpConverter.safe_codename(degenerate)
      assert safe.present?, "expected a non-empty safe name for #{degenerate.inspect}"
      refute_equal '.', safe
      refute_equal '..', safe
    end
  end

  test 'directory-style codenames land as sanitized staging files, grouped by ORIGINAL lexicographic order' do
    convert(mutate: ->(d) {
      tcs = d['objects']['1414']['testcases']
      d['objects']['1414']['testcases'] = {
        'result-rev3/1-01' => tcs['1-01'],
        'result/2-01' => tcs['2-01'],
        'result/2-02' => tcs['2-02']
      }
    })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    # Original lexicographic order: "result-rev3/1-01" < "result/2-01" < "result/2-02"
    # ('-' < '/' in ASCII), so the GroupMin [30,1],[70,2] split still puts
    # "result-rev3/1-01" alone in group 1 — this only holds if grouping ran
    # on the ORIGINAL codenames, not the sanitized ones.
    assert_equal({ group: 1, group_name: '1', weight: 30 }, tcs[:'result-rev3_1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'result_2-01'])
    assert_equal({ group: 2, group_name: '2', weight: 70 }, tcs[:'result_2-02'])
    assert File.exist?(@staging + 'testcases' + 'result-rev3_1-01.in')
    assert File.exist?(@staging + 'testcases' + 'result_2-01.sol')
    assert File.exist?(@staging + 'testcases' + 'result_2-02.in')
    assert_match(/sanitized for filesystem safety/, @result[:log].join("\n"))
  end

  test 'GroupMin regex params match against the ORIGINAL slashed codename' do
    convert(mutate: ->(d) {
      tcs = d['objects']['1414']['testcases']
      d['objects']['1414']['testcases'] = {
        'result/1-01' => tcs['1-01'],
        'result/2-01' => tcs['2-01'],
        'result/2-02' => tcs['2-02']
      }
      d['objects']['1414']['score_type_parameters'] = [[40, 'result/1-.*'], [60, 'result/2-.*']]
    })
    assert_equal [], @result[:errors]
    tcs = staging_cfg[:testcases]
    assert_equal({ group: 1, group_name: '1', weight: 40 }, tcs[:'result_1-01'])
    assert_equal({ group: 2, group_name: '2', weight: 60 }, tcs[:'result_2-01'])
    assert_equal({ group: 2, group_name: '2', weight: 60 }, tcs[:'result_2-02'])
  end

  test 'codenames colliding after sanitization reject the task with both names named' do
    convert(mutate: ->(d) {
      tcs = d['objects']['1414']['testcases']
      d['objects']['1414']['score_type'] = 'Sum'
      d['objects']['1414']['score_type_parameters'] = 100
      d['objects']['1414']['testcases'] = {
        'a/b' => tcs['1-01'],
        'a_b' => tcs['2-01']
      }
    })
    assert_match(/a\/b/, @result[:errors].join)
    assert_match(/a_b/, @result[:errors].join)
    assert_match(/collision|sanitize to the same/, @result[:errors].join)
  end
end
