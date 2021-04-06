#!/bin/bash
while read; do
  if curl -sLfko /dev/null ${REPLY}; then
    echo "403"
  else
    echo "200"
  fi
done