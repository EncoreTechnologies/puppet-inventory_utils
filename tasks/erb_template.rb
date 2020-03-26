#!/usr/bin/env ruby

task_helper = [
  # During a real bolt call, ruby_task_helper modules is installed in same directory as this module
  File.join(__dir__, '..', '..', 'ruby_task_helper', 'files', 'task_helper.rb'),
  # During development the ruby_task_helper module will be in the test module fixtures
  File.join(__dir__, '..', 'spec', 'fixtures', 'modules', 'ruby_task_helper', 'files', 'task_helper.rb'),
].find { |helper_path| File.exist?(helper_path) }
raise 'Could not find the Bolt ruby_task_helper' if task_helper.nil?
require_relative task_helper
require 'erb'
require 'time'

# makes a private context for the variables passed in on the command line
class ErbSandbox
  def initialize(variables)
    variables.each { |name, value| instance_variable_set(name, value) }
  end

  # Expose private binding() method.
  def public_binding
    binding
  end
end

# Retrieves hosts from the WSUS SQL server
class ErbTemplateTask < TaskHelper
  def resolve_reference(opts)
    template = opts[:template]
    variables = opts[:variables] || {}
    sandbox = ErbSandbox.new(variables)
    renderer = ERB.new(template)
    renderer.result(sandbox.public_binding)
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
  ErbTemplateTask.run
end
