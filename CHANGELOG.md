# Changelog

All notable changes to this project will be documented in this file.

## Release 0.3.0 (2020-07-22)

- Added a new parameter `group_configs` to the `inventory_utils::group_by` task.
  This new parameter can be used to assign configuration options based on a group's name
  that is returned. You can use this to add the following keys to a group's config:
  - `config`
  - `facts`
  - `features`
  - `vars`
  
- Similar to the change above, a new task was added `inventory::group_configs` that 
  accepts a list of `groups` and a `group_configs` hash. It's will then assign
  configuration data to groups based on name.
  
  Contributed by Nick Maludy (@nmaludy)


## Release 0.2.0 (2020-05-06)

**Features**

- Added a new parameter `parse` to the `inventory_utils::erb_template` task so that it
  can be used to parse YAML/JSON data. This allows ERB templates to render JSON/YAML
  then return structured data from tasks, resulting in us being able to generate
  lists of hosts in a range.
  
  Contributed by Nick Maludy (@nmaludy)

## Release 0.1.0

**Features**

**Bugfixes**

**Known Issues**
