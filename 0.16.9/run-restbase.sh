#!/bin/bash

set -e

domains=${!RB_CONF_DOMAIN_*}

#backward compatibility
if [[ -z "$RB_CONF_PARSOID_HOST" && -n "$MW_PARSOID_URL" ]]; then
    RB_CONF_PARSOID_HOST="$MW_PARSOID_URL"
fi
if [[ -z "$RB_CONF_NUM_WORKERS" && -n "$NUM_WORKERS" ]]; then
    RB_CONF_NUM_WORKERS="$NUM_WORKERS"
fi

cd $RB_HOME

# see https://phabricator.wikimedia.org/diffusion/GRES/browse/master/config.example.wikimedia.yaml
cat <<EOT > config.yaml
# Load some project templates. These are referenced / shared between domains
# in the root_spec further down.
default_project: &default_project
  x-modules:
    - path: projects/docker.yaml
      options: &default_options
        # 10 days Varnish caching, one day client-side
        purged_cache_control: ${RB_CONF_PURGED_CACHE_CONTROL:-s-maxage=864000, max-age=86400}
        # Cache control for purged endpoints allowing short-term client caching
        purged_cache_control_client_cache: ${RB_CONF_PURGED_CACHE_CONTROL_CLIENT_CACHE:-s-maxage=1209600, max-age=300}
        related:
          cache_control: ${RB_CONF_RELATED_CACHE_CONTROL:-s-maxage=86400, max-age=86400}
        action:
          apiUriTemplate: "{{'${RB_CONF_API_URI_TEMPLATE:-'http://{domain}/w/api.php'}'}}"
          baseUriTemplate: "{{'${RB_CONF_BASE_URI_TEMPLATE:-'http://{domain}/api/rest_v1'}'}}"
        skip_updates: ${RB_CONF_SKIP_UPDATES:-false}
        table:
          backend: sqlite
          dbname: /data/restbase.sqlite3
          pool_idle_timeout: 20000
          retry_delay: 250
          retry_limit: 10
          show_sql: false
EOT

if [ -n "$RB_CONF_PARSOID_HOST" ]; then
    cat <<EOT >> config.yaml
        parsoid:
          host: $RB_CONF_PARSOID_HOST
EOT
fi

if [ -n "$RB_CONF_GRAPHOID_HOST" ]; then
    cat <<EOT >> config.yaml
        graphoid:
          host: $RB_CONF_GRAPHOID_HOST
EOT
fi

if [ -n "$RB_CONF_MATHOID_HOST" ]; then
    cat <<EOT >> config.yaml
        mathoid:
          host: $RB_CONF_MATHOID_HOST
          cache-control: ${RB_CONF_MATHOID_CACHE_CONTROL:-s-maxage=864000, max-age=86400}
EOT
fi

if [ -n "$RB_CONF_MOBILEAPPS_HOST" ]; then
    cat <<EOT >> config.yaml
        mobileapps:
          host: $RB_CONF_MOBILEAPPS_HOST
EOT
fi

if [ -n "$RB_CONF_CITOID_HOST" ]; then
    cat <<EOT >> config.yaml
        citoid:
          host: $RB_CONF_CITOID_HOST
EOT
fi

if [ -n "$RB_CONF_RECOMMENDATION_HOST" ]; then
    cat <<EOT >> config.yaml
        recommendation:
          host: $RB_CONF_RECOMMENDATION_HOST
EOT
fi

if [ -n "$RB_CONF_PDF_URI" ]; then
    cat <<EOT >> config.yaml
        pdf:
          uri: $RB_CONF_PDF_URI
          cache_control: ${RB_CONF_PDF_CACHE_CONTROL:-s-maxage=600, max-age=600}
          secret: ${RB_CONF_PDF_SECRET:-secret}
EOT
fi

if [ -n "$RB_CONF_TRANSFORM_CX_HOST" ]; then
    cat <<EOT >> config.yaml
        transform:
          cx_host: $RB_CONF_TRANSFORM_CX_HOST
EOT
fi

# see https://phabricator.wikimedia.org/diffusion/GRES/browse/master/config.example.wikimedia.yaml
cat <<EOT >> config.yaml
#
# The root of the spec tree. Domains tend to share specs by referencing them
# using YAML references.
spec_root: &spec_root
  title: "The RESTBase root"
  x-request-filters:
    - path: lib/security_response_header_filter.js
  x-sub-request-filters:
    - type: default
      name: http
      options:
        allow:
          - pattern: ${MW_PARSOID_URL:-http://parsoid:8000}
            forward_headers: true
          - pattern: /^https?:\/\//
EOT

for var in $domains
do
    if [ -n "${!var}" ]; then
    cat <<EOT >> config.yaml
          - pattern: ${!var} # ${var:15}
            forward_headers: true
EOT
    else
        echo "Variable ${!var} is empty"
    fi
done

cat <<EOT >> config.yaml
  paths:
    # A robots.txt to make sure that the content isn't indexed.
    /robots.txt:
      get:
        x-request-handler:
          - static:
              return:
                status: 200
                headers:
                  content-type: text/plain
                body: |
                  User-agent: *
                  Allow: /*/v1/?doc
                  Disallow: /
EOT

for var in $domains
do
    if [ -n "${!var}" ]; then
        cat <<EOT >> config.yaml
    /{domain:${var:15}}: *default_project
EOT
    fi
done

# see https://phabricator.wikimedia.org/diffusion/GRES/browse/master/config.example.yaml
# see https://phabricator.wikimedia.org/diffusion/GRES/browse/master/config.example.wikimedia.yaml
cat <<EOT >> config.yaml
#
#
# Finally, a standard service-runner config.
info:
  name: restbase

services:
  - name: restbase
    module: hyperswitch
    conf:
      port: 7231
      spec: *spec_root
      salt: secret
      default_page_size: 125
      user_agent: '${RB_CONF_USER_AGENT:-RESTBase}'
      ui_name: '${RB_CONF_UI_NAME:-RESTBase}'
      ui_url: '${RB_CONF_UI_URL:-https://www.mediawiki.org/wiki/RESTBase}'
      ui_title: '${RB_CONF_UI_TITLE:-RESTBase docs}'

logging:
  name: restbase
  level: ${RB_CONF_LOGGING_LEVEL:-info}

# Number of worker processes to spawn.
# Set to 0 to run everything in a single process without clustering.
# Use 'ncpu' to run as many workers as there are CPU units
num_workers: ${RB_CONF_NUM_WORKERS:-'0'}
EOT

# Use HTTP instead of HTTPS in pdf.yaml
sed -i -e 's#https://{{domain}}#http://{{domain}}#' v1/pdf.yaml

su -c 'npm start' $RB_USER
