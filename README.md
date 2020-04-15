# inventory_utils

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
    mycoolfact: value_a
- name: hostname2.domain.tld
  facts:
    mycoolfact: value_b
- name: hostname3.domain.tld
  facts:
    mycoolfact: value_a
```

Key: `facts.mycoolfact`

This will separate those two targets by the value of the `mycoolfact` fact. For each unique
value, a group will be created and a list of all hosts with the same value for the `key` will
be appended.

Returned data:
``` yaml
- name: value_a
  targets:
    - name: hostname1.domain.tld
      facts:
        mycoolfact: value_a
    - name: hostname3.domain.tld
      facts:
        mycoolfact: value_a
- name: value_b
  targets:
    - name: hostname2.domain.tld
      facts:
        mycoolfact: value_b
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

