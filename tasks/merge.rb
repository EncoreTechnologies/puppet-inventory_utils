#!/usr/bin/env ruby

task_helper = [
  # During a real bolt call, ruby_task_helper modules is installed in same directory as this module
  File.join(__dir__, '..', '..', 'ruby_task_helper', 'files', 'task_helper.rb'),
  # During development the ruby_task_helper module will be in the test module fixtures
  File.join(__dir__, '..', 'spec', 'fixtures', 'modules', 'ruby_task_helper', 'files', 'task_helper.rb'),
].find { |helper_path| File.exist?(helper_path) }
raise 'Could not find the Bolt ruby_task_helper' if task_helper.nil?
require_relative task_helper

class MergeTask < TaskHelper
  def do_deep_merge(hash1, hash2)
    hash1.merge(hash2) do |_key, old_value, new_value|
      if old_value.is_a?(Hash) && new_value.is_a?(Hash)
        do_deep_merge(old_value, new_value)
      else
        new_value
      end
    end
  end

  def task(hashes: nil,
           deep_merge: false,
           **_kwargs)
    result = {}
    if hashes.length == 0
      result = nil
    elsif hashes.length == 1
      result = hashes[0]
    else # hashes.length >= 2
      hashes.each do |arg|
        next if arg.is_a?(String) && arg.empty? # empty string is synonym for puppet's undef
        # If the argument was not a hash, skip it.
        unless arg.is_a?(Hash)
          raise TaskHelper::Error, "merge: unexpected argument type #{arg.class}, only expects hash arguments"
        end
        result = if deep_merge
                   do_deep_merge(result, arg)
                 else
                   result.merge(arg)
                 end
      end
    end

    return { value: result }
  rescue TaskHelper::Error => e
    # ruby_task_helper doesn't print errors under the _error key, so we have to
    # handle that ourselves
    return { _error: e.to_h }
  end
end

if $PROGRAM_NAME == __FILE__
  MergeTask.run
end
