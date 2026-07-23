#!/bin/sh
echo 'ETUS_AGENT_EVENT:{"type":"test-start","testName":"test"}'
echo 'ETUS_AGENT_EVENT:{"type":"test-complete","testName":"test","status":"passed"}'
exit 0
