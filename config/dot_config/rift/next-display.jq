# Support the CLI array and protocol envelopes; fail closed on unknown data.
def displays:
  if type == "array" then .
  elif type == "object" and has("error") then error(.error | tostring)
  elif type == "object" and has("data") then .data | displays
  elif type == "object" and has("displays") then .displays | displays
  else error("Unexpected Rift display response") end;

displays
| map(select(.is_active_space == true))
| if all(.[];
    (.uuid | type) == "string" and (.uuid | length) > 0
    and (.frame.origin.x | type) == "number"
    and (.frame.origin.y | type) == "number") then .
  else error("Managed display is missing its UUID or coordinates") end
| if (map(.uuid) | unique | length) == length then .
  else error("Duplicate display UUIDs") end
| sort_by([.frame.origin.x, .frame.origin.y, .uuid]) as $screens
| if ($screens | length) < 2 then ""
  else
    [$screens | to_entries[] | select(.value.is_active_context == true) | .key] as $active
    | if ($active | length) != 1 then
        error("Cannot identify a unique active managed display")
      else
        $screens[(($active[0] + 1) % ($screens | length))].uuid
      end
  end
