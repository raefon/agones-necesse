#!/usr/bin/env sh
set -eu

# Change to the unpacked server directory
cd /necesse/necesse-server* || exit 1

# Default local directory for server data (can be overridden)
LOCALDIR="${LOCALDIR:-.}"

# If args were provided to this script, use them verbatim.
# Otherwise, construct args from environment variables.
if [ "$#" -eq 0 ]; then
  # Start with required/commonly used flags
  set -- -world "${WORLD:-world}" -slots "${SLOTS:-10}"

  # Only include flags when values are provided
  [ -n "${OWNER:-}" ] && set -- "$@" -owner "${OWNER}"
  [ -n "${MOTD:-}" ] && set -- "$@" -motd "${MOTD}"
  [ -n "${PASSWORD:-}" ] && set -- "$@" -password "${PASSWORD}"
  [ -n "${PAUSE:-}" ] && set -- "$@" -pausewhenempty "${PAUSE}"
  [ -n "${GIVE_CLIENTS_POWER:-}" ] && set -- "$@" -giveclientspower "${GIVE_CLIENTS_POWER}"
  [ -n "${LOGGING:-}" ] && set -- "$@" -logging "${LOGGING}"
  [ -n "${ZIP:-}" ] && set -- "$@" -zipsaves "${ZIP}"

  # Optional: allow appending free-form flags via ARGS env (space-separated)
  # Note: quoting inside ARGS won't be preserved by sh word-splitting.
  if [ -n "${ARGS:-}" ]; then
    # shellcheck disable=SC2086
    set -- "$@" ${ARGS}
  fi
fi

# JVM options (e.g., -Xms512m -Xmx2g), optional
JVMARGS="${JVMARGS:-}"

# Restart loop (kept from your original script)
while true; do
  if [ -n "$JVMARGS" ]; then
    # shellcheck disable=SC2086
    java ${JVMARGS} -jar Server.jar -nogui -localdir "${LOCALDIR}" "$@" 2>&1
  else
    java -jar Server.jar -nogui -localdir "${LOCALDIR}" "$@" 2>&1
  fi
  sleep 10
done