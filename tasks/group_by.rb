#!/usr/bin/env ruby

task_helper = [
  # During a real bolt call, ruby_task_helper modules is installed in same directory as this module
  File.join(__dir__, '..', '..', 'ruby_task_helper', 'files', 'task_helper.rb'),
  # During development the ruby_task_helper module will be in the test module fixtures
  File.join(__dir__, '..', 'spec', 'fixtures', 'modules', 'ruby_task_helper', 'files', 'task_helper.rb'),
].find { |helper_path| File.exist?(helper_path) }
raise 'Could not find the Bolt ruby_task_helper' if task_helper.nil?
require_relative task_helper
require 'bolt/util'

# Retrieves hosts from the WSUS SQL server
class GroupBy < TaskHelper
  NAME_REGEX = %r{[^a-z0-9_]}

  def resolve_reference(opts)
    key = opts[:key]
    targets = opts[:targets]
    group_name_prefix = opts[:group_name_prefix] || ''
    group_configs = opts[:group_configs] || {}
    key_list = key.split('.').map { |x| x.to_sym }

    group_hash = {}
    targets.each do |t|
      group_name = t.dig(*key_list) || 'null'
      group_name = normalize_group_name(group_name)
      unless group_hash.key?(group_name)
        group_hash[group_name] = []
      end
      group_hash[group_name] << t
    end

    group_array = []
    group_hash.each do |name, group|
      grp_name = group_name_prefix + name.downcase
      grp = { name: grp_name,
              targets: group }
      # deep merge so we can preserve any config options set "deep" in the tree
      group_array << Bolt::Util.deep_merge(group_configs.fetch(grp_name.to_sym, {}), grp)
    end
    group_array.sort_by { |h| h[:name] }
  end

  def normalize_group_name(name)
    name.downcase!
    name.gsub(NAME_REGEX, '_')
  end

  def task(opts)
    data = resolve_reference(opts)
    return { value: data }
  rescue TaskHelper::Error => e
    # ruby_task_helper doesn't print errors under the _error key, so we have to
    # handle that ourselves
    return { _error: e.to_h }
  end
end

if $PROGRAM_NAME == __FILE__
  GroupBy.run
end
