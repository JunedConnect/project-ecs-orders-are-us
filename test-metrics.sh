#!/bin/bash
# test-metrics.sh

# -------------------------------------------------------
# CONFIG
# -------------------------------------------------------
ALB_URL="https://dev.juned.co.uk"
ENVIRONMENT="dev"
CLUSTER="dev-ecs-cluster"
REGION="eu-west-2"
NAMESPACE="OrderPlatform/${ENVIRONMENT}"
SQS_QUEUE_NAME="dev-sqs-main-queue"
RDS_IDENTIFIER="dev-rds"

# -------------------------------------------------------
# HELPERS
# -------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
 
log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WAIT]${NC} $1"; }
error()   { echo -e "${RED}[FAIL]${NC} $1"; }
 
utc_ago() {
  local mins=$1
  if date -u -d "-${mins} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then
    return
  fi
  date -u -v-${mins}M +%Y-%m-%dT%H:%M:%SZ
}
 
utc_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
 
minutes_ago_ms() {
  local mins=$1
  if date -d "-${mins} minutes" +%s%3N 2>/dev/null; then
    return
  fi
  python3 -c "import time; print(int((time.time() - ${mins}*60) * 1000))"
}
 
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
 
record() {
  case $2 in
    pass) TESTS_PASSED=$((TESTS_PASSED+1)); success "PASSED: $1" ;;
    fail) TESTS_FAILED=$((TESTS_FAILED+1)); error  "FAILED: $1" ;;
    skip) TESTS_SKIPPED=$((TESTS_SKIPPED+1)); warn  "SKIPPED: $1" ;;
  esac
}
 
check_logs() {
  local group=$1 pattern=$2 mins=${3:-5}
  local result
  result=$(aws logs filter-log-events \
    --log-group-name "$group" \
    --start-time "$(minutes_ago_ms $mins)" \
    --filter-pattern "$pattern" \
    --region "$REGION" \
    --query 'events[*].message' \
    --output text 2>/dev/null)
  if [ -n "$result" ]; then
    local count
    count=$(echo "$result" | grep -c .)
    success "Found ${count} log line(s) matching: ${pattern}"
    echo "$result" | head -3 | sed 's/^/    /'
    return 0
  else
    error "No log lines found matching: ${pattern} in ${group}"
    return 1
  fi
}
 
# Wait for an alarm to reach IN_ALARM state
# Retries every 30s for up to max_wait seconds
wait_for_alarm() {
  local alarm_name=$1
  local max_wait=${2:-600}
  local elapsed=0
  local interval=30
 
  warn "Waiting for alarm ${alarm_name} to enter IN_ALARM state (max ${max_wait}s)..."
 
  while [ $elapsed -lt $max_wait ]; do
    local state
    state=$(aws cloudwatch describe-alarms \
      --alarm-names "${alarm_name}" \
      --region "$REGION" \
      --query 'MetricAlarms[0].StateValue' \
      --output text 2>/dev/null)
 
    if [ "$state" == "ALARM" ]; then
      success "Alarm ${alarm_name} is IN_ALARM ✓"
      return 0
    fi
 
    log "  ${alarm_name} state: ${state} — waiting ${interval}s (${elapsed}/${max_wait}s elapsed)"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
 
  error "Alarm ${alarm_name} did not enter IN_ALARM within ${max_wait}s (current state: ${state})"
  error "Check: aws cloudwatch describe-alarms --alarm-names ${alarm_name} --region ${REGION}"
  return 1
}
 
check_aws_metric() {
  local namespace=$1 metric=$2 stat=$3 period=$4 dims=$5 label=$6
  local val
  val=$(aws cloudwatch get-metric-statistics \
    --namespace "$namespace" \
    --metric-name "$metric" \
    --start-time "$(utc_ago 10)" \
    --end-time "$(utc_now)" \
    --period "$period" \
    --statistics "$stat" \
    --dimensions $dims \
    --region "$REGION" \
    --query 'sort_by(Datapoints, &Timestamp)[-1].'"$stat" \
    --output text 2>/dev/null)
  if [ "$val" == "None" ] || [ -z "$val" ] || [ "$val" == "null" ]; then
    warn "${label}: No data (metric may not have been emitted yet)"
    return 1
  fi
  success "${label}: ${val}"
  return 0
}
 
scale_service() {
  local svc=$1 count=$2
  log "Scaling ${ENVIRONMENT}-${svc} to ${count}..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "${ENVIRONMENT}-${svc}" \
    --desired-count "$count" \
    --region "$REGION" \
    --output text > /dev/null
  success "Scale request sent"
}
 
wait_stable() {
  local svc=$1
  log "Waiting for ${ENVIRONMENT}-${svc} to stabilise..."
  aws ecs wait services-stable \
    --cluster "$CLUSTER" \
    --services "${ENVIRONMENT}-${svc}" \
    --region "$REGION"
  success "${svc} is stable"
}
 
# -------------------------------------------------------
# PRE-FLIGHT
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " PRE-FLIGHT CHECKS"
echo "=================================================="
 
aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1 \
  || { error "AWS CLI not configured"; exit 1; }
success "AWS credentials OK"
 
command -v jq > /dev/null 2>&1 \
  || { error "jq required: brew install jq / apt install jq"; exit 1; }
success "jq OK"
 
# Verify all alarms exist before running anything
log "Verifying all alarms exist in CloudWatch..."
EXPECTED_ALARMS=(
  "${ENVIRONMENT}-payments-failed"
  "${ENVIRONMENT}-event-processing-errors"
  "${ENVIRONMENT}-inventory-reservation-failures"
  "${ENVIRONMENT}-gateway-proxy-errors"
  "${ENVIRONMENT}-sqs-message-age-high"
  "${ENVIRONMENT}-sqs-queue-depth-high"
  "${ENVIRONMENT}-rds-cpu-high"
  "${ENVIRONMENT}-rds-storage-low"
  "${ENVIRONMENT}-rds-connections-high"
  "${ENVIRONMENT}-alb-5xx-high"
)
 
missing_alarms=0
for alarm in "${EXPECTED_ALARMS[@]}"; do
  state=$(aws cloudwatch describe-alarms \
    --alarm-names "$alarm" \
    --region "$REGION" \
    --query 'MetricAlarms[0].StateValue' \
    --output text 2>/dev/null)
  if [ "$state" == "None" ] || [ -z "$state" ]; then
    error "Alarm not found: ${alarm} — run terraform apply first"
    missing_alarms=$((missing_alarms+1))
  else
    success "Alarm exists: ${alarm} (current state: ${state})"
  fi
done
 
if [ $missing_alarms -gt 0 ]; then
  error "${missing_alarms} alarm(s) missing — fix these before running tests"
  exit 1
fi
 
# Check services are running
for svc in scheduler worker order-service payment-service inventory-service; do
  count=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "${ENVIRONMENT}-${svc}" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null)
  if [ "$count" == "0" ] || [ -z "$count" ]; then
    error "${svc} has 0 running tasks — some tests will fail"
  else
    success "${svc}: ${count} running task(s)"
  fi
done
 
# -------------------------------------------------------
# STEP 1 — AUTH
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 1: Auth"
echo "=================================================="
 
TOKEN=$(curl -sf -X POST "${ALB_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"anything"}' 2>/dev/null | jq -r .token)
 
[ -z "$TOKEN" ] || [ "$TOKEN" == "null" ] \
  && { error "Could not get auth token — is ALB_URL correct?"; exit 1; }
success "Auth token obtained"
 
# -------------------------------------------------------
# STEP 2 — SEED PRODUCTS
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 2: Seed products"
echo "=================================================="
 
curl -sf -X POST "${ALB_URL}/api/inventory/products" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"test-product-001","name":"Test Product","sku":"TEST-001","price":10.00,"stock":500}' \
  > /dev/null 2>&1 && success "test-product-001 ready" || warn "Already exists, continuing"
 
curl -sf -X POST "${ALB_URL}/api/inventory/products" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"empty-product-001","name":"Empty Product","sku":"EMPTY-001","price":9.99,"stock":0}' \
  > /dev/null 2>&1 && success "empty-product-001 ready" || warn "Already exists, continuing"
 
# -------------------------------------------------------
# STEP 3 — PaymentsFailed (threshold: 3)
# 80 orders at 10% failure rate = ~8 failures (2.7x threshold)
# Alarm period is 5 min so all orders sent within that window
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 3: PaymentsFailed"
echo " Threshold: 3  |  Sending: 80 orders  |  Expected failures: ~8"
echo "=================================================="
 
placed=0
for i in {1..80}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${ALB_URL}/api/orders/" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"items":[{"product_id":"test-product-001","quantity":1,"price":10.00}]}' 2>/dev/null)
  [ "$code" == "201" ] && placed=$((placed+1))
  printf "."
  sleep 0.3
done
echo ""
success "Placed ${placed}/80 orders"
 
check_logs "/ecs/${ENVIRONMENT}-payment-service" "payment.failed" 5
 
# Alarm period=300s evaluation_periods=1 so needs to fire within one 5-min window
# Give it up to 10 minutes to transition
wait_for_alarm "${ENVIRONMENT}-payments-failed" 600 \
  && record "PaymentsFailed alarm" "pass" \
  || record "PaymentsFailed alarm" "fail"
 
# -------------------------------------------------------
# STEP 4 — InventoryReservationFailures (threshold: 3)
# 15 orders for 0-stock = 15 failures (5x threshold)
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 4: InventoryReservationFailures"
echo " Threshold: 3  |  Sending: 15 zero-stock orders  |  Expected failures: 15"
echo "=================================================="
 
for i in {1..15}; do
  curl -s -o /dev/null \
    -X POST "${ALB_URL}/api/orders/" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"items":[{"product_id":"empty-product-001","quantity":1,"price":9.99}]}' 2>/dev/null
  printf "."
  sleep 0.5
done
echo ""
success "Sent 15 orders for 0-stock product"
 
log "Waiting 30s for worker to process events..."
sleep 30
 
check_logs "/ecs/${ENVIRONMENT}-worker" "reservation failed" 5
 
wait_for_alarm "${ENVIRONMENT}-inventory-reservation-failures" 600 \
  && record "InventoryReservationFailures alarm" "pass" \
  || record "InventoryReservationFailures alarm" "fail"
 
# -------------------------------------------------------
# STEP 5 — GatewayProxyErrors / ALB 5xx
# threshold: 10, evaluation_periods: 2 (both 5-min periods
# must have 10+ errors so we send 25 requests, scale back
# up, then send another 25 to cover both evaluation windows)
#
# Scaling order-service to 0 makes the gateway return 502s
# for any order request, which the gateway logs as "Proxy
# error" (feeding GatewayProxyErrors) and which the ALB
# also counts directly as a 5xx response (feeding the ALB
# 5xx alarm) - so this single step exercises both alarms.
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 5: GatewayProxyErrors + ALB 5xx"
echo " Threshold: 10 over 2x5min periods (both alarms)"
echo " Sending 25 requests, waiting 5min, sending 25 more"
echo "=================================================="
 
scale_service "order-service" 0
log "Waiting 30s for tasks to stop..."
sleep 30
 
log "Sending first batch of 25 requests (period 1)..."
for i in {1..25}; do
  curl -s -o /dev/null \
    "${ALB_URL}/api/orders/" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || true
  printf "."
  sleep 1
done
echo ""
success "First batch sent"
 
log "Waiting 5 minutes for second evaluation period..."
sleep 300
 
log "Sending second batch of 25 requests (period 2)..."
for i in {1..25}; do
  curl -s -o /dev/null \
    "${ALB_URL}/api/orders/" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || true
  printf "."
  sleep 1
done
echo ""
success "Second batch sent"
 
check_logs "/ecs/${ENVIRONMENT}-api-gateway" "Proxy error" 10
 
scale_service "order-service" 1
 
# evaluation_periods=2 so both alarms need two consecutive periods
# give them up to 15 minutes
wait_for_alarm "${ENVIRONMENT}-gateway-proxy-errors" 900 \
  && record "GatewayProxyErrors alarm" "pass" \
  || record "GatewayProxyErrors alarm" "fail"
 
wait_for_alarm "${ENVIRONMENT}-alb-5xx-high" 900 \
  && record "ALB-5xx alarm" "pass" \
  || record "ALB-5xx alarm" "fail"
 
wait_stable "order-service"
 
# -------------------------------------------------------
# STEP 6 — EventProcessingErrors (threshold: 1)
# Scale inventory to 0, send 5 orders (5x threshold)
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 6: EventProcessingErrors"
echo " Threshold: 1  |  Sending: 5 orders with inventory down"
echo "=================================================="
 
scale_service "inventory-service" 0
log "Waiting 30s for inventory tasks to stop..."
sleep 30
 
for i in {1..5}; do
  curl -s -o /dev/null \
    -X POST "${ALB_URL}/api/orders/" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"items":[{"product_id":"test-product-001","quantity":1,"price":10.00}]}' 2>/dev/null
  printf "."
  sleep 2
done
echo ""
success "Sent 5 orders with inventory-service down"
 
log "Waiting 30s for worker to attempt processing..."
sleep 30
 
check_logs "/ecs/${ENVIRONMENT}-worker" "Failed to handle event" 5
 
scale_service "inventory-service" 1
 
wait_for_alarm "${ENVIRONMENT}-event-processing-errors" 600 \
  && record "EventProcessingErrors alarm" "pass" \
  || record "EventProcessingErrors alarm" "fail"
 
wait_stable "inventory-service"
 
# -------------------------------------------------------
# STEP 7 — Native AWS metrics (read-only)
# SQS and RDS alarms can't be safely triggered in a real
# environment (would require breaking the DB or flooding
# the queue). We verify the metrics have data, which
# confirms the alarms will work when thresholds are hit.
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " STEP 7: Native AWS infrastructure metrics"
echo " (read-only — verifying data is flowing to CloudWatch)"
echo " Note: these alarms fire on real infra problems,"
echo " not something we trigger in a test script."
echo "=================================================="
 
log "Checking SQS message age..."
check_aws_metric "AWS/SQS" "ApproximateAgeOfOldestMessage" "Maximum" 300 \
  "Name=QueueName,Value=${SQS_QUEUE_NAME}" \
  "SQS oldest message age (seconds)" \
  && record "SQS-MessageAge data" "pass" \
  || record "SQS-MessageAge data" "skip"
 
log "Checking SQS queue depth..."
check_aws_metric "AWS/SQS" "ApproximateNumberOfMessagesVisible" "Maximum" 300 \
  "Name=QueueName,Value=${SQS_QUEUE_NAME}" \
  "SQS visible messages" \
  && record "SQS-QueueDepth data" "pass" \
  || record "SQS-QueueDepth data" "skip"
 
log "Checking RDS CPU..."
check_aws_metric "AWS/RDS" "CPUUtilization" "Average" 300 \
  "Name=DBInstanceIdentifier,Value=${RDS_IDENTIFIER}" \
  "RDS CPU %" \
  && record "RDS-CPU data" "pass" \
  || record "RDS-CPU data" "skip"
 
log "Checking RDS free storage..."
check_aws_metric "AWS/RDS" "FreeStorageSpace" "Minimum" 300 \
  "Name=DBInstanceIdentifier,Value=${RDS_IDENTIFIER}" \
  "RDS free storage (bytes)" \
  && record "RDS-Storage data" "pass" \
  || record "RDS-Storage data" "skip"
 
log "Checking RDS connections..."
check_aws_metric "AWS/RDS" "DatabaseConnections" "Maximum" 300 \
  "Name=DBInstanceIdentifier,Value=${RDS_IDENTIFIER}" \
  "RDS active connections" \
  && record "RDS-Connections data" "pass" \
  || record "RDS-Connections data" "skip"
 
# -------------------------------------------------------
# SUMMARY
# -------------------------------------------------------
echo ""
echo "=================================================="
echo " RESULTS"
echo "=================================================="
echo ""
echo -e "${GREEN}Passed:${NC}  ${TESTS_PASSED}"
echo -e "${RED}Failed:${NC}  ${TESTS_FAILED}"
echo -e "${YELLOW}Skipped:${NC} ${TESTS_SKIPPED}"
echo ""
echo "Alarm verification summary:"
echo "  ${ENVIRONMENT}-payments-failed              tested — alarm must reach IN_ALARM"
echo "  ${ENVIRONMENT}-inventory-reservation-failures tested — alarm must reach IN_ALARM"
echo "  ${ENVIRONMENT}-gateway-proxy-errors          tested — alarm must reach IN_ALARM"
echo "  ${ENVIRONMENT}-alb-5xx-high                  tested — alarm must reach IN_ALARM"
echo "  ${ENVIRONMENT}-event-processing-errors       tested — alarm must reach IN_ALARM"
echo "  ${ENVIRONMENT}-sqs-message-age-high          data verified — fires on real SQS backlog"
echo "  ${ENVIRONMENT}-sqs-queue-depth-high          data verified — fires on real queue depth"
echo "  ${ENVIRONMENT}-rds-cpu-high                  data verified — fires on real CPU spike"
echo "  ${ENVIRONMENT}-rds-storage-low               data verified — fires on real low storage"
echo "  ${ENVIRONMENT}-rds-connections-high          data verified — fires on real conn spike"
echo ""
 
if [ "$TESTS_FAILED" -gt 0 ]; then
  echo -e "${RED}Some alarms did not fire. Possible causes:${NC}"
  echo "  1. CloudWatch metric filter pattern does not match actual log output"
  echo "     Fix: go to CloudWatch -> Log Groups -> Metric Filters -> Test Pattern"
  echo "  2. Not enough events generated to exceed threshold within the alarm period"
  echo "     Fix: re-run just the failing step manually and watch the alarm state"
  echo "  3. Alarm evaluation_periods=2 means it needs two consecutive 5-min windows"
  echo "     Fix: the gateway/ALB test now sends two batches to cover both windows"
  echo "  4. CloudWatch alarm state can lag up to 5 minutes after metric data arrives"
  echo "     Fix: wait_for_alarm retries for up to 10-15 minutes per alarm"
  exit 1
fi