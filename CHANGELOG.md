# Changelog

All notable changes to this project will be documented in this file.

## Development

## Release 0.4.9 (2020-12-10)

- Switch from Travis to GitHub Actions

  Contributed by Nick Maludy (@nmaludy)
  
- Added a new task `inventory_utils::merge` to merge an array of hashes
  This is super useful in inventory files where you need to resolve/merge configs
  at different layers. Deep merge can be achieved by passing in the `deep_merge: true` parameter.

  Contributed by Nick Maludy (@nmaludy)

## Release 0.3.1 (2020-09-15)

- Fixed bug in `inventory_utils::group_by` where the `group_configs` option wasn't using
  the right group name when performing lookups, causing configs to not get merged in.
  
  Contributed by Nick Maludy (@nmaludy)

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
