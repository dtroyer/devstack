#!/usr/bin/env bash

# **config_tempest.sh** - Stand-alone Tempest config generator

# Requirements:
# ENABLED_SERVICES=tempest
# DEFAULT_INSTANCE_TYPE=<flavor-id>
# DEFAULT_IMAGE_NAME=<image-name>
# SERVICE_PROTOCOL=
# SERVICE_HOST=
# TEMPEST_USERNAME=<user>
# TEMPEST_PASSWORD=<password>
# ALT_USERNAME=??
# ALT_PASSWORD=??

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

# Import config functions
source $TOP_DIR/lib/config

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Exit on error to stop unexpected errors
set -o errexit
set -o xtrace

function usage {
    echo "Usage: $0 - Configure Tempest"
    exit 1
}

# Phase: local
rm -f $TOP_DIR/.localrc.auto
if [[ -r $TOP_DIR/local.conf ]]; then
    LRC=$(get_meta_section_files $TOP_DIR/local.conf local)
    for lfile in $LRC; do
        if [[ "$lfile" == "localrc" ]]; then
            if [[ -r $TOP_DIR/localrc ]]; then
                warn $LINENO "localrc and local.conf:[[local]] both exist, using localrc"
            else
                echo "# Generated file, do not edit" >$TOP_DIR/.localrc.auto
                get_meta_section $TOP_DIR/local.conf local $lfile >>$TOP_DIR/.localrc.auto
            fi
        fi
    done
fi

if [[ ! -r $TOP_DIR/stackrc ]]; then
    log_error $LINENO "missing $TOP_DIR/stackrc - did you grab more than just stack.sh?"
fi
source $TOP_DIR/stackrc

FILES=$TOP_DIR/files
if [ ! -d $FILES ]; then
    log_error $LINENO "missing devstack/files"
fi

sudo mkdir -p $DEST
safe_chown -R $STACK_USER $DEST
safe_chmod 0755 $DEST

DATA_DIR=${DATA_DIR:-${DEST}/data}
sudo mkdir -p $DATA_DIR
safe_chown -R $STACK_USER $DATA_DIR

FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.0/24}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}

HOST_IP=$(get_default_host_ip $FIXED_RANGE $FLOATING_RANGE "$HOST_IP_IFACE" "$HOST_IP")
if [ "$HOST_IP" == "" ]; then
    die $LINENO "Could not determine host ip address.  See local.conf for suggestions on setting HOST_IP."
fi

# Allow the use of an alternate hostname (such as localhost/127.0.0.1) for service endpoints.
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}

# Allow the use of an alternate protocol (such as https) for service endpoints
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}

source $TOP_DIR/lib/tls

source $TOP_DIR/lib/infra
source $TOP_DIR/lib/oslo
source $TOP_DIR/lib/stackforge

source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/cinder

install_infra
# install_oslo
#
# install_keystoneclient
# install_glanceclient
# install_cinderclient
# install_novaclient

# Phase: source
#source $TOP_DIR/extras.d/80-tempest.sh source
source $TOP_DIR/lib/tempest

# Phase: install
#source $TOP_DIR/extras.d/80-tempest.sh stack install
install_tempest

# Phase: post-config
# Skip this for now as it only creates accounts and we're not doing that
#source $TOP_DIR/extras.d/80-tempest.sh stack post-config

# Phase: extra
# Skip this to avoid init_tempest()
#source $TOP_DIR/extras.d/80-tempest.sh stack extra
configure_tempest

# Fixups that could be fixed in lib/tempest

# Re-set the Identity URI's to allow setting port
iniset $TEMPEST_CONFIG identity uri "$KEYSTONE_SERVICE_PROTOCOL://$KEYSTONE_SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v2.0/"
iniset $TEMPEST_CONFIG identity uri_v3 "$KEYSTONE_SERVICE_PROTOCOL://$KEYSTONE_SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v3/"

# Compute
iniset $TEMPEST_CONFIG compute-feature-enabled api_v3 False

# Services
iniset $TEMPEST_CONFIG service_available swift false

