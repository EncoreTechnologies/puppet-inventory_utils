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

### inventory_utils::deep_merge

If you ever find yourself needing to merge some hashes in your inventory file, this is the 
task for you! Perfect for working with YAML / JSON files containing targets, config, data, etc.

``` yaml
version: 2
config:
  _plugin: task
  task: inventory_utils::merge
  parameters:
    hashes:
      - _plugin: yaml
        filepath: ../inventory-defaults.yaml
      - _plugin: yaml
        filepath: inventory-overrides.yaml
```

#### Deep mergeing

Deep merging (same as `stdlib`'s [`deep_merge()`](https://github.com/puppetlabs/puppetlabs-stdlib/blob/master/REFERENCE.md#deep_merge)
function) can be accomplished by passing in the `deep_merge: true` parameter to the task.
This recursively merges any nested hashes.


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


# Example Inventory

This is an example inventory that we use internally (sanitized of course):
It is provided as a reference to showcase lots of "cool" things you can do within
the inventory file using the `inventory_utils` module:

```yaml
---
version: 2

config:
  _plugin: task
  task: inventory_utils::merge
  parameters:
    deep_merge: true
    hashes:
      - _plugin: yaml
        filepath: ../inventory-config.yaml
      - winrm:
          user: svc_bolt_windows@domain.tld
          password:
            _plugin: pkcs7
            encrypted_value: >
              ENC[PKCS7,xxx]

vars:
  patching_monitoring_target: 'solarwinds'
  patching_snapshot_delete: true
  vsphere_host: vsphere.domain.tld
  vsphere_username: svc_bolt_vsphere@domain.tld
  vsphere_password:
    _plugin: pkcs7
    encrypted_value: >
      ENC[PKCS7,xxx]
  vsphere_datacenter: datacenter1
  vsphere_insecure: true

groups:
  - name: solarwinds
    config:
      transport: remote
      remote:
        port: 17778
        username: 'domain\svc_bolt_solarwinds'
        password:
          _plugin: pkcs7
          encrypted_value: >
            ENC[PKCS7,xxx]

    targets:
      - solarwinds.domain.tld

  - name: puppetdb_linux
    config:
      transport: ssh
    targets:
      - _plugin: puppetdb
        query: "inventory[certname] { facts.osfamily != 'windows' order by certname }"

  - name: puppetdb_windows
    config:
      transport: winrm
    vars:
      patching_reboot_strategy: 'always'
    groups:
      - _plugin: task
        task: inventory_utils::group_by
        parameters:
          key: 'facts.domain'
          group_name_prefix: puppetdb_windows_
          group_configs:
            # servers in otherdomain.tld use a different account to login
            # to faciliate this we group by domain name and assign all hosts
            # with otherdomain.tld a different account to login
            puppetdb_windows_otherdomain_tld:
              config:
                winrm:
                  user: svc_bolt_windows@otherdomain.tld
                  password:
                    _plugin: pkcs7
                    encrypted_value: >
                      ENC[PKCS7,xxx]
          targets:
            _plugin: puppetdb
            query: "inventory[certname, facts.domain] { facts.osfamily = 'windows' order by certname }"
            target_mapping:
              name: certname
              uri: certname
              facts:
                domain: facts.domain

  - name: puppetdb_patching_linux
    config:
      transport: ssh
    groups:
      - _plugin: task
        task: inventory_utils::group_by
        parameters:
          key: 'facts.patching_group'
          group_name_prefix: puppetdb_patching_
          targets:
            _plugin: puppetdb
            query: "inventory[certname, facts.patching_group] { facts.osfamily != 'windows' order by certname }"
            target_mapping:
              name: certname
              uri: certname
              facts:
                patching_group: facts.patching_group

  - name: puppetdb_patching_windows
    config:
      transport: winrm
    vars:
      patching_reboot_strategy: 'always'
    groups:
      - _plugin: task
        task: inventory_utils::group_by
        parameters:
          key: 'facts.patching_group'
          group_name_prefix: puppetdb_patching_windows_
          group_configs:
            # the special 'no_snapshot_a' and 'no_snapshot_b' groups are exactly the same
            # except we don't want to do VMware snapshots on them because they are
            # for example in Hyper-V or Google Cloud
            puppetdb_patching_windows_no_snapshot_a:
              vars:
                patching_snapshot_plan: 'disabled'
                patching_snapshot_create: false
                patching_snapshot_delete: false
            puppetdb_patching_windows_no_snapshot_b:
              vars:
                patching_snapshot_plan: 'disabled'
                patching_snapshot_create: false
                patching_snapshot_delete: false
          targets:
            _plugin: puppetdb
            query: "inventory[certname, facts.patching_group] { facts.osfamily = 'windows' order by certname }"
            target_mapping:
              name: certname
              uri: certname
              facts:
                patching_group: facts.patching_group


  - name: puppetdb_unreported
    groups:
      - name: puppetdb_unreported_linux
        config:
          transport: ssh
        targets:
          - _plugin: puppetdb
            query:
              _plugin: task
              task: inventory_utils::erb_template
              parameters:
                template: 'nodes[certname] { facts { name = "osfamily" and value != "windows" } and ((report_timestamp is null) or (report_timestamp < "<%= (Time.now - (3*60*60)).iso8601 %>")) order by certname }'
    
      - name: puppetdb_unreported_windows
        config:
          transport: winrm
        vars:
          patching_reboot_strategy: 'always'
        targets:
          - _plugin: puppetdb
            query:
              _plugin: task
              task: inventory_utils::erb_template
              parameters:
                template: 'nodes[certname] { facts { name = "osfamily" and value = "windows" } and ((report_timestamp is null) or (report_timestamp < "<%= (Time.now - (3*60*60)).iso8601 %>")) order by certname }'


  - name: puppetdb_failed
    groups:
      - name: puppetdb_failed_linux
        config:
          transport: winrm
        vars:
          patching_reboot_strategy: 'always'
        targets:
          - _plugin: puppetdb
            query: 'nodes[certname] { facts { name = "osfamily" and value != "windows" } and latest_report_status = "failed" order by certname }'
            target_mapping:
              name: certname
              uri: certname
    
      - name: puppetdb_failed_windows
        config:
          transport: winrm
        vars:
          patching_reboot_strategy: 'always'
        targets:
          - _plugin: puppetdb
            query: 'nodes[certname] { facts { name = "osfamily" and value = "windows" } and latest_report_status = "failed" order by certname }'
            target_mapping:
              name: certname
              uri: certname

  - name: wsus
    config:
      transport: winrm
    vars:
      patching_reboot_strategy: 'always'
    groups:
      - _plugin: task
        task: inventory_utils::group_configs
        parameters:
          group_configs:
            # don't snapshot Hyper-V hosts
            wsus_servers_hv:
              vars:
                patching_reboot_strategy: 'always'
                patching_snapshot_plan: 'disabled'
                patching_snapshot_create: false
                patching_snapshot_delete: false
          groups:
            _plugin: wsus_inventory
            host: 'wsussql.domain.tld'
            database: 'SUSDB'
            username: domain\svc_bolt_wsussql'
            password:
              _plugin: pkcs7
              encrypted_value: >
                ENC[PKCS7,xxx]
            format: 'groups'
            filter_older_than_days: 1
            group_name_prefix: 'wsus_'
```
