require "file_utils"
require "./models"

module Cdddns
  class HostsManager
    START_MARKER = "# CDDDNS start"
    END_MARKER   = "# CDDDNS end"

    def initialize(@hosts_file : String = "/etc/hosts")
    end

    def update(hosts : Array(HostInfo))
      fragment = generate_fragment(hosts)
      
      # Use a temporary file for atomic update if it's a real file
      tmp_file = "#{@hosts_file}.cdddns"
      
      File.open(@hosts_file, "r") do |input|
        File.open(tmp_file, "w") do |output|
          process_update(input, output, fragment)
        end
      end

      FileUtils.mv(tmp_file, @hosts_file)
    end

    # Internal logic for testing with IOs
    def process_update(input : IO, output : IO, fragment : String)
      in_section = false
      section_written = false

      input.each_line do |line|
        if line.strip == START_MARKER
          in_section = true
          output.puts START_MARKER
          output.print fragment
          output.puts END_MARKER
          section_written = true
          next
        elsif line.strip == END_MARKER
          in_section = false
          next
        end

        output.puts line unless in_section
      end

      # If there was no existing section, append it to the end
      if !section_written && !fragment.empty?
        output.puts START_MARKER
        output.print fragment
        output.puts END_MARKER
      end
    end

    def generate_fragment(hosts : Array(HostInfo)) : String
      String.build do |str|
        hosts.each do |host|
          host.ips.each do |ip|
            str << ip << "\t" << host.hostnames.join(" ") << "\n"
          end
        end
      end
    end
  end
end
