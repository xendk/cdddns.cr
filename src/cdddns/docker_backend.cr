require "http/client"
require "socket"
require "json"
require "uri"
require "log"
require "docr"
require "./models"

module Cdddns
  abstract class DockerBackend
    abstract def listen(&block : DockerEvent ->)
    abstract def inspect_container(id : String) : Container?
    abstract def list_containers : Array(Container)
  end

  class RealDockerBackend < DockerBackend
    def initialize(@socket_path : String = ENV.fetch("DOCKER_HOST", "/var/run/docker.sock").lchop("unix://"))
      @docker_api = Docr::API.new(Docr::Client.new)
      @log = Log.for("docker")
    end

    def listen(&block : DockerEvent ->)
      UNIXSocket.open(@socket_path) do |socket|
        http = HTTP::Client.new(socket)
        # TODO: Add filters for container start/die etc.
        filters = URI.encode_www_form("")

        @log.notice &.emit "Listening for Docker events", socket: @socket_path
        http.get("/events?#{filters}") do |response|
          unless response.status.success?
            raise "Error: #{response.status} – #{response.body_io.gets_to_end}"
          end

          response.body_io.each_line do |line|
            next if line.blank?
            event = DockerEvent.from_json(line)
            yield event
          end
        end
      end
    end

    def inspect_container(id : String) : Container?
      begin
        info = @docker_api.containers.inspect(id)
        convert_to_model(info)
      rescue ex
        @log.error(exception: ex) { "Failed to inspect container #{id}" }
        nil
      end
    end

    def list_containers : Array(Container)
      begin
        # Docr's list only returns a summary, so we might need to inspect each one
        # or use the information from the list if sufficient.
        # For simplicity and correctness (to get all IPs and envs), we'll inspect each.
        summaries = @docker_api.containers.list
        summaries.compact_map do |summary|
          inspect_container(summary.id)
        end
      rescue ex
        @log.error(exception: ex) { "Failed to list containers" }
        [] of Container
      end
    end

    private def convert_to_model(info : Docr::Types::ContainerInspectResponse) : Container
      ips = [] of String
      
      if ip = info.network_settings.ip_address
        ips << ip if !ip.empty?
      end

      info.network_settings.networks.each do |_, network|
        if ip = network.ip_address
          ips << ip if !ip.empty?
        end
      end

      Container.new(
        id: info.id,
        name: info.name,
        ips: ips,
        env: info.config.env || [] of String,
        labels: info.config.labels || {} of String => String
      )
    end
  end
end
