#!/bin/bash
# sending an alert from NetApp to PagerDuty, deduplicated by netapp event ID and source ID
# netapp doc: https://docs.netapp.com/ocum-99/index.jsp (search for 'How scripts work with alerts')
# pagerduty doc: https://developer.pagerduty.com/docs/ZG9jOjExMDI5NTgx-sending-an-alert-event

IKEY="replace-by-real-pagerduty-integrtion-key"
ARGS="$*"
EVENT_NAME=${4-NetAppAlert}
EVENT_ID=${2}
DEDUP_KEY=${2}
##SEVERITY=${6}
SEVERITY=`echo ${6} } | tr '[:upper:]' '[:lower:]'`
SOURCE_ID=${8}
CUSTOM_DETAILS='{}'

# make a dedup key
if [ -n "$8" ]; then
  DEDUP_KEY="${EVENT_ID}-${SOURCE_ID}"
fi

# check arguments
if [ -z "$1" ]; then
  CUSTOM_DETAILS='{"args": "no args passed to this alert"}'
else
  CUSTOM_DETAILS="{
    \"args\": \"$ARGS\",
    \"dedupkey\": \"$DEDUP_KEY\",
    \"${1}\": \"${2}\",
    \"${3}\": \"${4}\",
    \"${5}\": \"${6}\",
    \"${7}\": \"${8}\",
    \"${9}\": \"${10}\",
    \"${11}\": \"${12}\",
    \"${13}\": \"${14}\",
    \"${15}\": \"${16}\"
  }"
fi

# ignore warning alerts
if [ "$SEVERITY" = "warning" ]; then
  echo 'warning ignored'
  exit 0
fi

# make sure severity is a valid value to pagerduty
if [ "$SEVERITY" != "critical" ] &&
  [ "$SEVERITY" != "error" ] &&
  [ "$SEVERITY" != "warning" ] &&
  [ "$SEVERITY" != "info" ]; then
  SEVERITY='error'
fi

DATA=`cat << EOF
 {
   "routing_key": "$IKEY",
   "dedup_key": "$DEDUP_key",
   "event_action": "trigger",
   "payload": {
     "summary": "$EVENT_NAME",
     "source": "$0",
     "severity": "$SEVERITY",
     "custom_details": $CUSTOM_DETAILS
   }
 }
EOF
`

echo $DATA

curl --header "Content-Type: application/json" \
  --request POST \
  --data "$DATA" \
  https://events.pagerduty.com/v2/enqueue
