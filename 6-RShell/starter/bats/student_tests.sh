#!/usr/bin/env bats

# File: student_tests.sh
# 
# Create your unit tests suit in this file

# Setup function to clean lingering processes between tests
setup() {
  # Kill any lingering dsh server processes
  pkill -f "dsh -s" 2>/dev/null || true
  # Clean up any temporary files
  rm -f server_log.txt test_input.txt test_output.txt
}

# Teardown to ensure cleanup
teardown() {
  # Kill any remaining server processes
  pkill -f "dsh -s" 2>/dev/null || true
  # Clean up any temporary files from interrupted tests
  rm -f server_log.txt test_input.txt test_output.txt
}

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

## Helper Functions for Remote Server Testing
start_server() {
    local PORT=$((8000 + RANDOM % 1000))
    local MAX_ATTEMPTS=5
    local ATTEMPTS=0
    
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        if nc -z 127.0.0.1 $PORT 2>/dev/null; then
            PORT=$((8000 + RANDOM % 1000))
            ATTEMPTS=$((ATTEMPTS+1))
            continue
        fi
        
        ./dsh -s -p $PORT > server_log.txt 2>&1 &
        local SERVER_PID=$!
        
        sleep 0.5
        
        if ! nc -z 127.0.0.1 $PORT 2>/dev/null; then
            kill $SERVER_PID 2>/dev/null || true
            PORT=$((8000 + RANDOM % 1000))
            ATTEMPTS=$((ATTEMPTS+1))
            continue
        fi
        
        echo "$PORT:$SERVER_PID"
        return 0
    done
    
    echo "Failed to start server after $MAX_ATTEMPTS attempts" >&2
    return 1
}

@test "Remote: echo command via client-server" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    run bash -c "echo 'echo hello' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status: $output"; }
    [[ "$output" =~ "hello" ]] || { cat server_log.txt; fail "Expected 'hello' in output, got: $output"; }
}

@test "Remote: cd command changes directory in session" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    initial_pwd=$(echo "pwd" | ./dsh -c -i 127.0.0.1 -p $PORT)
    
    run bash -c "echo 'cd .. ; pwd' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    new_pwd=$(echo "$output" | tail -n1)
    [ "$new_pwd" != "$initial_pwd" ] || { cat server_log.txt; fail "Directory did not change"; }
}

@test "Remote: ls command lists files via client" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    run bash -c "echo 'ls' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    [[ "$output" =~ "dsh" ]] || { cat server_log.txt; fail "Expected 'dsh' in output: $output"; }
}

@test "Remote: output redirection on server side" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    echo "echo hello > remote_output.txt" | ./dsh -c -i 127.0.0.1 -p $PORT
    sleep 0.5  

    run bash -c "echo 'cat remote_output.txt' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    echo "rm remote_output.txt" | ./dsh -c -i 127.0.0.1 -p $PORT 2>/dev/null || true
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    [[ "$output" =~ "hello" ]] || { cat server_log.txt; fail "Expected 'hello' in output: $output"; }
}

@test "Remote: pipeline command over network" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    run bash -c "echo 'ls | grep \".c\"' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    [[ "$output" == *.c* ]] || { cat server_log.txt; fail "Expected .c file in output: $output"; }
}

@test "Remote: rc returns exit code of previous command" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    echo "invalidcommand" | ./dsh -c -i 127.0.0.1 -p $PORT
    run bash -c "echo 'rc' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    [[ "$output" =~ "127" ]] || { cat server_log.txt; fail "Expected exit code in output: $output"; }
}

@test "Remote: input redirection from file on server" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    echo "echo -e 'line1\nline2\nline3' > input.txt" | ./dsh -c -i 127.0.0.1 -p $PORT
    sleep 0.5  

    run bash -c "echo 'wc -l < input.txt' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    echo "rm input.txt" | ./dsh -c -i 127.0.0.1 -p $PORT 2>/dev/null || true
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    [[ "$output" =~ "3" ]] || { cat server_log.txt; fail "Expected count of 3 in output: $output"; }
}

@test "Remote: append output redirection" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    echo "echo line1 > append.txt" | ./dsh -c -i 127.0.0.1 -p $PORT
    sleep 0.5  
    echo "echo line2 >> append.txt" | ./dsh -c -i 127.0.0.1 -p $PORT
    sleep 0.5 
    
    run bash -c "echo 'cat append.txt' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    echo "rm append.txt" | ./dsh -c -i 127.0.0.1 -p $PORT 2>/dev/null || true
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Command failed with status $status"; }
    [[ "$output" =~ $'line1\nline2' ]] || { cat server_log.txt; fail "Expected appended lines in output: $output"; }
}

@test "Remote: exit command disconnects client" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    run bash -c "echo 'exit' | ./dsh -c -i 127.0.0.1 -p $PORT"
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Exit command failed with status $status"; }
    
    run bash -c "echo 'echo still alive' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Second connection failed with status $status"; }
    [[ "$output" =~ "still alive" ]] || { cat server_log.txt; fail "Expected 'still alive' in output: $output"; }
}


@test "Remote: multiple client connections work" {
    SERVER_INFO=$(start_server)
    [ "$?" -eq 0 ] || fail "Failed to start server"
    
    PORT=$(echo $SERVER_INFO | cut -d':' -f1)
    SERVER_PID=$(echo $SERVER_INFO | cut -d':' -f2)
    
    run bash -c "echo 'echo client one' | ./dsh -c -i 127.0.0.1 -p $PORT"
    [ "$status" -eq 0 ] || { cat server_log.txt; fail "First client connection failed with status $status"; }
    [[ "$output" =~ "client one" ]] || { cat server_log.txt; fail "Expected 'client one' in output: $output"; }
    
    run bash -c "echo 'echo client two' | ./dsh -c -i 127.0.0.1 -p $PORT"
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true

    [ "$status" -eq 0 ] || { cat server_log.txt; fail "Second client connection failed with status $status"; }
    [[ "$output" =~ "client two" ]] || { cat server_log.txt; fail "Expected 'client two' in output: $output"; }
}