require "mini_portile2"

# Patch MiniPortile to support GitHub Container Registry downloads
class CustomPortile < MiniPortile
  # expose some helper methods
  public :archives_path
  public :port_path

  private

  # inject GitHub Authentication Header for `ghcr.io` URLs
  def download_file_http(url, full_path, count = 3)
    filename = File.basename(full_path)
    with_tempfile(filename, full_path) do |temp_file|
      total = 0
      params = {
        "Accept-Encoding" => 'identity',
        :content_length_proc => lambda{|length| total = length },
        :progress_proc => lambda{|bytes|
          if total
            new_progress = (bytes * 100) / total
            message "\rDownloading %s (%3d%%) " % [filename, new_progress]
          else
            # Content-Length is unavailable because Transfer-Encoding is chunked
            message "\rDownloading %s " % [filename]
          end
        },
        :open_timeout => @open_timeout,
        :read_timeout => @read_timeout,
      }
      if url.include?("ghcr.io")
        params["Authorization"] = "Bearer QQ=="
      end

      proxy_uri = URI.parse(url).scheme.downcase == 'https' ?
                  ENV["https_proxy"] :
                  ENV["http_proxy"]
      if proxy_uri
        _, userinfo, _p_host, _p_port = URI.split(proxy_uri)
        if userinfo
          proxy_user, proxy_pass = userinfo.split(/:/).map{|s| CGI.unescape(s) }
          params[:proxy_http_basic_authentication] =
            [proxy_uri, proxy_user, proxy_pass]
        end
      end

      begin
        OpenURI.open_uri(url, 'rb', params) do |io|
          temp_file << io.read
        end
        output
      rescue OpenURI::HTTPRedirect => redirect
        raise "Too many redirections for the original URL, halting." if count <= 0
        count = count - 1
        return download_file(redirect.url, full_path, count-1)
      rescue => e
        count = count - 1
        puts "#{count} retrie(s) left for #{filename} (#{e.message})"
        if count > 0
          sleep 1
          return download_file_http(url, full_path, count)
        end

        output e.message
        return false
      end
    end
  end
end
