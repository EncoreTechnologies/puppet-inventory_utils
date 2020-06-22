# inventory_utils

[![Build Status](https://travis-ci.org/EncoreTechnologies/puppet-inventory_utils.svg?branch=master)](https://travis-ci.org/EncoreTechnologies/puppet-inventory_utils)
[![Puppet Forge Version](https://img.shields.io/puppetforge/v/encore/inventory_utils.svg)](https://forge.puppet.com/encore/inventory_utils)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/encore/inventory_utils.svg)](https://forge.puppet.com/encore/inventory_utils)
[![Puppet Forge Score](https://img.shields.io/puppetforge/f/encore/inventory_utils.svg)](https://forge.puppet.com/encore/inventory_utils)
[![Puppet PDK Version](https://img.shields.io/puppetforge/pdk-version/encore/inventory_utils.svg)](https://forge.puppet.com/encore/inventory_utils)
[![puppetmodule.info docs](http://www.puppetmodule.info/images/badge.png)](http://www.puppetmodule.info/m/encore-inventory_utils)

## Description

Module that contains a lot of helpful Bolt tasks designed for use in dynamic inventory files.

## Usage

### inventory_utils::erb_template

It is sometimes necessary to dynamically render things at various points in your inventory
file. To help support this, we've created the `inventory_utils::erb_template` task.
This task takes a `template` parameter which is a string containing an ERB template.

Below is an inventory file that uses an ERB template to query PuppetDB for nodes that haven't
reported in, or haven't reported in within the last `3` hours (`3*60*60`).

``` yaml
version: 2
groups:
  - name: puppetdb_unreported
    targets:
      - _plugin: puppetdb
        query:
          _plugin: task
          task: inventory_utils::erb_template
          parameters:
            template: 'nodes[certname] { (report_timestamp is null) or (report_timestamp < "<%= (Time.now - (3*60*60)).iso8601 %>") }'
```

The task also accepts a `variables` hash to define variables that will be set when rendering
the template. These variables are set as `instance` variables inside of a sandbox class
when performing the rendering. You'll need to reference them with `@name` in your ERB template.

Below is an inventory file example that uses and ERB template to wuery for all Windows
targets, based on an `osfamily` variable passed in as a parameter to the task:

``` yaml
version: 2
groups:
  - name: puppetdb_windows
    config:
      transport: winrm
    targets:
      - _plugin: puppetdb
        query:
          _plugin: task
          task: inventory_utils::erb_template
          parameters:
            template: 'inventory[certname] { facts.osfamily = "<%= @osfamily %>" }'
            variables:
              osfamily: windows
```

This allows for some cool things, for example we could have another plugin that populates
the variables value and chain them together to then generate the PuppetDB query.

### inventory_utils::erb_template - Creating hosts ranges

Sometimes it's necessary to generate a list of hosts based on a range of numbers.
We can use ERB templating to help solve this problem. The ERB templates can be
used to generate YAML data, then parse that YAML and return the structured results
as the output of the plugin. To accomplish this, you can use the `parse` parameter
setting it to `parse: yaml` to tell the ERB templating task to parse the rendered
template as YAML (you can also use `parse: json` if you prefer to render JSON inside
of ERB).

Below is an example inventory of generating a list of hosts of the pattern 
`web[00-10].domain.tld`:

``` yaml
version: 2
groups:
 - name: hosts_range
   targets:
     _plugin: task
     task: inventory_utils::erb_template
     parameters:
       parse: yaml
       template: |
         <% (0..10).each do |num| %>
         - web<%= '%02d' % num %>.domain.tld
         <% end %>
```

This results in the following hosts list in the inventory:

```shell
$ bolt inventory show --targets hosts_range
web00.domain.tld
web01.domain.tld
web02.domain.tld
web03.domain.tld
web04.domain.tld
web05.domain.tld
web06.domain.tld
web07.domain.tld
web08.domain.tld
web09.domain.tld
web10.domain.tld
11 targets
```

### inventory_utils::group_by

This task takes a list of targets as input, potentially from another Bolt plugin, and
organizes them into groups based on a `key`. The `key` is a lookup string used to find data 
in each `target` based on property names. To drill down into sub-objects within the `target`, 
example to access `facts` or `vars`, use a `.` to traverse into those components.

**Example:**
Target Data:
```
- name: hostname1.domain.tld
  facts:
    mycoolfact: group_a
- name: hostname2.domain.tld
  facts:
    mycoolfact: group_b
- name: hostname3.domain.tld
  facts:
    mycoolfact: group_a
```

Key: `facts.mycoolfact`

This will separate those two targets by the value of the `mycoolfact` fact. For each unique
value, a group will be created and a list of all hosts with the same value for the `key` will
be appended.

Returned data:
``` yaml
- name: group_a
  targets:
    - name: hostname1.domain.tld
      facts:
        mycoolfact: group_a
    - name: hostname3.domain.tld
      facts:
        mycoolfact: group_a
- name: value_b
  targets:
    - name: hostname2.domain.tld
      facts:
        mycoolfact: group_b
```

Below is an inventory file that uses `inventory_utils::group_by` to query PuppetDB and create groups
based on their `wsus_target_group` fact.

``` yaml
version: 2
groups:
  - name: puppetdb_wsus
    groups:
      - _plugin: task
        task: inventory_utils::group_by
        parameters:
          key: 'facts.wsus_target_group'
          group_name_prefix: puppetdb_wsus_
          targets:
            _plugin: puppetdb
            query: "inventory[certname, facts.wsus_target_group] { facts.osfamily = 'windows' and facts.wsus_target_group is not null}"
            target_mapping:
              name: certname
              facts:
                wsus_target_group: facts.wsus_target_group
              features:
                - facts.wsus_target_group
```


#### Setting configuration options on a group

Below is an inventory file that uses `inventory_utils::group_by` to query PuppetDB and create groups
based on their `domain` fact. It then sets configuration options based on the group
name. In this case we want a different username to use when logging into these Windows host
based on the domain that the machine is in.

``` yaml
version: 2
groups:
  - name: puppetdb_ad
    groups:
      - _plugin: task
        task: inventory_utils::group_by
        parameters:
          key: 'facts.domain'
          group_configs:
            puppetdb_ad_ad1_domain_tld:
              config:
                winrm:
                  user: some_special_user@ad1.domain.tld
            puppetdb_ad_ad2_domain_tld:
              config:
                winrm:
                  user: some_special_user@ad2.domain.tld
          group_name_prefix: puppetdb_ad_
          targets:
            _plugin: puppetdb
            query: "inventory[certname, facts.domain] { facts.osfamily = 'windows' }"
            target_mapping:
              name: certname
              facts:
                domain: facts.domain
              features:
                - facts.ad_domain
```

Only the following keys can be specified in the `group_configs` hash:
 - `config`
 - `facts`
 - `features`
 - `vars`


### inventory_utils::group_configs

In certain scenarios you maybe already have a list of groups returned from another
Bolt inventory plugin. You may want to take those groups and assign `config` or `vars`, etc
to those groups by name, this is exactly what `inventory_utils::group_configs` is meant for.

Below the `some_group_returning_plugin` is expeted to return a list of groups.
Then, `inventory_utils::group_configs` matches those groups, by name, to the keys in 
the `group_configs` parameter. Finally, it merges the configs hash with the groups hash
producing a group with configuration options set. on the final group.

``` yaml
version: 2
groups:
  - name: puppetdb_ad
    groups:
      - _plugin: task
        task: inventory_utils::group_configs
        parameters:
          group_configs:
            puppetdb_ad_ad1_domain_tld:
              config:
                winrm:
                  user: some_special_user@ad1.domain.tld
            puppetdb_ad_ad2_domain_tld:
              config:
                winrm:
                  user: some_special_user@ad2.domain.tld
          groups:
            _plugin: some_group_returning_plugin
            ...
```

To be consistent with the way that Bolt works, if a user specifies config options "deep"
in the tree, those options are taken in favor of the "broad" options specified higher up
in the tree.

Example:

``` yaml
version: 2
groups:
  - name: ad
    groups:
      - _plugin: task
        task: inventory_utils::group_configs
        parameters:
          group_configs:
            ad_ad1_domain_tld:
              config:
                winrm:
                  user: some_special_user@ad1.domain.tld
                  password: abc123
          groups:
            - name: ad_ad1_domain_tld
              config:
                winrm:
                  # this user option is preferred over the one set higher up in the group_configs parameter
                  user: my_specific_user
                
```

Only the following keys can be specified in the `group_configs` hash:
 - `config`
 - `facts`
 - `features`
 - `vars`
