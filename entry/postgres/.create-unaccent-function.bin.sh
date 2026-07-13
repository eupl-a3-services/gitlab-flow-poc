#!/bin/bash
DATABASE="$1"
USER="$2"

log DEBUG Creating unaccent extension and function in database: ${DATABASE}
psql -U postgres ${DATABASE} << 'EOF'
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE OR REPLACE FUNCTION public.immutable_unaccent(regdictionary, text)
  RETURNS text LANGUAGE c IMMUTABLE STRICT AS
'$libdir/unaccent', 'unaccent_dict';
EOF
psql -U ${USER} ${DATABASE} << 'EOF'
CREATE OR REPLACE FUNCTION public.f_unaccent(text)
  RETURNS text LANGUAGE sql IMMUTABLE STRICT AS
$func$
SELECT public.immutable_unaccent(regdictionary 'public.unaccent', $1)
$func$;
EOF