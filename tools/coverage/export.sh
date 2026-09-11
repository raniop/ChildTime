#!/bin/zsh
# Refresh docs/admin/question-coverage.json from the question banks in the app.
#   tools/coverage/export.sh
# Runs automatically from .githooks/pre-commit whenever a bank file is committed.
set -e
ROOT=${0:A:h:h:h}
M=$ROOT/ChildTime/Models
TMP=$(mktemp -d)
trap 'rm -rf $TMP' EXIT

# Only the pieces of these two files the banks need — the rest pulls in the
# whole app (profiles, StoreKit, cloud sync).
awk '/^\/\/\/ 🌍 World passes/{exit} {print}' $M/QuestionPack.swift > $TMP/QuestionPack.swift
awk '/^enum WorldSuitability/{f=1} f{print} f&&/^}/{exit}' $M/ConversionConfig.swift > $TMP/WorldSuitability.swift

xcrun swiftc -Onone -parse-as-library -o $TMP/coverage \
  $M/QuestionBanks*.swift $M/QuestionDifficultyTags*.swift $M/ReadingContent.swift \
  $M/Topic.swift $M/Question.swift $M/RemoteQuestionBank.swift $ROOT/Shared/AppGroup.swift \
  $ROOT/Shared/Localization/AppLanguage.swift \
  $ROOT/ChildTime/DesignSystem/Colors.swift \
  $TMP/QuestionPack.swift $TMP/WorldSuitability.swift \
  $ROOT/tools/coverage/export.swift

$TMP/coverage $ROOT/docs/admin/question-coverage.json
