require 'open3'
require 'pathname'

# Extracting (untrusted) student archives on the judge worker. Used by
# language compilers that accept a multi-file zip — e.g. a Digital circuit
# project with custom component files next to the main circuit.
#
# Extraction is flattened (unzip -j): every entry lands directly in the
# destination dir, because Digital resolves sub-circuits by bare filename
# relative to the main circuit, not by archive path. The main-file choice is
# documented in the archive via MANIFEST.TXT ("Main-Circuit: demo.dig") and
# falls back to "the lone matching file" when no manifest is present.
module ZipArchive
  # Extract a (student-supplied) zip into dest_dir, flattening paths so every
  # entry lands directly in dest_dir. Returns the basenames extracted (dotfiles
  # excluded). Raises GraderError on an unreadable archive, a zip-slip entry,
  # or an empty zip.
  def extract_archive(source_zip_path, dest_dir)
    dest = Pathname.new(dest_dir)
    dest.mkpath
    out, err, status = Open3.capture3('unzip', '-j', '-o', source_zip_path.to_s, '-d', dest.to_s)
    unless status.exitstatus == 0
      message = err.strip.presence || "unzip exited #{status.exitstatus}"
      raise GraderError.new("Archive extraction failed: #{message}")
    end
    validate_archive_containment!(dest)
    entries = Dir.children(dest).reject { |name| name.start_with?('.') }
    raise GraderError.new('Archive contains no files') if entries.empty?
    entries.sort
  end

  # Zip-slip defense (mirrors ProblemImporter#validate_containment!): every
  # extracted entry must resolve inside the extraction dir.
  def validate_archive_containment!(dest)
    base = File.realpath(dest.to_s)
    Dir.glob("#{dest}/**/*", File::FNM_DOTMATCH).each do |entry|
      next if ['.', '..'].include?(File.basename(entry))
      resolved = (File.realpath(entry) rescue nil)
      next if resolved&.start_with?("#{base}/") || resolved == base
      raise GraderError.new("Archive entry '#{File.basename(entry)}' escapes the extraction directory")
    end
    true
  end

  # Pick the main file of an extracted (flattened) archive. An optional
  # MANIFEST.TXT names it with a "Main-Circuit: <file>.<ext>" line; otherwise
  # a single matching file wins. Returns the basename. Raises GraderError when
  # the manifest names a missing file or no candidate can be determined.
  def archive_main_file(dir, ext:)
    dir = Pathname.new(dir)
    manifest = dir + 'MANIFEST.TXT'
    if manifest.exist?
      main_name = nil
      File.foreach(manifest, chomp: true) do |raw|
        line = raw.strip
        next unless line.match?(/\AMain-Circuit\s*:/i)
        main_name = line.sub(/^[^:]+:/, '').strip
        break
      end
      if main_name.present?
        candidate = dir + File.basename(main_name)
        if candidate.exist?
          return File.basename(main_name)
        end
        raise GraderError.new("Archive manifest names missing main file '#{main_name}'")
      end
    end

    matching = Dir.glob((dir + "*.#{ext}").to_s).map { |f| File.basename(f) }
    if matching.size == 1
      matching.first
    else
      raise GraderError.new("Cannot determine archive main file: #{matching.size} .#{ext} files" \
                            " and no MANIFEST.TXT")
    end
  end
end
