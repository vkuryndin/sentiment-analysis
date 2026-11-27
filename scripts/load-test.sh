#!/usr/bin/env bash
end=$((SECONDS + 240))
ok=0
last=$SECONDS
echo "Load test started: 8 parallel requests"
while (( SECONDS < end )); do
  pids=()
  for i in {1..8}; do
    curl -fsS --max-time 10 -G \
      --data-urlencode "text=Это отличный продукт" \
      --data-urlencode "lang=ru" \
      http://10.100.148.160/api/sentiment > /dev/null &
    pids+=("$!")
  done
  errors=0
  for pid in "${pids[@]}"; do
    if wait "$pid"; then
      ((ok+=1))
    else
      ((errors+=1))
    fi
  done
  if (( errors > 0 )); then
    echo "STOP: successful=$ok, failed=$errors"
    exit 1
  fi
  if (( SECONDS - last >= 5 )); then
    echo "OK: $ok requests, errors=0"
    last=$SECONDS
  fi
  sleep 0.05
done
echo "DONE: successful=$ok, errors=0"
