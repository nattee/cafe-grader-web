namespace :viva do
  desc 'Move per-problem llm_prompt tags into problems.viva_prompt; re-kind shared ones to viva_conduct. Report-only unless APPLY=1.'
  task migrate_prompt_tags: :environment do
    Current.actor_note = 'Rake: viva:migrate_prompt_tags'
    Viva::PromptTagMigrator.new(apply: ENV['APPLY'] == '1').run
  end
end

namespace :viva do
  desc 'Import a viva-scenario kit directory (manifest.yml + scenario/briefing .md files) into viva_exam problems. Report-only unless APPLY=1. Usage: bin/rails viva:import DIR=/path/to/kit [APPLY=1]'
  task import: :environment do
    dir = ENV['DIR'].presence or abort 'usage: bin/rails viva:import DIR=/path/to/kit [APPLY=1]'
    Current.actor_note = "Rake: viva:import #{File.basename(dir)}"
    ok = Viva::KitImporter.new(dir, apply: ENV['APPLY'] == '1').run
    exit(1) unless ok
  end
end
