# ceph.sh - Devstack extras script to install Ceph

if is_service_enabled ceph; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/storage_plugins/ceph
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Ceph"
        install_storage_ceph
        echo_summary "Configuring Ceph"
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        configure_storage_ceph
        # NOTE (leseb): unfortunately we do everything here because we need to have Ceph started before the main
        # OpenStack components. Ceph OSD must start here otherwise we can't upload any images
        # since the OSD will not be up by that time.
        echo_summary "Initializing Ceph"
        init_storage_ceph
        start_storage_ceph
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Configuring libvirt secret"
        import_libvirt_secret_storage_ceph
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_storage_ceph
        cleanup_storage_ceph
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_storage_ceph
    fi
fi
