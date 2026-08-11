#!/usr/bin/env bash
# Seed demo Supabase Auth accounts (email/password 123456) + set roles on app_users.
# Run AFTER `supabase start` (or `supabase db reset`).
# Signups via curl; roles set via psql (docker) by email — no jq needed.
# Usage: ./scripts/seed_auth.sh

set -uo pipefail

API_URL="${1:-http://127.0.0.1:54333}"
ANON_KEY="$(supabase status -o env 2>/dev/null | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
DB_CONTAINER="${SUPABASE_DB_CONTAINER:-supabase_db_Coffe_app}"

if [[ -z "$ANON_KEY" ]]; then
  echo "Error: cannot read anon key. Is 'supabase start' running?" >&2
  exit 1
fi

# name email role
ACCOUNTS=(
  "Nguyễn Hữu Thanh|admin@smartcafe.com|admin"
  "Trần Thị Thu Ngân|cashier@smartcafe.com|cashier"
  "Lê Pha Chế|barista@smartcafe.com|barista"
  "Phạm Phục Vụ|waiter@smartcafe.com|waiter"
  "Khách Vãng Lai|customer@smartcafe.com|customer"
)

echo "Seeding auth accounts..."
for entry in "${ACCOUNTS[@]}"; do
  IFS='|' read -r name email role <<< "$entry"
  resp=$(curl -s -o /tmp/signup.out -w "%{http_code}" -X POST "$API_URL/auth/v1/signup" \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"123456\",\"data\":{\"full_name\":\"$name\"}}")
  if [[ "$resp" == "200" ]]; then
    echo "  $email: created"
  else
    echo "  $email: exists or failed (HTTP $resp)"
  fi
done

echo "Setting roles on app_users..."
for entry in "${ACCOUNTS[@]}"; do
  IFS='|' read -r name email role <<< "$entry"
  docker exec "$DB_CONTAINER" psql -U postgres -d postgres \
    -tAc "update public.app_users set role = '$role' where email = '$email'" >/dev/null 2>&1
  echo "  $email -> $role"
done

echo "Done. Logins: <role>@smartcafe.com / 123456"
