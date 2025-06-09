#!/bin/bash

# dir2env <DIRECTORY>
# Packs the specified DIRECTORY into a tar.xz archive,
# encodes it to base64 url-safe string (no padding, single line),
# exports it as an environment variable named DIR_<DIRNAME_UPPERCASE_NO_DOTS>,
# and creates a file dir-<dirname_lowercase_no_dots> with the export line.

_dir2env() {
  local dirpath="$1"

  assert DIR "$dirpath"

  local dirname
  dirname=$(basename "$dirpath")
  # Remove dots and convert to uppercase for variable name
  local varname="DIR_${dirname//./}"
  varname=${varname^^}

  # For filename: lowercase and remove dots
  local filename="dir-${dirname//./}"
  filename="${filename,,}.env"

  tar -cJf .env2dir.tar.xz -C "$(dirname "$dirpath")" "$dirname" || {
    log ERROR "Failed to create archive from directory '$dirpath'."
    return 2
  }

  local encoded
  encoded=$(base64 .env2dir.tar.xz | tr -d '\n' | tr '+/' '-_' | sed 's/=*$//')

  rm -f .env2dir.tar.xz

  export "$varname=$encoded"
  log INFO "Exported variable: $varname"

  # Create the env file with export statement
  echo "$varname=$encoded" > "$filename"
  log INFO "Created env file: $filename"
}

if [[ $# -ne 1 ]]; then
    log USAGE "$0 <DIRECTORY_PATH>"
    exit 64
fi

_dir2env "$1"