update-overlay name:
  #!/usr/bin/env bash
  overlay="$name"
  echo "Implement generic dispatch for $overlay using manifest metadata."

update-all-overlays:
  #!/usr/bin/env bash
  echo "Iterate through manifest entries or overlay directories and call just update-overlay <name>."