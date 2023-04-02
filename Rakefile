# frozen_string_literal: true

require "digest/sha1"
require "mini_portile2"
require "yaml"

# extend MiniPortile for local compilation
require_relative "src/custom_portile"

SUPPORTED_PLATFORMS = %w(
  aarch64-linux-musl
  x86_64-linux-musl
  aarch64-apple-darwin20.0
  x86_64-apple-darwin20.0
)

directory "ports"
directory "tmp"

# load libs.yml
libs = YAML.safe_load(File.read("libs.yml"))

# define tasks for download of each platform
libs.each do |lib|
  binaries = lib["binaries"]

  SUPPORTED_PLATFORMS.each do |platform|
    port = CustomPortile.new(lib["name"], lib["version"])
    port.host = platform

    if found = binaries.find { |b| b["platform"] == platform }
      short_platform = platform.split("-").first

      # save port path before changing target
      port_path = port.port_path
      port.target = "ports/#{platform}"

      desc "Fetch #{lib["name"]} #{lib["version"]}"
      task "fetch:#{platform}:#{lib["name"]}" => ["tmp"] do
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

        checkpoint = "tmp/.#{port.name}-#{port.version}-#{port.host}.download"

        unless File.exist?(checkpoint)
          port.download unless port.downloaded?
          mkdir_p port_path

          port.files.each do |file|
            file_path = File.expand_path(File.basename(file[:url]), port.archives_path)
            sh "tar -tf #{file_path} 2>#{IO::NULL} | grep -E '#{lib["files"].join("|")}' | xargs -I '{}' tar -xf #{file_path} -C #{port_path} --no-anchored '{}' 2>#{IO::NULL}"
          end

          FileUtils.touch(checkpoint)
        end
      end
    end

    desc "Fetch all for '#{platform}'"
    task "fetch:#{platform}" => ["fetch:#{platform}:#{port.name}"]

    desc "Package all for '#{platform}'"
    task "package:#{platform}" => ["fetch:#{platform}:#{port.name}"]
  end
end

SUPPORTED_PLATFORMS.each do |platform|
  target_dir = File.join("pkg", platform)
  lib_dir = File.join(target_dir, "lib")
  pkg_dir = File.join(lib_dir, "pkgconfig")

  directory pkg_dir

  task "package:#{platform}" => [pkg_dir] do
    pkg_digest = Digest::SHA1.new

    # collect all the `.a` files
    Dir.glob("ports/#{platform}/**/*.a").each do |a_lib|
      basename = File.basename(a_lib)
      target_file = File.join(lib_dir, basename)

      unless File.exist?(target_file)
        cp a_lib, target_file
      end

      pkg_digest.update File.binread(a_lib)
    end

    # collect all the `.pc` files
    Dir.glob("ports/#{platform}/**/*.pc").each do |pc_file|
      basename = File.basename(pc_file)
      target_file = File.join(pkg_dir, basename)

      unless File.exist?(target_file)
        cp pc_file, target_file
      end

      pkg_digest.update File.binread(pc_file)
    end

    checkpoint = "tmp/.#{platform}-#{pkg_digest.hexdigest}.package"
    unless File.exist?(checkpoint)
      # generate platform.tar.xz
      sh "tar -C pkg -cJf pkg/#{platform}.tar.xz #{platform}"
      touch checkpoint
    end
  end

  desc "Fetch everything"
  task "fetch:all" => ["fetch:#{platform}"]

  desc "Package everything"
  task "package:all" => ["package:#{platform}"]
end
