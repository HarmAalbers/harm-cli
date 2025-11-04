#!/usr/bin/env bash
# Safe wrapper for running ShellSpec tests
# Detects TTY availability and adjusts formatter accordingly

# Check if stdin is a TTY
if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
  # TTY is available, can use any formatter
  exec shellspec "$@"
else
  # No TTY available, avoid trace formatter
  # Check if --format trace is in the arguments
  has_trace_format=false
  for arg in "$@"; do
    if [ "$arg" = "trace" ] && [ "$prev_arg" = "--format" ]; then
      has_trace_format=true
      break
    fi
    prev_arg="$arg"
  done

  if [ "$has_trace_format" = true ]; then
    # Replace trace format with documentation format
    new_args=()
    skip_next=false
    for arg in "$@"; do
      if [ "$skip_next" = true ]; then
        new_args+=("documentation")
        skip_next=false
      elif [ "$arg" = "--format" ]; then
        new_args+=("$arg")
        skip_next=true
      else
        new_args+=("$arg")
      fi
    done
    echo "⚠️  No TTY available, using documentation format instead of trace" >&2
    exec shellspec "${new_args[@]}"
  else
    # No trace format specified, run as-is
    exec shellspec "$@"
  fi
fi
