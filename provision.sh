#!/bin/sh

set -e

# Install docker
curl -sSL https://get.docker.com/ubuntu/ | sudo sh

# Install mercurial
apt-get install -y mercurial

# Install go
cd /opt
wget --no-verbose https://storage.googleapis.com/golang/go1.4.1.linux-amd64.tar.gz
tar xzf go1.4.1.linux-amd64.tar.gz

cat <<EOF > /etc/environment
PATH="/opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
GOROOT=/opt/go
GOPATH=/opt/workspace
EOF

# Create the go workspace
mkdir -p /opt/workspace

# Export environment so we can use it.
export PATH="/opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
export GOROOT=/opt/go
export GOPATH=/opt/workspace

cd $GOPATH
# Get the present tool
# TODO: I'd like to use the git repo but it seems not to work right now.
# go get github.com/golang/tools/cmd/present
echo "Installing cmd/present..."
go get code.google.com/p/go.tools/cmd/present

# Get the docker client library
echo "Installing go-dockerclient..."
go get github.com/fsouza/go-dockerclient

# Pull the nginx docker image.
docker pull nginx

# Run the tool so that the presentation can be viewed.
# NOTE: For some reason the root user doesn't load /etc/environment so we add the
#       necessary environment variables here too..
cat <<EOF > /usr/local/bin/present.sh
#!/bin/sh
$GOPATH/bin/present -http="0.0.0.0:3999" -orighost="localhost"
EOF
chmod +x /usr/local/bin/present.sh

cat <<EOF > /etc/init.d/present
#!/bin/sh
### BEGIN INIT INFO
# Provides:          present
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Example initscript
# Description:       This file should be used to construct scripts to be
#                    placed in /etc/init.d.
### END INIT INFO

# Author: Foo Bar <foobar@baz.org>
#
# Please remove the "Author" lines above and replace them
# with your own name if you copy and modify this script.

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
GOPATH=$GOPATH
GOROOT=$GOROOT
PATH=\$GOPATH/bin:\$GOROOT/bin:/sbin:/usr/sbin:/bin:/usr/bin
DESC="Presentation app"
NAME=present
DAEMON=/usr/local/bin/present.sh
DAEMON_ARGS=""
PIDFILE=/var/run/\$NAME.pid
SCRIPTNAME=/etc/init.d/\$NAME

# Exit if the package is not installed
[ -x "\$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/\$NAME ] && . /etc/default/\$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
# and status_of_proc is working.
. /lib/lsb/init-functions

#
# Function that starts the daemon/service
#
do_start()
{
	# Return
	#   0 if daemon has been started
	#   1 if daemon was already running
	#   2 if daemon could not be started
	start-stop-daemon --start --quiet --background --chdir \$GOPATH/src/github.com/IanMLewis/docker_meetup_slides --make-pidfile --pidfile \$PIDFILE --exec \$DAEMON --test > /dev/null \
		|| return 1
	start-stop-daemon --start --quiet --background --chdir \$GOPATH/src/github.com/IanMLewis/docker_meetup_slides --make-pidfile --pidfile \$PIDFILE --exec \$DAEMON -- \
		\$DAEMON_ARGS \
		|| return 2
	# Add code here, if necessary, that waits for the process to be ready
	# to handle requests from services started subsequently which depend
	# on this one.  As a last resort, sleep for some time.
}

#
# Function that stops the daemon/service
#
do_stop()
{
	# Return
	#   0 if daemon has been stopped
	#   1 if daemon was already stopped
	#   2 if daemon could not be stopped
	#   other if a failure occurred
	start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile \$PIDFILE --name \$NAME
	RETVAL="\$?"
	[ "\$RETVAL" = 2 ] && return 2
	# Wait for children to finish too if this is a daemon that forks
	# and if the daemon is only ever run from this initscript.
	# If the above conditions are not satisfied then add some other code
	# that waits for the process to drop all resources that could be
	# needed by services started subsequently.  A last resort is to
	# sleep for some time.
	start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec \$DAEMON
	[ "\$?" = 2 ] && return 2
	# Many daemons don't delete their pidfiles when they exit.
	rm -f \$PIDFILE
	return "\$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
	#
	# If the daemon can reload its configuration without
	# restarting (for example, when it is sent a SIGHUP),
	# then implement that here.
	#
	start-stop-daemon --stop --signal 1 --quiet --pidfile \$PIDFILE --name \$NAME
	return 0
}

case "\$1" in
  start)
	[ "\$VERBOSE" != no ] && log_daemon_msg "Starting \$DESC" "\$NAME"
	do_start
	case "\$?" in
		0|1) [ "\$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "\$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
	;;
  stop)
	[ "\$VERBOSE" != no ] && log_daemon_msg "Stopping \$DESC" "\$NAME"
	do_stop
	case "\$?" in
		0|1) [ "\$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "\$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
	;;
  status)
	status_of_proc "\$DAEMON" "\$NAME" && exit 0 || exit \$?
	;;
  #reload|force-reload)
	#
	# If do_reload() is not implemented then leave this commented out
	# and leave 'force-reload' as an alias for 'restart'.
	#
	#log_daemon_msg "Reloading \$DESC" "\$NAME"
	#do_reload
	#log_end_msg \$?
	#;;
  restart|force-reload)
	#
	# If the "reload" option is implemented then remove the
	# 'force-reload' alias
	#
	log_daemon_msg "Restarting \$DESC" "\$NAME"
	do_stop
	case "\$?" in
	  0|1)
		do_start
		case "\$?" in
			0) log_end_msg 0 ;;
			1) log_end_msg 1 ;; # Old process is still running
			*) log_end_msg 1 ;; # Failed to start
		esac
		;;
	  *)
		# Failed to stop
		log_end_msg 1
		;;
	esac
	;;
  *)
	#echo "Usage: \$SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
	echo "Usage: \$SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
	exit 3
	;;
esac

:
EOF

sudo chmod +x /etc/init.d/present
sudo update-rc.d -f present remove
sudo update-rc.d present defaults 

# Execute the present script to start the app.
/etc/init.d/present start
