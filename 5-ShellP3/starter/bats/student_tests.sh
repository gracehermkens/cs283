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

@test "Test pipeline: ls | grep '.c'" {
    run ./dsh <<EOF
ls | grep ".c"
EOF
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *.c* ]] 
}

@test "Test pipeline: echo hello | wc -c" {
    run ./dsh <<EOF
echo hello | wc -c
EOF
    [ "$status" -eq 0 ]
    [ "${lines[0]}" -eq 6 ] 
}

@test "Test input redirection: wc -l < file.txt" {
    echo -e "line1\nline2\nline3" > file.txt
    run ./dsh <<EOF
wc -l < file.txt
EOF
    [ "$status" -eq 0 ]
    [ "${lines[0]}" -eq 3 ]
    rm file.txt
}

@test "Test output redirection: echo hello > out.txt" {
    run ./dsh <<EOF
echo hello > out.txt
EOF
    [ "$status" -eq 0 ]
    [ "$(cat out.txt)" = "hello" ]  
    rm out.txt
}

@test "Test append output redirection: echo line1 >> out.txt and echo line2 >> out.txt" {
    echo "line1" > out.txt
    run ./dsh <<EOF
echo line2 >> out.txt
EOF
    [ "$status" -eq 0 ]
    [ "$(cat out.txt)" = $'line1\nline2' ] 
    rm out.txt
}

@test "Test combined pipeline and redirection: ls | grep '.c' > out.txt" {
    run ./dsh <<EOF
ls | grep ".c" > out.txt
EOF
    [ "$status" -eq 0 ]
    [ "$(cat out.txt)" != "" ]  
    rm out.txt
}

@test "Test combined input and output redirection: wc -l < file.txt > out.txt" {
    echo -e "line1\nline2\nline3" > file.txt
    run ./dsh <<EOF
wc -l < file.txt > out.txt
EOF
    [ "$status" -eq 0 ]
    [ "$(cat out.txt)" -eq 3 ] 
    rm file.txt out.txt
}