{# Essential packages #}

git package is installed:
  pkg.installed:
    - name: git

virtualenv is installed:
  pkg.installed:
    - name: virtualenv

{# Setting up and installing applications #}
{%- for application, options in salt['pillar.get']('applications', {}).items() %}

{%- set deploy = options.get('deploy', {}) %}
{%- set config = options.get('config', {}) %}
{%- set check = options.get('check', {}) %}

{%- set directory = deploy.get('directory', '/home/' + application) %}
{%- set user = deploy.get('user', application) %}
{%- set group = deploy.get('group', application) %}
{%- set service = deploy.get('service', application) %}
{%- set repository = deploy.get('repository', None) %}
{%- set branch = deploy.get('branch', 'master') %}
{%- set runtime = deploy.get('runtime', 'python2') %}

user is present for {{ application }}:
  user.present:
    - name: {{ user }}
    - home: {{ directory }}
    - system: True

group is present for {{ application }}:
  group.present:
    - name: {{ group }}
    - system: True

directory is present for {{ application }}:
  file.directory:
    - name: {{ directory }}
    - user: {{ user }}
    - group: {{ group }}
    - require:
      - user: user is present for {{ application }}
      - group: group is present for {{ application }}

virtualenv is installed for {{ application }}:
  pkg.installed:
    - name: {{ runtime }}-virtualenv
    - require:
      - pkg: virtualenv

deploy code for {{ application }}:
  git.latest:
    - name: {{ repository }}
    - target: {{ directory }}/code
    - user: {{ user }}
    - branch: {{ branch }}
    - require:
      - user: user is present for {{ application }}
      - pkg: git

deploy runtime for {{ application }}:
  virtualenv.managed:
    - name: {{ directory }}/runtime
    - user: {{ user }}
    - python: {{ runtime }}
    - system_site_packages: False
    - requirements: {{ directory }}/code/requirements.txt
    - require:
      - git: deploy code for {{ application }}
      - pkg: virtualenv is installed for {{ application }}

deploy app systemd unit for {{ application }}:
  file.managed:
    - name: /etc/systemd/system/{{ service }}.service
    - context:
        service: {{ service }}
        directory: {{ directory }}
        user: {{ user }}
        group: {{ group }}
    - source: salt://deployment/files/application.service.j2
    - template: jinja
    - require:
      - virtualenv: deploy runtime for {{ application }}
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/{{ service }}.service

enable service for {{ application }}:
  service.running:
    - name: {{ service }}
    - enable: True
    - require:
      - file: deploy app systemd unit for {{ application }}

deploy environment file for {{ application }}:
  file.managed:
    - name: {{ directory }}/.env
    - user: {{ user }}
    - group: {{ group }}
    - chmod: 0400
    - contents: |
        # Salt managed configuration
        {%- for entry, value in config.items() %}
        APP_{{ entry | upper }}={{ value }}
        {%- endfor %}

restart {{ application }} on redeploy or service changes:
  service.running:
    - name: {{ service }}
    - restart: True
    - order: last
    - watch:
      - git: deploy code for {{ application }}
      - virtualenv: {{ directory }}/runtime
      - file: /etc/systemd/system/{{ service }}.service
      - file: {{ directory }}/.env

issue event when {{ application }} is deployed:
  event.send:
    - name: application/service/register
    - data:
        application:
          service:
            name: {{ service }}
            id: {{ grains['host'] }}
            address: {{ grains['fqdn_ip4'][0] }}
            port: {{ config.get('port', 5000) }}
            endpoint: {{ check.get('endpoint', None) }}
            tags: {{ check.get('tags', None) }}
            interval: {{ check.get('interval', '30s') }}

{# End processing for applications #}
{%- endfor %}
