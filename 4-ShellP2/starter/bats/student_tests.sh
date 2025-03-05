#!/usr/bin/env bats

# File: student_tests.sh
# 
# Create your unit tests suit in this file

 @test "Example: check ls runs without errors" {
    run ./dsh <<EOF
ls
EOF

    # Assertions
    [ "$status" -eq 0 ]
}

@test "echo command outputs expected text" {
  run bash -c 'echo "echo hello world" | ./dsh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "hello world" ]]
}

@test "uname -a command outputs Linux" {
  run bash -c 'echo "uname" | ./dsh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Linux" ]]
}

@test "dragon command prints dragon art" {
  run bash -c 'echo "dragon" | ./dsh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "@%%%%" ]]
}

@test "cd command changes directory" {
  run bash -c 'echo "pwd\ncd ..\npwd" | ./dsh'
  [ "$status" -eq 0 ]
  oldpwd=$(echo "$output" | sed -n '2p')
  newpwd=$(echo "$output" | sed -n '4p')
  [ "$oldpwd" != "$newpwd" ]
}

@test "ls command lists expected file" {
  run bash -c 'echo "ls" | ./dsh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dsh" ]]
}

@test "rc built-in returns correct exit code after failure" {
  run bash -c 'echo -e "not_exists\rc" | ./dsh'
  [ "$status" -eq 0 ]
  last_char=$(echo -n "$output" | tail -c 1)
  [ "$last_char" -eq 2 ]
}