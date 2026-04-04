require "./spec_helper"
require "../src/cdddns/hosts_manager"

describe Cdddns::HostsManager do
  manager = Cdddns::HostsManager.new("/tmp/test_hosts")

  it "generates a fragment correctly" do
    hosts = [
      Cdddns::HostInfo.new(["web.local", "api.local"], ["172.17.0.2"]),
      Cdddns::HostInfo.new(["db.local"], ["172.17.0.3", "192.168.0.5"])
    ]
    fragment = manager.generate_fragment(hosts)
    fragment.should contain("172.17.0.2\tweb.local api.local\n")
    fragment.should contain("172.17.0.3\tdb.local\n")
    fragment.should contain("192.168.0.5\tdb.local\n")
  end

  it "appends a new section if one doesn't exist" do
    input = IO::Memory.new("127.0.0.1 localhost\n")
    output = IO::Memory.new
    fragment = "1.2.3.4\thost.local\n"

    manager.process_update(input, output, fragment)
    
    result = output.to_s
    result.should contain("127.0.0.1 localhost\n")
    result.should contain("# CDDDNS start\n")
    result.should contain("1.2.3.4\thost.local\n")
    result.should contain("# CDDDNS end\n")
  end

  it "replaces an existing section" do
    input = IO::Memory.new("127.0.0.1 localhost\n# CDDDNS start\nold contents\n# CDDDNS end\n# some other comment\n")
    output = IO::Memory.new
    fragment = "1.2.3.4\thost.local\n"

    manager.process_update(input, output, fragment)
    
    result = output.to_s
    result.should contain("127.0.0.1 localhost\n")
    result.should contain("# CDDDNS start\n1.2.3.4\thost.local\n# CDDDNS end\n")
    result.should contain("# some other comment\n")
    result.should_not contain("old contents")
  end

  it "preserves original file contents" do
    input = IO::Memory.new("127.0.0.1 localhost\n\n::1 localhost\n")
    output = IO::Memory.new
    fragment = ""

    manager.process_update(input, output, fragment)
    
    output.to_s.should eq("127.0.0.1 localhost\n\n::1 localhost\n")
  end
end
