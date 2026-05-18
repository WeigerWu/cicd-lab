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

1. 推送含 `.github/workflows/ci_weigerwu.yaml` 的分支至 GitHub。
2. 開啟 repo **Actions** 分頁，確認 workflow 因 `push` 自動觸發。
3. 檢查 job 內是否依序出現 typecheck、Prettier、test 步驟且皆成功。
4. 在 run 頁面查看 **Vitest** 測試報告（test-reporter 產生的 check / summary）。
5. （可選）故意引入型別錯誤、格式問題或失敗測試，確認 workflow 顯示 **failed**。

## 本機模擬

若已安裝 [act](https://github.com/nektos/act)：

```bash
act push -W .github/workflows/ci_weigerwu.yaml
```

注意：test-reporter 在本機 act 環境可能無法完整模擬 GitHub Checks API，建議以實際 push 至 GitHub 驗證測試結果 UI。
