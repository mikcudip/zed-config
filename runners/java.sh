#!/bin/bash

# Enhanced Java Runner Script for Zed Editor
# Optimized for Zed environment variables
# Based on NetBeans internal patterns

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [file=PATH] [relativeFile=REL] [stem=NAME] [workspaceRoot=ROOT]

Zed Integration:
  file=PATH              Absolute file path (\$ZED_FILE)
  relativeFile=REL       Relative file path (\$ZED_RELATIVE_FILE)
  stem=NAME              File stem (\$ZED_STEM)
  workspaceRoot=ROOT     Workspace root (\$ZED_WORKTREE_ROOT)

Options:
  -c, --compile-only     Compile only, don't execute
  -r, --run-only        Execute only (assumes compiled)
  -lib, --library DIR   Library directory (auto-detects JARs)
  -args "ARGS"          Program arguments
  -jvm "OPTS"           JVM options
  -debug                Enable debug mode
  -verbose              Verbose output
  -h, --help            Show this help

Examples:
  # Direct usage
  $0 src/main/App.java

  # Zed integration
  $0 file=/path/to/Main.java relativeFile=src/main/Main.java stem=Main workspaceRoot=/path/to/project
EOF
}

# Default values
COMPILE_ONLY=false
RUN_ONLY=false
LIB_DIR=""
PROGRAM_ARGS=""
JVM_OPTS=""
DEBUG_MODE=false
VERBOSE=false

# Zed variables
ZED_FILE=""
ZED_RELATIVE_FILE=""
ZED_STEM=""
ZED_WORKTREE_ROOT=""
JAVA_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        file=*) ZED_FILE="${1#*=}"; shift ;;
        relativeFile=*) ZED_RELATIVE_FILE="${1#*=}"; shift ;;
        stem=*) ZED_STEM="${1#*=}"; shift ;;
        workspaceRoot=*) ZED_WORKTREE_ROOT="${1#*=}"; shift ;;
        -c|--compile-only) COMPILE_ONLY=true; shift ;;
        -r|--run-only) RUN_ONLY=true; shift ;;
        -lib|--library) LIB_DIR="$2"; shift 2 ;;
        -args) PROGRAM_ARGS="$2"; shift 2 ;;
        -jvm) JVM_OPTS="$2"; shift 2 ;;
        -debug) DEBUG_MODE=true; shift ;;
        -verbose) VERBOSE=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        -*) echo "Unknown option: $1"; show_help; exit 1 ;;
        *) JAVA_FILE="$1"; shift ;;
    esac
done

# Determine Java file and workspace context
determine_context() {
    if [[ -n "$ZED_FILE" ]]; then
        # Using Zed variables - preferred method
        JAVA_FILE="$ZED_FILE"
        FILE_NAME="$ZED_STEM"
        WORKSPACE_ROOT="$ZED_WORKTREE_ROOT"

        # Extract directory from absolute path
        FILE_DIR=$(dirname "$JAVA_FILE")

        [[ "$VERBOSE" == true ]] && echo "Using Zed context: $ZED_RELATIVE_FILE in workspace $WORKSPACE_ROOT"
    elif [[ -n "$JAVA_FILE" ]]; then
        # Direct file specification
        JAVA_FILE=$(realpath "$JAVA_FILE")
        FILE_DIR=$(dirname "$JAVA_FILE")
        FILE_NAME=$(basename "$JAVA_FILE" .java)
        WORKSPACE_ROOT=$(pwd)

        [[ "$VERBOSE" == true ]] && echo "Using direct file: $JAVA_FILE"
    else
        echo "Error: No Java file specified"
        show_help
        exit 1
    fi
}

# Validation functions
check_java_installation() {
    if ! command -v java &> /dev/null || ! command -v javac &> /dev/null; then
        echo "Error: Java not found. Please install JDK."
        exit 1
    fi

    if [[ "$VERBOSE" == true ]]; then
        echo "Java version: $(java -version 2>&1 | head -n 1)"
    fi
}

validate_input() {
    if [[ ! -f "$JAVA_FILE" ]]; then
        echo "Error: File not found: $JAVA_FILE"
        exit 1
    fi
}

# Extract package information
extract_package_info() {
    PACKAGE=$(grep -m 1 "^package " "$JAVA_FILE" 2>/dev/null | \
              sed 's/package \(.*\);/\1/' | tr -d ' ')
}

# Build intelligent classpath
build_classpath() {
    local base_cp=""

    # Start with workspace root as base
    if [[ -n "$WORKSPACE_ROOT" ]]; then
        # Look for common Java source directories
        for src_dir in "src/main/java" "src" "java"; do
            if [[ -d "$WORKSPACE_ROOT/$src_dir" ]]; then
                base_cp="$WORKSPACE_ROOT/$src_dir"
                break
            fi
        done

        # If no standard structure, use file directory logic
        if [[ -z "$base_cp" && -n "$PACKAGE" ]]; then
            PACKAGE_PATH=$(echo "$PACKAGE" | tr '.' '/')
            if [[ "$FILE_DIR" == *"$PACKAGE_PATH" ]]; then
                base_cp="${FILE_DIR%/$PACKAGE_PATH}"
            else
                base_cp="$FILE_DIR"
            fi
        elif [[ -z "$base_cp" ]]; then
            base_cp="$FILE_DIR"
        fi
    else
        # Fallback to original logic
        if [[ -n "$PACKAGE" ]]; then
            PACKAGE_PATH=$(echo "$PACKAGE" | tr '.' '/')
            if [[ "$FILE_DIR" == *"$PACKAGE_PATH" ]]; then
                base_cp="${FILE_DIR%/$PACKAGE_PATH}"
            else
                base_cp="$FILE_DIR"
            fi
        else
            base_cp="$FILE_DIR"
        fi
    fi

    # Add external libraries from workspace
    if [[ -n "$WORKSPACE_ROOT" ]]; then
        for lib_candidate in "lib" "libs" "dependencies" "target/dependency"; do
            local lib_path="$WORKSPACE_ROOT/$lib_candidate"
            if [[ -d "$lib_path" ]]; then
                local auto_jars=$(find "$lib_path" -name "*.jar" 2>/dev/null | tr '\n' ':')
                if [[ -n "$auto_jars" ]]; then
                    base_cp="$base_cp:$auto_jars"
                    [[ "$VERBOSE" == true ]] && echo "Auto-detected JARs in $lib_candidate: $auto_jars"
                fi
            fi
        done
    fi

    # Add specified lib directory
    if [[ -n "$LIB_DIR" && -d "$LIB_DIR" ]]; then
        local jars=$(find "$LIB_DIR" -name "*.jar" 2>/dev/null | tr '\n' ':')
        if [[ -n "$jars" ]]; then
            base_cp="$base_cp:$jars"
            [[ "$VERBOSE" == true ]] && echo "Found JARs in $LIB_DIR: $jars"
        fi
    fi

    # Clean up classpath
    BASE_CLASSPATH=$(echo "$base_cp" | sed 's/:*$//')
    RUN_CLASSPATH="$BASE_CLASSPATH"
}

# Determine main class
determine_main_class() {
    if [[ -n "$PACKAGE" ]]; then
        MAIN_CLASS="$PACKAGE.$FILE_NAME"
    else
        MAIN_CLASS="$FILE_NAME"
    fi
}

# Compilation function
compile_java() {
    echo "=== Compilation ==="

    local compile_cmd="javac"

    # Add classpath
    if [[ -n "$BASE_CLASSPATH" && "$BASE_CLASSPATH" != "." ]]; then
        compile_cmd="$compile_cmd -cp \"$BASE_CLASSPATH\""
    fi

    # Add debug information
    if [[ "$DEBUG_MODE" == true ]]; then
        compile_cmd="$compile_cmd -g"
    fi

    # Compile package files or single file
    if [[ -n "$PACKAGE" ]]; then
        local package_dir="$(dirname "$JAVA_FILE")"
        if [[ -d "$package_dir" ]]; then
            compile_cmd="$compile_cmd \"$package_dir\"/*.java"
        else
            compile_cmd="$compile_cmd \"$JAVA_FILE\""
        fi
    else
        compile_cmd="$compile_cmd \"$JAVA_FILE\""
    fi

    [[ "$VERBOSE" == true ]] && echo "Command: $compile_cmd"

    if ! eval $compile_cmd; then
        echo "Error: Compilation failed"
        exit 1
    fi

    echo "✓ Compilation successful"
}

# Execution function
execute_java() {
    echo "=== Execution ==="

    local run_cmd="java"

    # Add JVM options
    if [[ -n "$JVM_OPTS" ]]; then
        run_cmd="$run_cmd $JVM_OPTS"
    fi

    # Add debug options
    if [[ "$DEBUG_MODE" == true ]]; then
        run_cmd="$run_cmd -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005"
        echo "Debug mode enabled. Connect debugger to port 5005"
    fi

    # Add classpath
    if [[ -n "$RUN_CLASSPATH" ]]; then
        run_cmd="$run_cmd -cp \"$RUN_CLASSPATH\""
    fi

    # Add main class
    run_cmd="$run_cmd $MAIN_CLASS"

    # Add program arguments
    if [[ -n "$PROGRAM_ARGS" ]]; then
        run_cmd="$run_cmd $PROGRAM_ARGS"
    fi

    [[ "$VERBOSE" == true ]] && echo "Command: $run_cmd"

    # Change to workspace directory for execution
    if [[ -n "$WORKSPACE_ROOT" ]]; then
        cd "$WORKSPACE_ROOT"
    fi

    if ! eval $run_cmd; then
        echo "Error: Execution failed"
        exit 1
    fi
}

# Main execution flow
main() {
    check_java_installation
    determine_context
    validate_input
    extract_package_info
    build_classpath
    determine_main_class

    if [[ "$VERBOSE" == true ]]; then
        echo "=== Configuration ==="
        echo "File: $JAVA_FILE"
        echo "Workspace: ${WORKSPACE_ROOT:-"(none)"}"
        echo "Package: ${PACKAGE:-"(none)"}"
        echo "Main class: $MAIN_CLASS"
        echo "Classpath: $BASE_CLASSPATH"
        echo "JVM options: ${JVM_OPTS:-"(none)"}"
        echo "Program args: ${PROGRAM_ARGS:-"(none)"}"
        echo ""
    fi

    # Execute based on options
    if [[ "$RUN_ONLY" != true ]]; then
        compile_java
        echo ""
    fi

    if [[ "$COMPILE_ONLY" != true ]]; then
        execute_java
    fi
}

# Run main function
main "$@"
