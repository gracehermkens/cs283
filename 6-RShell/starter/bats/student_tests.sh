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
    run bash -c 'echo "pwd; cd ..; pwd" | ./dsh'
    [ "$status" -eq 0 ]
    oldpwd=$(echo "$output" | sed -n '1p')
    newpwd=$(echo "$output" | sed -n '2p')
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

# Helper function to wait for a port to be open
wait_for_port() {
  local port=$1
  local max_attempts=10
  local attempt=0
  while ! nc -z 127.0.0.1 $port && [ $attempt -lt $max_attempts ]; do
    sleep 0.1
    attempt=$((attempt+1))
  done
}

###########################################
# Additional Remote Shell Tests for Assignment
###########################################

@test "Remote: echo command via client-server" {
  PORT=5678
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  run bash -c './dsh -c -i 127.0.0.1 -p $PORT <<< "echo hello"'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "hello" ]]

  kill $server_pid || true
}

@test "Remote: cd command changes directory in session" {
  PORT=5679
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  initial_pwd=$(./dsh -c -i 127.0.0.1 -p $PORT <<< "pwd")
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "cd .. ; pwd"
  new_pwd=$(echo "$output" | tail -n1)
  [ "$new_pwd" != "$initial_pwd" ]

  kill $server_pid || true
}

@test "Remote: ls command lists files via client" {
  PORT=5680
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "ls"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dsh" ]]

  kill $server_pid || true
}

@test "Remote: output redirection on server side" {
  PORT=5681
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo hello > remote_output.txt"
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "cat remote_output.txt"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "hello" ]]

  ./dsh -c -i 127.0.0.1 -p $PORT <<< "rm remote_output.txt"
  kill $server_pid || true
}

@test "Remote: pipeline command over network" {
  PORT=5682
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "ls | grep '.c'"
  [ "$status" -eq 0 ]
  [[ "$output" == *.c* ]]

  kill $server_pid || true
}

@test "Remote: dragon command returns art" {
  PORT=5683
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "dragon"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "@%%%%" ]]

  kill $server_pid || true
}

@test "Remote: rc returns exit code of previous command" {
  PORT=5684
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  ./dsh -c -i 127.0.0.1 -p $PORT <<< "invalidcommand"
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "rc"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "127" ]]  # Assuming command not found exit code is 127

  kill $server_pid || true
}

@test "Remote: stop-server command shuts down server" {
  PORT=5685
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "stop-server"
  [ "$status" -eq 0 ]

  # Wait for server to exit
  wait $server_pid || true
  run pgrep -f "dsh -s -p $PORT"
  [ "$status" -ne 0 ]
}

@test "Remote: input redirection from file on server" {
  PORT=5686
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  echo -e "line1\nline2\nline3" > input.txt
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "wc -l < input.txt"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]

  rm input.txt
  kill $server_pid || true
}

@test "Remote: append output redirection" {
  PORT=5687
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo line1 > append.txt"
  ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo line2 >> append.txt"
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "cat append.txt"
  [ "$status" -eq 0 ]
  [[ "$output" =~ $'line1\nline2' ]]

  ./dsh -c -i 127.0.0.1 -p $PORT <<< "rm append.txt"
  kill $server_pid || true
}

###########################################
# Additional Remote Functionality Tests
###########################################

@test "Remote: exit command disconnects client" {
  PORT=5688
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  # Send the "exit" command to disconnect this client.
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "exit"
  [ "$status" -eq 0 ]

  # Now try connecting again to verify the server is still running.
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo still alive"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "still alive" ]]

  kill $server_pid || true
}

@test "Remote: multiple semicolon-separated commands execute in order" {
  PORT=5689
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  # Send multiple commands separated by semicolons.
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo first; echo second; echo third"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "first" ]]
  [[ "$output" =~ "second" ]]
  [[ "$output" =~ "third" ]]

  kill $server_pid || true
}

@test "Remote: multiple client connections work" {
  PORT=5690
  ./dsh -s -p $PORT &
  server_pid=$!
  wait_for_port $PORT

  # First client connection
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo client one"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "client one" ]]

  # Second client connection
  run ./dsh -c -i 127.0.0.1 -p $PORT <<< "echo client two"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "client two" ]]

  kill $server_pid || true
}
