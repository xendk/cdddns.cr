require "docr"
require "file_utils"
require "option_parser"
require "./cdddns/models"
require "./cdddns/metadata_extractor"
require "./cdddns/hosts_manager"
require "./cdddns/docker_backend"
require "./cdddns/daemon"

# A simple Docker "DNS service".
module Cdddns
  VERSION = "0.1.0"

  def self.main
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

    backend = RealDockerBackend.new
    extractor = MetadataExtractor.new
    manager = HostsManager.new(hostsfile)

    daemon = Daemon.new(backend, extractor, manager)
    daemon.run
  end
end

unless ENV["CRYSTAL_SPEC_CONTEXT"]? == "true"
  Cdddns.main
end
