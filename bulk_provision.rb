#!/usr/bin/env ruby

# bulkprovision - provision many hosts in foreman from a csv file
# Copyright (C) 2013  Steve Stodola http://github.com/plytro
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see {http://www.gnu.org/licenses/}.

require 'csv'
require 'trollop'
require 'rest-client'
require 'json'
require 'io/console'

opts = Trollop::options do
  version "bulkprovision 1.0 (c) 2013 Steve Stodola"
  banner <<-EOS
This program will bulk provision new hosts in foreman using the data in the 
source csv

Usage:
       bulkprovision.rb [options] csvfile
where [options] are:
EOS

  opt :host, "the foreman server", :type => :string
  opt :username, "foreman username", :type => :string
  opt :password, "foreman password", :type => :string
end
Trollop::die :host, "must have a value" if opts[:host].to_s.empty?

inputfile = ARGV[0]
if inputfile == nil
  abort("Give me some input.")
end


hostname = opts[:host]
username = opts[:username]
password = opts[:password]

if username == nil
  print "Enter your username: "
  username = STDIN.gets
end

if password == nil
  print "Enter your password: "
  password = STDIN.noecho(&:gets)
  puts 
end

hostname = hostname.chomp
username = username.chomp
password = password.chomp

client = RestClient::Resource.new(hostname,
                                 :user     => username,
                                 :password => password,
                                 :headers  => { :accept => :json })

domains = JSON.parse(client["domains"].get)
environemnts = JSON.parse(client["environments"].get)
hostgroups = JSON.parse(client["hostgroups"].get)
models = JSON.parse(client["models"].get)
partitiontables = JSON.parse(client["ptables"].get)
subnets = JSON.parse(client["subnets"].get)

CSV.foreach(inputfile, {:headers => true, :header_converters => :symbol}) do |row|
  
  domainId = domains.detect{|p| row[:domain] == p['domain']['name']}['domain']['id']
  hostgroupId = hostgroups.detect{|p| row[:hostgroup] == p['hostgroup']['name']}['hostgroup']['id']
  modelId =  models.detect{|p| row[:model] == p['model']['name']}['model']['id']
  ptableId = partitiontables.detect{|p| row[:partition_table] == p['ptable']['name']}['ptable']['id']
   
  searchsubnet = row[:ip].gsub(/[0-9]*$/,'').concat("0")
  subnetId = subnets.detect{|p| searchsubnet == p['subnet']['network']}['subnet']['id']

  hostdata = { 
    :host => {
      :build => 'true',
      :domain_id => domainId,
      :hostgroup_id  => hostgroupId,
      :ip => row[:ip],
      :mac => row[:mac],
      :model_id => modelId,
      :name => row[:host],
      :ptable_id => ptableId,
      :subnet_id => subnetId,
    }
  }

  client["hosts"].post(hostdata)
end
