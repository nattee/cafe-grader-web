module OptionConst
  #YAML default options value
  DEFAULT = {
    dir: {
      testcases: 'testcases',
      attachments: 'attachments',
      checker: 'checker',
      managers: 'managers',
      model_sols: 'model_solutions',
    },
    file: {
      checker: 'checker',
      statement: 'statment.pdf',
    }
  }

  YAML_FILENAME = 'config.yml'

  # these are keys of the Option hash, MUST BE SYMBOL
  YAML_KEY = {
    dir: {
      testcases: :testcases_dir,
      attachments: :attachments_dir,
      checker: :checker_dir,
      managers: :managers_dir,
      model_sols: :solutions_dir,
    },
    ds_name: :ds_name,
    tags: :tags,
    checker: :checker,
    managers_pattern: :managers_pattern,
    testcases: :testcases,
    testcases_pattern: :testcases_pattern,
  }



end
