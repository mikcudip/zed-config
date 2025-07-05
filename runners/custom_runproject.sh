#!/bin/bash

# Parse key=value arguments passed from Zed
for arg in "$@"
do
  case $arg in
    fileName=*)
      fileName="${arg#*=}"
      ;;
    fileNameWithoutExt=*)
      fileNameWithoutExt="${arg#*=}"
      ;;
    dirName=*)
      dirName="${arg#*=}"
      ;;
  esac
done

# Basic sanity check for required variables
if [ -z "$fileName" ] || [ -z "$fileNameWithoutExt" ] || [ -z "$dirName" ]; then
  echo "❌ Error: Missing required variables. Make sure to pass fileName, fileNameWithoutExt, and dirName."
  exit 1
fi

# Change to the directory where the file is located
cd "$dirName" || exit 1

# Extract file extension
extension="${fileName##*.}"

# Choose the right command based on the file extension
case "$extension" in
  js) node "$fileName" ;;
  ts) ts-node "$fileName" ;;
  py) python -u "$fileName" ;;
  java)
    # Construct workspace root by going up from current directory
    workspaceRoot=$(pwd)
    while [[ "$workspaceRoot" != "/" && ! -d "$workspaceRoot/.git" && ! -f "$workspaceRoot/pom.xml" && ! -f "$workspaceRoot/build.gradle" ]]; do
      workspaceRoot=$(dirname "$workspaceRoot")
    done

    # If we couldn't find a project root, use current directory
    if [[ "$workspaceRoot" == "/" ]]; then
      workspaceRoot=$(pwd)
    fi

    bash ~/.config/zed/runners/java.sh \
      "file=$dirName/$fileName" \
      "relativeFile=${dirName#$workspaceRoot/}/$fileName" \
      "stem=$fileNameWithoutExt" \
      "workspaceRoot=$workspaceRoot"
    ;;
  cpp) g++ "$fileName" -o "$fileNameWithoutExt" && "./$fileNameWithoutExt" ;;
  c) gcc "$fileName" -o "$fileNameWithoutExt" && "./$fileNameWithoutExt" ;;
  go) go run "$fileName" ;;
  rs) rustc "$fileName" && "./$fileNameWithoutExt" ;;
  php) php "$fileName" ;;
  rb) ruby "$fileName" ;;
  lua) lua "$fileName" ;;
  sh) bash "$fileName" ;;
  swift) swift "$fileName" ;;
  scala) scala "$fileName" ;;
  dart) dart "$fileName" ;;
  hs) runghc "$fileName" ;;
  *)
    echo "❌ Error: Unsupported file extension: $extension"
    exit 1
    ;;
esac
