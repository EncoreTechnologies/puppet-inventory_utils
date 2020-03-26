# inventory_utils

Welcome to your new module. A short overview of the generated parts can be found in the PDK documentation at https://puppet.com/pdk/latest/pdk_generating_modules.html .

The README template below provides a starting point with details about what information to include in your README.

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with inventory_utils](#setup)
    * [What inventory_utils affects](#what-inventory_utils-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with inventory_utils](#beginning-with-inventory_utils)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

Briefly tell users why they might want to use your module. Explain what your module does and what kind of problems users can solve with it.

This should be a fairly short description helps the user decide if your module is what they want.


## Usage

### inventory_utils::erb_template

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

### inventory_utils::group_by

Below is an inventory file that uses the Group By to query PuppetDB and create groups
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

