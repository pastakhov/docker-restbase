# Containerized MediaWiki RESTbase service

This repo contains [Docker](https://docs.docker.com/) container to run the [RESTbase](https://www.mediawiki.org/wiki/RESTBase) proxy.

It is a part of [Containerized Mediawiki install](https://github.com/pastakhov/compose-mediawiki-ubuntu) project.

## Settings

- `RB_CONF_NUM_WORKERS` defines the number of worker processes to the RESTbase service. Set to `0` to run everything in a single process without clustering. Use `ncpu` to run as many workers as there are CPU units.
- `RB_CONF_DOMAIN_{domain}` defines uri and domain for RESTbase service. The '{domain}' word should be the same as `MW_REST_DOMAIN` parameter in MediaWiki web container. You can specify any number of such variables (by the number of domains for the service)
- `RB_CONF_PARSOID_HOST` defines uri to Parsoid service. Example: `http://parsoid:8000`.
- `RB_CONF_BASE_URI_TEMPLATE` defines base uri for the links to RESTBase service. Example: `http://{domain}/api/rest_v1`.
- `RB_CONF_API_URI_TEMPLATE` defines uri to the MediaWiki API. Example :`http://{domain}/w/api.php`

### Examples ###

The environment variable `RB_CONF_DOMAIN_web=http://mywiki/w/api.php` creates config contains:
```
default_project: &default_project
  x-modules:
    - path: projects/docker.yaml
      options: &default_options
        action:
          apiUriTemplate: "{{'${RB_CONF_API_URI_TEMPLATE:-'http://{domain}/w/api.php'}'}}"
          baseUriTemplate: "{{'${RB_CONF_BASE_URI_TEMPLATE:-'http://{domain}/api/rest_v1'}'}}"

spec_root: &spec_root
  x-sub-request-filters:
    options:
      allow:
        pattern: http://mywiki/w/api.php # web
  paths:
    /{domain:web}: *default_projecturi

services:
  - name: restbase
    conf:
      spec: *spec_root
```
