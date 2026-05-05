# C Language Rules

このディレクトリは、C 言語専用の外部規約を Markdown 化したファイルの格納先です。

## 置き場所

- C 言語専用の規約は .github/rules/c-language/ に置く
- Copilot 向けの instructions は .github/instructions/ に置き、規約本文はここへ分離する
- 人間向け README や開発手順と混在させず、エージェントが探しやすい場所に集約する

## 推奨ファイル名

- 01-overview.md
- 02-naming.md
- 03-formatting.md
- 04-types.md
- 05-functions.md
- 06-macros.md
- 07-memory-and-pointers.md
- 08-embedded-specific.md
- 09-review-checklist.md

連番は参照順と優先順位を兼ねます。既存資料の章構成に合わせて調整して構いません。

## Copilot からの参照方針

- 共通ルールは .github/copilot-instructions.md で定義する
- C 言語の編集時は .github/instructions/c.instructions.md を適用する
- 組み込み文脈では .github/instructions/embedded-c.instructions.md を追加で適用する
- 詳細な規約判断が必要なときは、このディレクトリの関連 Markdown を読む

## 運用メモ

- 規約本文を instructions 側へ重複記載しない
- PDF 由来の Markdown は見出し、用語、表記ゆれを最低限整える
- 優先順位や適用範囲が曖昧なら 01-overview.md に明記する