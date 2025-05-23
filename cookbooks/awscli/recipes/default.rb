#
# Cookbook:: awscli
# Recipe:: default
#
# Copyright:: 2023, OpenStreetMap Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

cache_dir = Chef::Config[:file_cache_path]

# Determine architecture of system for the AWS CLI download
awscli_arch = if arm?
                "aarch64"
              else
                "x86_64"
              end

awscli_version_suffix = if node[:awscli][:version] == "latest"
                          "" # latest version does not have a suffix
                        else
                          "-#{node[:awscli][:version]}"
                        end

awscli_zip = "awscliv2#{awscli_version_suffix}.zip"

# Ensure unpack directory is removed
directory "#{cache_dir}/awscli" do
  action :delete
  recursive true
end

# Remove any existing AWS CLI zip files, unless it's the one we're downloading
Dir.glob("#{cache_dir}/awscliv2*.zip").each do |zip|
  next if zip == "#{cache_dir}/#{awscli_zip}"

  file zip do
    action :delete
    backup false
  end
end

# Download the AWS CLI zip file
remote_file "#{cache_dir}/#{awscli_zip}" do
  source "https://awscli.amazonaws.com/awscli-exe-linux-#{awscli_arch}#{awscli_version_suffix}.zip"
  owner "root"
  group "root"
  mode "644"
  backup false
  ignore_failure true
end

# Extract the AWS CLI zip file
archive_file "#{cache_dir}/#{awscli_zip}" do
  path "#{cache_dir}/#{awscli_zip}"
  destination "#{cache_dir}/awscli"
  strip_components 1
  action :nothing
  subscribes :extract, "remote_file[#{cache_dir}/#{awscli_zip}]", :immediately
end

# Find the version of the AWS CLI we just downloaded
# Example version string: aws-cli/2.12.6 Python/3.11.4 Linux/5.15.49-linuxkit-pr exe/aarch64.ubuntu.22 prompt/off
# Install CLI to path: /opt/awscli/v2/current/bin/aws
ruby_block "install-awscli" do
  block do
    require "fileutils"
    awscli_version_string = shell_out("#{cache_dir}/awscli/dist/aws", "--version")
    awscli_version = awscli_version_string.stdout.split(" ").first.split("/").last

    install_dir = "/opt/awscli/v2/#{awscli_version}"

    FileUtils.mkdir_p("#{install_dir}/bin/", :mode => 0755)
    FileUtils.mv("#{cache_dir}/awscli/dist", "#{install_dir}/dist", :force => true)
    FileUtils.ln_sf("#{install_dir}/dist/aws", "#{install_dir}/bin/aws")
    FileUtils.ln_sf("#{install_dir}/dist/aws_completer", "#{install_dir}/bin/aws_completer")

    FileUtils.rm_f("/opt/awscli/v2/current")
    FileUtils.ln_sf(install_dir, "/opt/awscli/v2/current")

    # Retain the last 5 versions, including the current one
    versions = Dir.glob("/opt/awscli/v2/*").select { |dir| File.directory?(dir) && dir != "/opt/awscli/v2/current" }
    versions.sort_by! { |dir| File.mtime(dir) }.reverse!
    versions_to_delete = versions[5..] || []

    versions_to_delete.each do |dir|
      FileUtils.rm_rf(dir)
    end
  end
  action :nothing
  subscribes :run, "archive_file[#{cache_dir}/#{awscli_zip}]", :immediately
end
