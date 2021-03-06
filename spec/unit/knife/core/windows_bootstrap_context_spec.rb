#
# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright (c) 2014-2016 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'chef/knife/core/windows_bootstrap_context'
describe Chef::Knife::Core::WindowsBootstrapContext do
  let(:mock_bootstrap_context) { Chef::Knife::Core::WindowsBootstrapContext.new({ }, nil, { :knife => {} }) }

  before do
     allow(Chef::Knife::Core::WindowsBootstrapContext).to receive(:new).and_return(mock_bootstrap_context)
   end

  describe "fips" do
    before do
      Chef::Config[:fips] = fips_mode
    end

    after do
      Chef::Config.reset!
    end

    context "when fips is set" do
      let(:fips_mode) { true }

      it "sets fips mode in the client.rb" do
        expect(mock_bootstrap_context.config_content).to match(/fips true/)
      end
    end

    context "when fips is not set" do
      let(:fips_mode) { false }

      it "sets fips mode in the client.rb" do
        expect(mock_bootstrap_context.config_content).not_to match(/fips true/)
      end
    end
  end

  describe "trusted_certs_script" do
    let(:mock_cert_dir) { ::File.absolute_path(::File.join('spec','assets','fake_trusted_certs')) }
    let(:script_output) { mock_bootstrap_context.trusted_certs_script }
    let(:crt_files) { ::Dir.glob(::File.join(mock_cert_dir, "*.crt")) }
    let(:pem_files) { ::Dir.glob(::File.join(mock_cert_dir, "*.pem")) }
    let(:other_files) { ::Dir.glob(::File.join(mock_cert_dir, "*"))-crt_files-pem_files }

    before do
      mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:trusted_certs_dir => mock_cert_dir))
    end

    it "should echo every .crt file in the trusted_certs directory" do
      crt_files.each do |f|
        echo_file = ::File.read(f).gsub(/^/, "echo.")
        expect(script_output).to include(::File.join('trusted_certs',::File.basename(f)))
        expect(script_output).to include(echo_file)
      end
    end

    it "should echo every .pem file in the trusted_certs directory" do
      pem_files.each do |f|
        echo_file = ::File.read(f).gsub(/^/, "echo.")
        expect(script_output).to include(::File.join('trusted_certs',::File.basename(f)))
        expect(script_output).to include(echo_file)
      end
    end

    it "should not echo files which aren't .crt or .pem files" do
      other_files.each do |f|
        echo_file = ::File.read(f).gsub(/^/, "echo.")
        expect(script_output).to_not include(::File.join('trusted_certs',::File.basename(f)))
        expect(script_output).to_not include(echo_file)
      end
    end
  end

  describe "validation_key" do
    before do
      mock_bootstrap_context.instance_variable_set(:@config, Mash.new(:validation_key => "C:\\chef\\key.pem"))
    end

    it "should return false if validation_key does not exist" do
      allow(::File).to receive(:expand_path)
      allow(::File).to receive(:exist?).and_return(false)
      expect(mock_bootstrap_context.validation_key).to eq(false)
    end
  end

  describe "#get_log_location" do

    context "when config_log_location value is nil" do
      it "sets STDOUT in client.rb as default" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => nil))
        expect(mock_bootstrap_context.get_log_location).to eq("STDOUT\n")
      end
    end

    context "when config_log_location value is empty" do
      it "sets STDOUT in client.rb as default" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => ""))
        expect(mock_bootstrap_context.get_log_location).to eq("STDOUT\n")
      end
    end

    context "when config_log_location value is STDOUT" do
      it "sets STDOUT in client.rb" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => STDOUT))
        expect(mock_bootstrap_context.get_log_location).to eq("STDOUT\n")
      end
    end

    context "when config_log_location value is STDERR" do
      it "sets STDERR in client.rb" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => STDERR))
        expect(mock_bootstrap_context.get_log_location).to eq("STDERR\n")
      end
    end

    context "when config_log_location value is path to a file" do
      it "sets file path in client.rb" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => "C:\\chef\\chef.log"))
        expect(mock_bootstrap_context.get_log_location).to eq("\"C:\\chef\\chef.log\"\n")
      end
    end

    context "when config_log_location value is :win_evt" do
      it "sets :win_evt in client.rb" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => :win_evt))
        expect(mock_bootstrap_context.get_log_location).to eq(":win_evt\n")
      end
    end

    context "when config_log_location value is :syslog" do
      it "raise error with message and exit" do
        mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_location => :syslog))
        expect { mock_bootstrap_context.get_log_location }.to raise_error("syslog is not supported for log_location on Windows OS\n")
      end
    end

  end

  describe "#config_content" do
    before do
      mock_bootstrap_context.instance_variable_set(:@chef_config, Mash.new(:config_log_level => :info,
        :config_log_location => STDOUT,
        :chef_server_url => "http://chef.example.com:4444",
        :validation_client_name => "chef-validator-testing",
        :file_cache_path => "c:/chef/cache",
        :file_backup_path => "c:/chef/backup",
        :cache_options => ({:path => "c:/chef/cache/checksums", :skip_expires => true})
        ))
    end

    it "generates the config file data" do
      expected = <<-EXPECTED
echo.chef_server_url  "http://chef.example.com:4444"
echo.validation_client_name "chef-validator-testing"
echo.file_cache_path   "c:/chef/cache"
echo.file_backup_path  "c:/chef/backup"
echo.cache_options     ^({:path =^> "c:/chef/cache/checksums", :skip_expires =^> true}^)
echo.# Using default node name ^(fqdn^)
echo.log_level :info
echo.log_location       STDOUT
EXPECTED
    expect(mock_bootstrap_context.config_content).to eq expected
    end
  end

  describe "chef_version_in_url" do
    it "returns the major version of the current version of Chef" do
      stub_const("Chef::VERSION", '11.1.2')
      expect(mock_bootstrap_context.chef_version_in_url).to eq("&v=11")
    end

    it "does not add prerelease if the version of Chef installed is a prerelease" do
      stub_const("Chef::VERSION", '42.0.1.alpha.1')
      expect(mock_bootstrap_context.chef_version_in_url).not_to match(/&prerelease=true/)
    end

    it "does add prerelease if the version specified to be installed is a prerelease" do
      allow(mock_bootstrap_context).to receive(:knife_config).and_return(Mash.new(:bootstrap_version => "12.0.0.alpha.1"))
      expect(mock_bootstrap_context.chef_version_in_url).to eq("&v=12.0.0.alpha.1&prerelease=true")
    end

    context "when the prerelease config option is set" do
      before do
        mock_bootstrap_context.instance_variable_set(:@config, Mash.new(:prerelease => true))
      end

      it "sets prerelease to true in the returned string" do
        expect(mock_bootstrap_context.chef_version_in_url).to eq("&prerelease=true")
      end
    end
  end

  describe "msi_url" do
    context "when config option is not set" do
      before do
        expect(mock_bootstrap_context).to receive(:chef_version_in_url).and_return("&v=something")
      end

      it "returns a chef.io msi url with minimal url parameters" do
        reference_url = "https://www.chef.io/chef/download?p=windows&v=something"
        expect(mock_bootstrap_context.msi_url).to eq(reference_url)
      end

      it "returns a chef.io msi url with provided url parameters substituted" do
        reference_url = "https://www.chef.io/chef/download?p=windows&pv=machine&m=arch&DownloadContext=ctx&v=something"
        expect(mock_bootstrap_context.msi_url('machine', 'arch', 'ctx')).to eq(reference_url)
      end
    end

    context "when msi_url config option is set" do
      let(:custom_url) { "file://something" }

      before do
        mock_bootstrap_context.instance_variable_set(:@config, Mash.new(:msi_url => custom_url))
      end

      it "returns the overriden url" do
        expect(mock_bootstrap_context.msi_url).to eq(custom_url)
      end

      it "doesn't introduce any unnecessary query parameters if provided by the template" do
        expect(mock_bootstrap_context.msi_url('machine', 'arch', 'ctx')).to eq(custom_url)
      end
    end
  end

  describe "bootstrap_install_command for bootstrap through WinRM" do
    context "when bootstrap_install_command option is passed on CLI" do
      let(:bootstrap) { Chef::Knife::BootstrapWindowsWinrm.new(['--bootstrap-install-command', 'chef-client']) }
      before do
        bootstrap.config[:bootstrap_install_command] = "chef-client"
      end

      it "sets the bootstrap_install_command option under Chef::Config::Knife object" do
        expect(Chef::Config[:knife][:bootstrap_install_command]).to eq("chef-client")
      end

      after do
        bootstrap.config.delete(:bootstrap_install_command)
        Chef::Config[:knife].delete(:bootstrap_install_command)
      end
    end

    context "when bootstrap_install_command option is not passed on CLI" do
      let(:bootstrap) { Chef::Knife::BootstrapWindowsWinrm.new([]) }
      it "does not set the bootstrap_install_command option under Chef::Config::Knife object" do
        expect(Chef::Config[:knife][:bootstrap_install_command]). to eq(nil)
      end
    end
  end

  describe "bootstrap_install_command for bootstrap through SSH" do
    context "when bootstrap_install_command option is passed on CLI" do
      let(:bootstrap) { Chef::Knife::BootstrapWindowsSsh.new(['--bootstrap-install-command', 'chef-client']) }
      before do
        bootstrap.config[:bootstrap_install_command] = "chef-client"
      end

      it "sets the bootstrap_install_command option under Chef::Config::Knife object" do
        expect(Chef::Config[:knife][:bootstrap_install_command]).to eq("chef-client")
      end

      after do
        bootstrap.config.delete(:bootstrap_install_command)
        Chef::Config[:knife].delete(:bootstrap_install_command)
      end
    end

    context "when bootstrap_install_command option is not passed on CLI" do
      let(:bootstrap) { Chef::Knife::BootstrapWindowsSsh.new([]) }
      it "does not set the bootstrap_install_command option under Chef::Config::Knife object" do
        expect(Chef::Config[:knife][:bootstrap_install_command]). to eq(nil)
      end
    end
  end
end
