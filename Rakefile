# frozen_string_literal: true

require "digest/sha1"
require "mini_portile2"
require "rake/packagetask"
require "yaml"

# extend MiniPortile for local compilation
require_relative "src/custom_portile"

SUPPORTED_PLATFORMS = %w(
  aarch64-linux-musl
  x86_64-linux-musl
  aarch64-apple-darwin21.0
  x86_64-apple-darwin21.0
)

HAVERSACK_VERSION = "0.4.0"

directory "downloads"
directory "lib"
directory "tmp"

# load libs.yml
libs = YAML.safe_load(File.read("libs.yml"))

# define tasks for download of each platform
libs.each do |lib|
  binaries = lib["binaries"]

  SUPPORTED_PLATFORMS.each do |platform|
    port = CustomPortile.new(lib["name"], lib["version"])
    port.host = platform

    downloads_dir = "downloads/#{platform}"
    lib_dir = "lib/#{platform}"
    pkg_dir = File.join(lib_dir, "pkgconfig")

    directory downloads_dir
    directory pkg_dir

    if found = binaries.find { |b| b["platform"] == platform }
      short_platform = platform.split("-").first

      # save path before changing target
      tmp_port_path = File.join("tmp", port.port_path)
      port.target = downloads_dir

      task "fetch:#{platform}:#{lib["name"]}" => ["tmp", downloads_dir, pkg_dir] do
        # determine single or multiple files present
        if url = found["url"]
          port.files << {
            url: found["url"],
            sha256: found[:sha256],
          }
        end

        urls = found["urls"]
        if urls && !urls.empty?
          urls.each do |entry|
            port.files << {
              url: entry["url"],
              sha256: entry["sha256"],
            }
          end
        end

        checkpoint_download = "tmp/.#{port.host}-#{port.name}-#{port.version}.download"

        unless File.exist?(checkpoint_download)
          port.download unless port.downloaded?
          mkdir_p tmp_port_path

          port.files.each do |file|
            file_path = File.expand_path(File.basename(file[:url]), port.archives_path)
            sh "tar -tf #{file_path} 2>#{IO::NULL} | grep -E '#{lib["files"].join("|")}' | xargs -I '{}' tar -xf #{file_path} -C #{tmp_port_path} --no-anchored '{}' 2>#{IO::NULL}"
          end

          FileUtils.touch(checkpoint_download)
        end

        # collect SHA1 of all `.a` and `.pc` extracted files
        files_digest = Digest::SHA1.new
        port_files = Dir.glob("#{tmp_port_path}/**/*.{a,pc}")
        port_files.each do |file|
          files_digest.update File.binread(file)
        end

        checkpoint_extract = "tmp/.#{port.host}-#{port.name}-#{port.version}-#{files_digest.hexdigest}.extract"

        unless File.exist?(checkpoint_extract)
          port_files.each do |file|
            path = File.extname(file) == ".pc" ? pkg_dir : lib_dir
            target_file = File.join(path, File.basename(file))

            if File.exist?(target_file) && !FileUtils.compare_file(file, target_file)
              rm target_file, force: true
            end

            cp file, target_file
          end

          FileUtils.touch(checkpoint_extract)
        end
      end
    end

    desc "Fetch all for '#{platform}'"
    task "fetch:#{platform}" => ["fetch:#{platform}:#{port.name}"]

    desc "Fetch all"
    task "fetch:all" => ["fetch:#{platform}"]
  end
end

Rake::PackageTask.new("magic-haversack", HAVERSACK_VERSION) do |t|
  t.need_tar_xz = true

  globs = SUPPORTED_PLATFORMS.map { |platform| "lib/#{platform}/**/*.{a,pc}" }
  t.package_files.include(globs)
  t.package_files.include("bin/*-cc")
end

task "package" => ["fetch:all"]
