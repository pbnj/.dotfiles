# Normalize gh-attention's overlapping sections into one prioritized PR list.
def valid_pr:
  type == "object" and
  (.repo | type == "string") and
  (.number | type == "number" and . > 0 and . == floor) and
  (.title | type == "string") and
  # Only GitHub PR URLs can become browser click actions.
  (.url | type == "string" and test("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$"));

if type != "object" or
  ([.approved, .review, .feedback, .failing] | all(.[]; type == "array") | not)
then error("Invalid gh attention sections") else . end
| if all(.[][]; valid_pr) then . else error("Invalid gh attention PR") end
| . as $sections
| {
    fetchedAt: $fetched_at,
    counts: ($sections | with_entries(.value |= length)),
    prs: (
      [$sections | to_entries[] | .key as $section | .value[] | . + {section: $section}]
      | group_by(.url)
      | map(
          . as $copies | .[0] + {
            failing: any($copies[]; .section == "failing"),
            feedback: any($copies[]; .section == "feedback"),
            approved: any($copies[]; .section == "approved"),
            requested: any($copies[]; .section == "requested")
          }
          | .rank = (
              if .failing then 0
              elif .feedback then 1
              elif .conflicting then 2
              elif .approved then 3
              elif .requested then 4
              else 5 end
            )
        )
      # Stable newest-first ordering within each urgency group.
      | sort_by(.updatedAt // "") | reverse | sort_by(.rank)
    )
  }
