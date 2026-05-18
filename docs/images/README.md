# CI 失敗截圖

請將 GitHub Actions **failed** 的截圖放在此資料夾，檔名建議：

| 檔名                    | 內容                                   |
| ----------------------- | -------------------------------------- |
| `ci-fail-typecheck.png` | TypeScript typecheck 步驟失敗          |
| `ci-fail-prettier.png`  | Prettier check 步驟失敗                |
| `ci-fail-test.png`      | Run tests 步驟失敗（可含 Vitest 報告） |

截圖建議包含：workflow run 列表的紅色 ❌、job 名稱、失敗的 step 名稱、以及 log 最後幾行錯誤訊息。
