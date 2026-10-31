#!/usr/bin/env bash
# scripts/lib/linear-ticket.sh — Linear GraphQL helpers shared by any script here that
# files/comments on tickets against the LAB team via Linear's GraphQL API.
# Requires: LINEAR_API_KEY, LOG_PREFIX env vars set by the caller.
set -euo pipefail

linear_graphql() {
  local query_json="$1"
  curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$query_json"
}

linear_comment_on_issue() {
  local issue_id="$1" body="$2" comment_json
  comment_json=$(jq -n --arg issueId "$issue_id" --arg body "$body" \
    '{query:"mutation($issueId:String!,$body:String!){commentCreate(input:{issueId:$issueId,body:$body}){success}}", variables:{issueId:$issueId, body:$body}}')
  linear_graphql "$comment_json" > /dev/null
}

linear_find_team_id() {
  local team_response team_id
  team_response=$(linear_graphql '{"query":"{ teams(filter: { key: { eq: \"LAB\" } }) { nodes { id } } }"}')
  team_id=$(echo "$team_response" | jq -r '.data.teams.nodes[0].id // empty')

  if [[ -z "$team_id" ]]; then
    echo "${LOG_PREFIX} ERROR: could not find LAB team" >&2
    exit 1
  fi

  echo "$team_id"
}

linear_find_backlog_state_id() {
  local states_response state_id
  states_response=$(linear_graphql '{"query":"{ workflowStates(filter: { team: { key: { eq: \"LAB\" } }, name: { eq: \"Backlog\" } }) { nodes { id } } }"}')
  state_id=$(echo "$states_response" | jq -r '.data.workflowStates.nodes[0].id // empty')

  if [[ -z "$state_id" ]]; then
    echo "${LOG_PREFIX} ERROR: could not find Backlog state" >&2
    exit 1
  fi

  echo "$state_id"
}

linear_create_issue() {
  local team_id="$1" title="$2" description="$3" state_id="$4" priority="$5" label_ids_json="$6"
  local mutation query_json create_response success identifier url

  mutation='mutation($teamId: String!, $title: String!, $description: String!, $stateId: String!, $priority: Int, $labelIds: [String!]) {
    issueCreate(input: {
      teamId: $teamId,
      title: $title,
      description: $description,
      stateId: $stateId,
      priority: $priority,
      labelIds: $labelIds
    }) {
      success
      issue { identifier url }
    }
  }'

  query_json=$(jq -n \
    --arg mutation "$mutation" \
    --arg teamId "$team_id" \
    --arg title "$title" \
    --arg description "$description" \
    --arg stateId "$state_id" \
    --argjson priority "$priority" \
    --argjson labelIds "$label_ids_json" \
    '{
      query: $mutation,
      variables: {
        teamId: $teamId,
        title: $title,
        description: $description,
        stateId: $stateId,
        priority: $priority,
        labelIds: $labelIds
      }
    }')

  create_response=$(linear_graphql "$query_json")
  success=$(echo "$create_response" | jq -r '.data.issueCreate.success // false')

  if [[ "$success" != "true" ]]; then
    echo "${LOG_PREFIX} ERROR: issueCreate failed for \"$title\": $(echo "$create_response" | jq -r '.errors[0].message // "unknown"')" >&2
    exit 1
  fi

  identifier=$(echo "$create_response" | jq -r '.data.issueCreate.issue.identifier')
  url=$(echo "$create_response" | jq -r '.data.issueCreate.issue.url')
  echo "${LOG_PREFIX} created $identifier: $url"
}
