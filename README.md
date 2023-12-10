# はじめに

[Inspector のコンテナイメージスキャンを CodeBuild で実行してみた](https://dev.classmethod.jp/articles/inspector-cicd-codebuild/)のサンプルコードになります。

# デプロイ手順

## 前提

- terraform がインストールされていること

## AWS インフラの作成

`inspector-cicd-codebuild` フォルダ配下で以下コマンドを実行する

1. `terraform init` で フォルダの初期化を行う
2. `terraform plan` で 作成されるリソースの確認
3. `terraform apply` で 作成されるリソースの最終確認および作成

## コードの配置

`inspector` フォルダ配下で以下コマンドを実行する

1. 作成した CodeCommit レポジトリに `git clone` を行う

```bash
cd ..
git clone ssh://git-codecommit.ap-northeast-1.amazonaws.com/v1/repos/inspector-scan-repo
cp -R inspector-cicd-codebuild/codebuild inspector-scan-repo
cd inspector-scan-repo
git add . && git commit -m '[add] code asset added' && git push
```

適宜、Dockerfile を変えてみて挙動をお楽しみください。
