#!/usr/bin/env bash
# Usage: issue-in-progress.sh <issue-number>
# Sets Status = "In Progress" once the issue has an assignee AND a linked branch.
set -euo pipefail

issue=$1

ready=$(gh api graphql \
  -F owner="${GITHUB_REPOSITORY%/*}" -F repo="${GITHUB_REPOSITORY#*/}" -F issue="$issue" \
  -f query='query($owner: String!, $repo: String!, $issue: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $issue) {
        assignees(first: 1) { totalCount }
        linkedBranches(first: 1) { totalCount }
      }
    }
  }' \
  --jq '.data.repository.issue | .assignees.totalCount > 0 and .linkedBranches.totalCount > 0')

[[ "$ready" == true ]] || { echo "Issue #$issue: waiting for assignee and linked branch"; exit 0; }

export GH_TOKEN=$PROJECT_TOKEN # GITHUB_TOKEN cannot access Projects
project=("$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json)
item_id=$(gh project item-add "${project[@]}" --url "https://github.com/$GITHUB_REPOSITORY/issues/$issue" --jq .id)
project_id=$(gh project view "${project[@]}" --jq .id)
field=$(gh project field-list "${project[@]}" --jq '.fields[] | select(.name == "Status")')

gh project item-edit --id "$item_id" --project-id "$project_id" \
  --field-id "$(jq -r .id <<< "$field")" \
  --single-select-option-id "$(jq -re '.options[] | select(.name == "In progress") | .id' <<< "$field")"
