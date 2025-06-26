#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

function check_dependency {
  if ! command -v $1 &> /dev/null
  then
    echo -e "${RED}❌ $1 не установлен. Установи через: ${NC}$2"
    exit 1
  fi
}

echo -e "${GREEN}🔍 Проверка зависимостей...${NC}"
check_dependency xcodegen "brew install xcodegen"
check_dependency pod "sudo gem install cocoapods"
check_dependency swiftgen "brew install swiftgen"

echo -e "${GREEN}🚧 Генерация проекта (xcodegen)...${NC}"
xcodegen

#echo -e "${GREEN}📦 Установка зависимостей (pod install)...${NC}"
#pod install

echo -e "${GREEN}✨ Генерация ресурсов (swiftgen)...${NC}"
swiftgen config run --config swiftgen.yml

workspace=$(find . -maxdepth 1 -name "*.xcworkspace" | head -n 1)

if [[ -n "$workspace" ]]; then
  echo -e "${GREEN}🚀 Открытие Xcode workspace: $workspace${NC}"
  open "$workspace"
else
  echo -e "${RED}❗️ .xcworkspace не найден. Убедись, что CocoaPods создал его.${NC}"
fi

echo -e "${GREEN}✅ Всё готово!${NC}"
