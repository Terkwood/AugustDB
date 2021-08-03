#!/bin/bash
rm *.sst && rm *.idx
cp commit.log.test0 commit.log
mix phx.server
