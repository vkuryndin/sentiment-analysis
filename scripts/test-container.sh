#!/usr/bin/env bash
# Exercise the already-built, optimized image through its real HTTP API.
set -euo pipefail
base=${1:?Usage: test-container.sh BASE_URL}
body=$(mktemp)
trap 'rm -f "$body"' EXIT
checks=0
declare -A predictions=()
request() {
    local expected=$1 label=$2 status
    shift 2
    status=$(curl --noproxy '*' --silent --show-error --max-time 15 --output "$body" --write-out '%{http_code}' "$@")
    if [[ "$status" != "$expected" ]]; then
        echo "$label: expected HTTP $expected, got $status" >&2
        cat "$body" >&2
        exit 1
    fi
    checks=$((checks+1))
    echo "HTTP $status: $label"
}
assert_json() {
    if ! jq -e "$@" "$body" >/dev/null; then
        cat "$body" >&2
        exit 1
    fi
}
record_prediction() {
    local lang=$1 expected=$2 actual key
    if [[ "$expected" == any ]]; then
        assert_json 'type == "object" and (keys == ["sentiment"]) and (.sentiment == "positive" or .sentiment == "negative" or .sentiment == "neutral")'
    else
        assert_json --arg expected "$expected" '. == {sentiment: $expected}'
    fi
    actual=$(jq -r .sentiment "$body")
    key="$lang,$actual"
    predictions[$key]=$(( ${predictions[$key]:-0} + 1 ))
}
get_prediction() {
    local lang=$1 expected=$2 text=$3
    if [[ "$lang" == default ]]; then
        request 200 "GET default / $expected" --get --data-urlencode "text=$text" "$base/api/sentiment"
        lang=en
    else
        request 200 "GET $lang / $expected" --get --data-urlencode "text=$text" --data-urlencode "lang=$lang" "$base/api/sentiment"
    fi
    record_prediction "$lang" "$expected"
}
post_prediction() {
    local lang=$1 expected=$2 text=$3 json
    if [[ "$lang" == default ]]; then
        json=$(jq -nc --arg text "$text" '{text:$text}')
        lang=en
    else
        json=$(jq -nc --arg text "$text" --arg lang "$lang" '{text:$text,lang:$lang}')
    fi
    request 200 "POST $lang / $expected" -H 'Content-Type: application/json' --data "$json" "$base/api/sentiment"
    record_prediction "$lang" "$expected"
}
bad_post() {
    request 400 "$1" -H 'Content-Type: application/json' --data "$2" "$base/api/sentiment"
}
en_pos='Excellent food and friendly service. I absolutely loved this restaurant!'
en_neg='Terrible food, rude staff and horrible service. I will never come back.'
ru_pos='Очень вкусная еда! Прекрасное обслуживание, всем рекомендую!'
ru_neg='Ужасный ресторан. Еда отвратительная, обслуживание ужасное!'
ru_neutral='Сегодня понедельник. Магазин открывается в девять часов.'
request 200 'Actuator health' "$base/actuator/health"
assert_json '.status == "UP"'
get_prediction default positive hello
get_prediction en positive "$en_pos"
get_prediction en negative "$en_neg"
get_prediction ru positive "$ru_pos"
get_prediction ru negative "$ru_neg"
get_prediction ru neutral "$ru_neutral"
post_prediction default positive hello
post_prediction default positive "$en_pos"
post_prediction en negative "$en_neg"
post_prediction en positive $'Excellent food and friendly service.\nI absolutely loved this restaurant!'
post_prediction ru positive "$ru_pos"
post_prediction ru negative "$ru_neg"
post_prediction ru neutral "$ru_neutral"
get_prediction ru any 'Отлично'
# Valid text with more tokens than the model's context: truncation, not HTTP 500.
long_ru=$(printf 'я %.0s' {1..900})
post_prediction ru any "$long_ru"
request 400 'GET missing text' "$base/api/sentiment"
request 400 'GET empty text' "$base/api/sentiment?text="
request 400 'GET blank text' --get --data-urlencode 'text=   ' "$base/api/sentiment"
request 400 'GET unsupported language' "$base/api/sentiment?text=hello&lang=de"
long_en=$(printf 'a%.0s' {1..2001})
request 400 'GET text over 2000 characters' --get --data-urlencode "text=$long_en" "$base/api/sentiment"
bad_post 'POST missing text' '{"lang":"en"}'
bad_post 'POST empty text' '{"text":""}'
bad_post 'POST blank text' '{"text":"  \n  "}'
bad_post 'POST unsupported language' '{"text":"hello","lang":"de"}'
bad_post 'POST malformed JSON' '{"text": }'
bad_post 'POST text over 2000 characters' "$(jq -nc --arg text "$long_en" '{text:$text}')"
request 200 'Prometheus metrics' "$base/actuator/prometheus"
# All successful predictions must be counted exactly; rejected requests must not be counted.
for key in "${!predictions[@]}"; do
    lang=${key%,*}
    sentiment=${key#*,}
    metric="sentiment_predictions_total{language=\"$lang\",sentiment=\"$sentiment\"}"
    count=${predictions[$key]}
    awk -v metric="$metric" -v count="$count" '$1 == metric && $2 == count { found++ } END { exit(found != 1) }' "$body" || {
        echo "Wrong or missing metric: $metric, expected $count" >&2
        grep '^sentiment_predictions_total{' "$body" >&2 || true
        exit 1
    }
done
actual_total=$(awk '/^sentiment_predictions_total\{/ { sum += $2 } END { print sum+0 }' "$body")
expected_total=0
for count in "${predictions[@]}"; do expected_total=$((expected_total + count)); done
[[ "$actual_total" == "$expected_total" ]] || { echo "Unexpected total predictions: $actual_total != $expected_total" >&2; exit 1; }
grep '^sentiment_predictions_total{' "$body"
echo "All $checks HTTP checks passed; $expected_total successful predictions verified."
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "Final container: $checks HTTP checks passed; $expected_total successful predictions verified." >> "$GITHUB_STEP_SUMMARY"
fi
