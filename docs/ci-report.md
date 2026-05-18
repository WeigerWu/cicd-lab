# CI Pipeline 實作報告

## 概述

本專案於 `.github/workflows/ci_b12705032.yaml` 建立 GitHub Actions CI pipeline，在每次 `push` 時自動執行 TypeScript 型別檢查、Prettier 格式檢查與單元測試，並將測試結果顯示於 GitHub Actions 執行頁面。

## 1. 自動執行（20%）

### 實作方式

在 workflow 頂層設定觸發條件：

```yaml
on:
  push:
```

任何分支的 `push` 事件都會啟動此 workflow，無需手動觸發。

### 策略說明

- 僅使用 `push` 觸發，符合作業要求。
- 未額外限制 `branches`，確保 feature branch 與 main 推送皆會跑 CI。

## 2. Pipeline 內容（20%）

### 實作方式

於單一 `ci` job 中依序執行三項檢查，皆使用 `package.json` 既有 script：

| 檢查項目             | 指令                            | 說明                                      |
| -------------------- | ------------------------------- | ----------------------------------------- |
| TypeScript typecheck | `npm run typecheck`             | 執行 `tsc --noEmit`，僅檢查型別不產出檔案 |
| Prettier check       | `npm run format:check`          | 執行 `prettier --check .`，驗證格式       |
| Test                 | `npm test`（含 JUnit reporter） | 使用 Vitest 執行 `test/` 內測試           |

環境準備步驟：

- `actions/checkout@v5`：取得程式碼
- `actions/setup-node@v5`：安裝 Node.js 22，並啟用 npm cache
- `npm ci`：依 lock 檔安裝依賴，確保可重現建置

### 策略說明

- 採用專案已定義的 npm scripts，與本機開發指令一致，降低 CI 與本地行為差異。
- 檢查順序為 typecheck → Prettier → test，先排除編譯與格式問題再跑測試，縮短失敗時的除錯路徑。

## 3. 失敗處理（20%）

### 實作方式

GitHub Actions 預設行為：任一 step 以非零 exit code 結束時，該 job 標記為 **failed**，整個 workflow run 亦為 **failed**。

本 pipeline 未對 typecheck、Prettier 或 test 設定 `continue-on-error: true`，因此：

- 型別錯誤 → workflow failed
- 格式不符 → workflow failed
- 測試失敗 → workflow failed

`dorny/test-reporter` 設定 `fail-on-error: true`，若 JUnit 報告解析失敗也會使 job 失敗。

### 策略說明

- 依賴平台原生失敗語意，不額外包裝，行為直觀且符合「任一檢查失敗則整體失敗」要求。

## 4. 測試結果可視化（20%）

### 實作方式

1. **產生 JUnit XML**  
   Vitest 執行時同時啟用 `default` 與 `junit` reporter：

   ```bash
   npm test -- --reporter=default --reporter=junit --outputFile.junit=reports/vitest-junit.xml
   ```

   - `default`：在 Actions log 中保留可讀的測試輸出
   - `junit`：產生 `reports/vitest-junit.xml` 供後續解析

2. **發布至 GitHub Checks**  
   使用 Marketplace action [`dorny/test-reporter@v2`](https://github.com/marketplace/actions/test-reporter)：

   ```yaml
   - name: Publish test report
     uses: dorny/test-reporter@v2
     if: ${{ !cancelled() }}
     with:
       name: Vitest
       path: reports/vitest-junit.xml
       reporter: java-junit
       fail-on-error: true
   ```

3. **權限**  
   workflow 設定 `permissions.checks: write`，讓 test-reporter 能在 Actions 摘要與 Checks 區塊顯示各測試案例通過/失敗狀態。

### 策略說明

- 參考課程 lab `snippets/02_run-test.yaml` 的 JUnit 輸出方式，並加上 test-reporter 滿足「結果直接顯示在 GitHub Actions 頁面」的需求。
- `reports/` 已列入 `.gitignore`，報告僅在 CI 執行期間產生，不進版控。

## 5. 工具與版本摘要

| 工具 / Action               | 用途                             |
| --------------------------- | -------------------------------- |
| Node.js 22                  | 與 `package.json` `engines` 一致 |
| TypeScript (`tsc --noEmit`) | 靜態型別檢查                     |
| Prettier 3                  | 程式碼格式檢查                   |
| Vitest 4                    | 單元測試與 JUnit 報告            |
| actions/checkout@v5         | 拉取原始碼                       |
| actions/setup-node@v5       | Node 環境與 npm cache            |
| dorny/test-reporter@v2      | 將 JUnit 結果呈現於 GitHub UI    |

## 驗證方式

1. 推送含 `.github/workflows/ci_b12705032.yaml` 的分支至 GitHub。
2. 開啟 repo **Actions** 分頁，確認 workflow 因 `push` 自動觸發。
3. 檢查 job 內是否依序出現 typecheck、Prettier、test 步驟且皆成功。
4. 在 run 頁面查看 **Vitest** 測試報告（test-reporter 產生的 check / summary）。
5. 依下方「失敗情境驗證」分三次 push 失敗版本並截圖，再還原為成功版本。

## 6. 失敗情境驗證

以下三種情境用於驗證「任一檢查失敗 → pipeline 整體 **failed**」。建議**分三次 commit / push**（每次只引入一種錯誤），到 GitHub **Actions** 截圖後再修正。

截圖請存於 `docs/images/`（見該目錄 README），並在下方對應小節引用。

本機可先執行（不會留下修改）：

```bash
chmod +x scripts/ci-failure-demo.sh
./scripts/ci-failure-demo.sh all
```

---

### 6.1 TypeScript 型別錯誤

#### 如何製造錯誤

在 `src/app.ts` 檔案**最後一行**加入：

```typescript
const _ciDemoTypeError: number = 'broken';
```

變數宣告為 `number`，卻賦值字串 `'broken'`，TypeScript 編譯器會報 **TS2322**。

#### Pipeline 表現

| 項目          | 內容                                             |
| ------------- | ------------------------------------------------ |
| 失敗步驟      | **TypeScript typecheck**                         |
| 後續步驟      | Prettier、Run tests **不會執行**（前一步已失敗） |
| Workflow 狀態 | ❌ **Failure**                                   |

#### 錯誤 log（節錄）

```text
> my-app@1.0.0 typecheck
> tsc --noEmit

src/app.ts(24,7): error TS2322: Type 'string' is not assignable to type 'number'.
```

#### 錯誤原因

靜態型別檢查發現型別不一致：無法將 `string` 指派給 `number` 型別變數。

#### 修正方式

1. **刪除**上述示範用那一行，或改為合法型別，例如：`const _ciDemoTypeError: number = 0;`
2. 本機確認：`npm run typecheck` 應成功（exit code 0）
3. `git add` → `commit` → `push`，Actions 應恢復綠色 ✓

#### 截圖

![TypeScript typecheck 失敗](../images/ci-fail-typecheck.png)

> 若尚未截圖：Actions → 失敗的 run → 點 **ci** job → 展開 **TypeScript typecheck** → 截圖含紅色 ❌ 與 TS2322 訊息。

---

### 6.2 Prettier 格式錯誤

#### 如何製造錯誤

修改 `src/app.ts` 函式宣告，故意加入多餘空格（與專案 `.prettierrc` 不符），例如將：

```typescript
export function buildApp(options: FastifyServerOptions = {}) {
```

改為：

```typescript
export function buildApp( options: FastifyServerOptions = {} ) {
```

#### Pipeline 表現

| 項目          | 內容                          |
| ------------- | ----------------------------- |
| 失敗步驟      | **Prettier check**            |
| 前置步驟      | TypeScript typecheck 已通過 ✓ |
| 後續步驟      | Run tests **不會執行**        |
| Workflow 狀態 | ❌ **Failure**                |

#### 錯誤 log（節錄）

```text
> my-app@1.0.0 format:check
> prettier --check .

Checking formatting...
[warn] src/app.ts
[warn] Code style issues found in the above file. Run Prettier with --write to fix.
```

#### 錯誤原因

`prettier --check` 比對目前檔案與專案格式規則，發現 `src/app.ts` 未符合格式（多餘空格等）。

#### 修正方式

1. 執行 `npm run format`（等同 `prettier --write .`）自動修正，或手動改回標準格式
2. 確認：`npm run format:check` 通過
3. `commit` → `push`

#### 截圖

![Prettier check 失敗](../images/ci-fail-prettier.png)

> 截圖應顯示 **Prettier check** 步驟失敗，以及 `Code style issues found` 訊息。

---

### 6.3 測試失敗

#### 如何製造錯誤

在 `test/app.test.ts` 將預期狀態碼從 `200` 改為 `500`（與 API 實際回傳不符），例如：

```diff
-    expect(response.statusCode).toBe(200);
+    expect(response.statusCode).toBe(500);
```

兩個 `it(...)` 區塊各改一處即可。

#### Pipeline 表現

| 項目          | 內容                                                                   |
| ------------- | ---------------------------------------------------------------------- |
| 失敗步驟      | **Run tests**                                                          |
| 前置步驟      | typecheck、Prettier 已通過 ✓                                           |
| Workflow 狀態 | ❌ **Failure**                                                         |
| 測試報告      | 若 JUnit 已產生，Summary 可能顯示 **Vitest** 失敗案例（test-reporter） |

#### 錯誤 log（節錄）

```text
 FAIL  test/app.test.ts > Fastify app > GET /health returns ok status
AssertionError: expected 200 to be 500 // Object.is equality

- Expected
+ Received

- 500
+ 200
```

#### 錯誤原因

`/health` 與 `/` 實際回傳 HTTP 200，測試卻斷言為 500，Vitest 斷言失敗，程序以 exit code 1 結束。

#### 修正方式

1. 將 `toBe(500)` 改回 `toBe(200)`
2. 確認：`npm test` 全部通過
3. `commit` → `push`；Actions 應成功，且 Summary 顯示 Vitest 通過

#### 截圖

![Run tests 失敗](../images/ci-fail-test.png)

> 建議截圖含 **Run tests** 失敗 log，若 Summary 有 Vitest 失敗報告一併截取。

---

### 6.4 在 GitHub 重現失敗的建議流程

每次只測一種錯誤，避免混淆：

```bash
# 範例：型別錯誤分支
git checkout -b demo/fail-typecheck
# 編輯 src/app.ts 加入示範錯誤
git add src/app.ts
git commit -m "demo: introduce typecheck failure"
git push -u origin demo/fail-typecheck
# → 到 Actions 截圖 → 修正 → commit → push

# 還原後可合併回主分支，或刪除 demo 分支
```

| 分支建議名稱          | 引入錯誤     |
| --------------------- | ------------ |
| `demo/fail-typecheck` | 6.1 型別錯誤 |
| `demo/fail-prettier`  | 6.2 格式錯誤 |
| `demo/fail-test`      | 6.3 測試失敗 |

三種情境都驗證並截圖後，請確保 **main / 繳交分支** 上的程式碼為**正確可通過 CI** 的版本。

## 本機模擬

若已安裝 [act](https://github.com/nektos/act)：

```bash
act push -W .github/workflows/ci_b12705032.yaml
```

注意：test-reporter 在本機 act 環境可能無法完整模擬 GitHub Checks API，建議以實際 push 至 GitHub 驗證測試結果 UI。
