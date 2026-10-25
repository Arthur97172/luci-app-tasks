#!/bin/sh
# luci-app-tasks shared helpers.
# POSIX sh only: /bin/sh on OpenWrt is BusyBox ash.

TASKS_CONFIG=tasks
TASKS_DIR=/etc/tasks
TASKS_LOG=$TASKS_DIR/tasks.log
TASKS_STARTUP=$TASKS_DIR/startup.sh
TASKS_CRON=/etc/crontabs/root
TASKS_MARK=luci-app-tasks
TASKS_LOG_LIMIT=500

# Read a UCI option, falling back to a default when it is unset.
# tasks_cfg <section> <option> [default]
tasks_cfg() {
	local value

	value=$(uci -q get "$TASKS_CONFIG.$1.$2" 2>/dev/null)
	[ -n "$value" ] || value=$3
	printf '%s' "$value"
}

# Clamp an integer option to [min, max]; non-numeric values become <default>.
# tasks_int <value> <min> <max> <default>
tasks_int() {
	local value=$1

	case "$value" in
		''|*[!0-9-]*)
			printf '%s' "$4"
			return 0
			;;
		-*)
			# Negative numbers are meaningless here; clamp to the minimum.
			printf '%s' "$2"
			return 0
			;;
		*[!0-9]*)
			printf '%s' "$4"
			return 0
			;;
	esac

	# Strip leading zeroes so arithmetic never treats the value as octal.
	value=$(printf '%s' "$value" | sed 's/^0*//')
	[ -n "$value" ] || value=0
	value=$((value + 0))

	[ "$value" -lt "$2" ] && value=$2
	[ "$value" -gt "$3" ] && value=$3
	printf '%s' "$value"
}

# Only allow the weekday presets emitted by the web UI.
# tasks_weekday <value> -> prints a safe cron weekday field
tasks_weekday() {
	case "$1" in
		''|*[!0-6,-]*)
			printf '*'
			;;
		*)
			printf '%s' "$1"
			;;
	esac
}

# Translate the friendly schedule options into a cron time expression.
# tasks_cron_expr <mode> <hour> <minute> <weekday> <monthday> <imin> <ihour>
tasks_cron_expr() {
	local mode=$1 hour=$2 minute=$3 weekday=$4 monthday=$5 imin=$6 ihour=$7

	case "$mode" in
		daily)
			printf '%s %s * * *' "$minute" "$hour"
			;;
		weekly)
			printf '%s %s * * %s' "$minute" "$hour" "$weekday"
			;;
		monthly)
			printf '%s %s %s * *' "$minute" "$hour" "$monthday"
			;;
		hourly)
			printf '%s * * * *' "$minute"
			;;
		interval_minutes)
			printf '*/%s * * * *' "$imin"
			;;
		interval_hours)
			printf '%s */%s * * *' "$minute" "$ihour"
			;;
		*)
			return 1
			;;
	esac
}

# A UCI section name must be safe to embed in generated shell code.
tasks_valid_section() {
	case "$1" in
		''|*[!A-Za-z0-9_-]*)
			return 1
			;;
	esac

	return 0
}

# An init.d service name must not escape /etc/init.d.
tasks_valid_service() {
	case "$1" in
		''|*[!A-Za-z0-9._-]*)
			return 1
			;;
	esac

	return 0
}

tasks_cron_count() {
	local count=0

	[ -f "$TASKS_CRON" ] && count=$(grep -c "$TASKS_MARK" "$TASKS_CRON" 2>/dev/null)
	[ -n "$count" ] || count=0
	printf '%s' "$count"
}

# tasks_log <source> <message>
tasks_log() {
	mkdir -p "$TASKS_DIR" 2>/dev/null
	printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$TASKS_LOG"
	chmod 600 "$TASKS_LOG" 2>/dev/null
	tasks_log_limit
}

# Keep the log bounded so it cannot grow forever on flash.
tasks_log_limit() {
	local count

	[ -f "$TASKS_LOG" ] || return 0
	count=$(wc -l <"$TASKS_LOG" 2>/dev/null)
	[ -n "$count" ] || count=0
	count=$((count + 0))

	if [ "$count" -gt "$TASKS_LOG_LIMIT" ]; then
		tail -n "$TASKS_LOG_LIMIT" "$TASKS_LOG" >"$TASKS_LOG.tmp.$$" 2>/dev/null &&
			mv "$TASKS_LOG.tmp.$$" "$TASKS_LOG"
	fi
}
