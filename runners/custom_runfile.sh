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

echo "=== Execution ==="

# Choose the right command based on the file extension
case "$extension" in
  js) node "$fileName" ;;
  ts) ts-node "$fileName" ;;
  py) python -u "$fileName" ;;
  java) javac "$fileName" && java "$fileNameWithoutExt" ;;
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
  julia) julia "$fileName" ;;
  cs) scriptcs "$fileName" ;;
  r) Rscript "$fileName" ;;
  nim) nim compile --verbosity:0 --hints:off --run "$fileName" ;;
  v) v run "$fileName" ;;
  *)
    echo "❌ Unsupported file extension: .$extension. Add support for it if needed. 💾"
    ;;
esac
