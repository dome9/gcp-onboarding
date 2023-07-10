while [[ "$#" -gt 0 ]]; do
  case $1 in
    --sinks=*)
      SINKS="${1#*=}"
      ;;
    *)
      echo "Invalid option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# Example input: --sinks='[{"projectId":"project1", "sinkName":"sink1"}, {"projectId":"project2", "sinkName":"sink2"}]'

for sink in $(echo "$SINKS" | jq -c '.[]'); do
  PROJECT_ID=$(echo "$sink" | jq -r '.projectId')
  SINK_NAME=$(echo "$sink" | jq -r '.sinkName')

  # Rest of your script
  # Use $PROJECT_ID and $SINK_NAME in your commands
done
