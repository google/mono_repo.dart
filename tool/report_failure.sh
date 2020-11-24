#!/bin/bash
curl -H "Content-Type: application/json" -X POST -d \
  "{'text':'Build failed! ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}'}" \
  "${CHAT_HOOK_URI}"
