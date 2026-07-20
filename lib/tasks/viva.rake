namespace :viva do
  desc 'Move per-problem llm_prompt tags into problems.viva_prompt; re-kind shared ones to viva_conduct. Report-only unless APPLY=1.'
  task migrate_prompt_tags: :environment do
    Viva::PromptTagMigrator.new(apply: ENV['APPLY'] == '1').run
  end
end
