#!/usr/bin/env bash
# 在本機快速驗證三種 CI 失敗情境（不修改檔案，僅暫存後還原）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

run_typecheck_demo() {
  cp src/app.ts /tmp/ci-demo-app.ts.bak
  echo "const _ciDemoTypeError: number = 'broken';" >> src/app.ts
  echo "=== TypeScript typecheck (預期失敗) ==="
  npm run typecheck || true
  cp /tmp/ci-demo-app.ts.bak src/app.ts
}

run_prettier_demo() {
  cp src/app.ts /tmp/ci-demo-app.ts.bak
  sed -i '' 's/buildApp(options/buildApp( options/' src/app.ts
  echo "=== Prettier check (預期失敗) ==="
  npm run format:check || true
  cp /tmp/ci-demo-app.ts.bak src/app.ts
}

run_test_demo() {
  cp test/app.test.ts /tmp/ci-demo-test.ts.bak
  sed -i '' 's/expect(response.statusCode).toBe(200)/expect(response.statusCode).toBe(500)/' test/app.test.ts
  echo "=== Vitest (預期失敗) ==="
  npm test || true
  cp /tmp/ci-demo-test.ts.bak test/app.test.ts
}

case "${1:-all}" in
  typecheck) run_typecheck_demo ;;
  prettier) run_prettier_demo ;;
  test) run_test_demo ;;
  all)
    run_typecheck_demo
    echo
    run_prettier_demo
    echo
    run_test_demo
    ;;
  *)
    echo "用法: $0 [typecheck|prettier|test|all]"
    exit 1
    ;;
esac

echo
echo "本機示範完成，原始檔案已還原。"
