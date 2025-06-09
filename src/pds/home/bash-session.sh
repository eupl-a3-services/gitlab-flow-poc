clear
printb "\U0001F13F\U0001F133\U0001F142 Production Deployment Session is temporarily open [ ${PDS_REVISION} | ${PDS_BUILD} ] \U0001F13F\U0001F133\U0001F142"

export PDS_TOKEN=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
printc GREEN "SESSION-VAULT" "/cache-volume/session-vault"
mkdir -p /cache-volume/session-vault
printc GREEN "SESSION-REQUEST" "/cache-volume/session-request"
mkdir -p /cache-volume/session-request
