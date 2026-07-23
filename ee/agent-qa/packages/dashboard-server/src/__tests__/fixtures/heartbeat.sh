#!/bin/sh
echo 'ETUS_AGENT_EVENT:{"type":"test-start","testName":"test"}'
while true; do
  echo 'ETUS_AGENT_EVENT:{"type":"heartbeat"}'
  sleep 2
done
