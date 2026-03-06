require "docr"
require "file_utils"
require "option_parser"
require "./cdddns/docker"

# A simple Docker "DNS service".
module Cdddns
  VERSION = "0.1.0"

  hostsfile = "/etc/hosts"

  OptionParser.parse do |parser|
    parser.banner = "Usage: #{PROGRAM_NAME} [arguments]"
    parser.on("-f FILE", "--file=FILE", "Hosts file to edit (defaults to /etc/hosts)") { |file| hostsfile = file }
    parser.on("-h", "--help", "Show this help") do
      puts parser
      exit
    end
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end
  end

  @@docker = Docr::API.new(Docr::Client.new)

  alias HostInfo = NamedTuple(hostnames: Array(String), ips: Array(String))
  addresses = {} of String => HostInfo

  Docker.listen do |event|
    next unless event.type == "container"

    next if event.actor.attributes["com.docker.compose.oneoff"]? == "True"

    case event.action
    when "start"
      addresses[event.actor.id] = get_hostinfo(event.actor.id)
    when "die", "kill", "pause"
      addresses.delete(event.actor.id)
    else
      # Ignore
      next
    end


    update_hosts_file(hostsfile, generate_hosts_file(addresses.values))
    # pp event
  end

  def self.get_hostinfo(id : String) : HostInfo
    host_info = {hostnames: [] of String, ips: [] of String}

    container_info = @@docker.containers.inspect(id)

    if ip = container_info.network_settings.ip_address
      host_info[:ips] << ip
    end

    container_info.network_settings.networks.each do |name, network|
      if ip = network.ip_address
        host_info[:ips] << ip
      end
    end

    # <containername>.local
    host_info[:hostnames] << container_info.name[1..] + ".local"

    # Get name from VIRTUAL_HOST env variable.
    container_info.config.env.try &.each do |env_def|
      if env_def =~ /^VIRTUAL_HOST=(.*)/
        host_info[:hostnames] << $~[1]
      end
    end

    container_info.config.labels.try do |labels|
      # Use orbstacks label.
      if name = labels["dev.orbstack.domains"]?
        host_info[:hostnames] << name
      end

      compose_project = labels["com.docker.compose.project"]?
      compose_service = labels["com.docker.compose.service"]?

      # Docker Compose <service>.<compose_project>.local
      if compose_project && compose_service
        host_info[:hostnames] << "#{compose_service}.#{compose_project}.local"
      end
    end

    host_info
  end

  def self.generate_hosts_file(hosts : Array(HostInfo))
    String.build do |str|
      hosts.each do |host_info|
        host_info[:ips].each do |ip|
          str << ip << "\t" << host_info[:hostnames].join(" ") << "\n"
        end
      end
    end
  end

  def self.update_hosts_file(file : String, fragment : String)
    tmp_file = "#{file}.cdddns"
    File.open(file, "r") do |orig_io|
      in_cdddns_section = false
      File.open(tmp_file, "w") do |io|
        orig_io.each_line do |line|
          if line =~ /^# CDDDNS start/
            in_cdddns_section = true
          end
          io << line << "\n" unless in_cdddns_section
          if line =~ /^# CDDDNS end/
            in_cdddns_section = false
          end
        end

        if fragment.presence
          io << "# CDDDNS start\n" << fragment << "# CDDDNS end"
        end
      end
    end

    FileUtils.mv(tmp_file, file)
  end
end
