#!/usr/bin/env bash
# file-ci-failure-ticket.sh — file a Linear ticket when main-branch CI fails, or comment on
# the existing open one for this repo instead of creating a duplicate. Mirrors
# PeterChauYEG/labone-actions' scripts/file-ci-failure-ticket.sh, kept local per org policy —
# mecha-industries org repos may not depend on PeterChauYEG/labone-actions.
#
# Usage: file-ci-failure-ticket.sh <workflow-name> <run-url>
# Required env vars: LINEAR_API_KEY, GITHUB_REPOSITORY
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="[file-ci-failure-ticket]"
# shellcheck source=lib/linear-ticket.sh
source "$script_dir/lib/linear-ticket.sh"

workflow_name="${1:-Main}"
run_url="${2:-}"

CI_LABEL_ID="01f4906f-28d8-4ff9-b95c-a1d6de39d1ca"

if [[ -z "${LINEAR_API_KEY:-}" ]]; then
  echo "${LOG_PREFIX} WARN: LINEAR_API_KEY not set — skipping" >&2
  exit 0
fi

repo_name="${GITHUB_REPOSITORY#*/}"
title="🔴 CI failing on main: ${repo_name}"
ci_failure_key="ci-failure:${repo_name}:${workflow_name}"
ci_failure_marker="<!-- ci-failure-key: ${ci_failure_key} -->"

search_query=$(jq -n --arg descriptionContains "$ci_failure_marker" '{
  query: "query($descriptionContains: String!) { issues(filter: { team: { key: { eq: \"LAB\" } }, state: { type: { nin: [\"completed\", \"cancelled\", \"duplicate\"] } }, description: { contains: $descriptionContains } }, first: 1) { nodes { id identifier url } } }",
  variables: { descriptionContains: $descriptionContains }
}')

search_response=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$search_query")

existing_id=$(echo "$search_response" | jq -r '.data.issues.nodes[0].id // empty')
existing_identifier=$(echo "$search_response" | jq -r '.data.issues.nodes[0].identifier // empty')

if [[ -n "$existing_id" ]]; then
  echo "${LOG_PREFIX} existing open ticket $existing_identifier — commenting instead of creating a duplicate"
  comment_body="Still failing: \`${workflow_name}\` on main as of ${run_url}."
  linear_comment_on_issue "$existing_id" "$comment_body"
  exit 0
fi

team_id=$(linear_find_team_id)
state_id=$(linear_find_backlog_state_id)

description="**Repository:** \`${repo_name}\`
**Workflow:** \`${workflow_name}\`
**Run:** ${run_url}

${ci_failure_marker}
"

label_ids_json=$(jq -n --arg ciLabelId "$CI_LABEL_ID" '[$ciLabelId]')
linear_create_issue "$team_id" "$title" "$description" "$state_id" 1 "$label_ids_json"
