=========================
 Devstack on Clear Linux
=========================

Clear Linux is not supported in upstream DevStack so support is carried
in a number of patches to upstream.

Bootstrapping Clear Linux
=========================

A new bootstrap script ``bootstrap-clear.sh`` has been added that does the
heavy lifting for getting the environment ready for DevStack.  It runs as
root (I know, right?) and sets up the ``stack`` user to enable the usual
workflow.

* Do the horrible thing and run bootstrap-clear.sh directly from the repo::

	curl https://???/devstack/???/tools/bootstrap-clear.sh | bash

* Log in as the newly-minted stack user and get started::

	cd /opt/stack/devstack
	vi local.conf
	# muck about and make it the way you want
	./stack.sh
