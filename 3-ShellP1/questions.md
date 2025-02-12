1. In this assignment I suggested you use `fgets()` to get user input in the main while loop. Why is `fgets()` a good choice for this application?

    > **Answer**:  Using `fgets()` is good for getting user input because it safely handles input by preventing buffer overflows, preserves whitespace and special characters in the input (so important for shell commands), and it reads until a newline or EOF is entered which is perfect for command-line input. In addition, it is generally more reliable than `gets()` or `scanf()`.

2. You needed to use `malloc()` to allocte memory for `cmd_buff` in `dsh_cli.c`. Can you explain why you needed to do that, instead of allocating a fixed-size array?

    > **Answer**: Using `malloc()` to allocate memory is essential since it allows for dynamic sizing. This allows the buffer to adapt to varying input lengths during runtime. Also, memory is only allocated when needed and can be freed when no longer required which is more efficient than reserving a large fixed array. 


3. In `dshlib.c`, the function `build_cmd_list()` must trim leading and trailing spaces from each command before storing it. Why is this necessary? If we didn't trim spaces, what kind of issues might arise when executing commands in our shell?

    > **Answer**: This is necessary because firstly unix commands are space-sensitive, so trailing spaces can cause command parsing errors. Command lookup would also fail if there were leading spaces before the name of the command. Similarly, arguments can be misinterpreted as a resuly of extra white space. Overall, without trimming, even the simple commands can fail to execute. 

4. For this question you need to do some research on STDIN, STDOUT, and STDERR in Linux. We've learned this week that shells are "robust brokers of input and output". Google _"linux shell stdin stdout stderr explained"_ to get started.

- One topic you should have found information on is "redirection". Please provide at least 3 redirection examples that we should implement in our custom shell, and explain what challenges we might have implementing them.

    > **Answer**: We should implement output redirection (>) where it writes command output to a file, but the challenge will be properly saving and restoring file descriptors. Also, we should add input redirection (<) where it takes input from a file instead of the keyboard, and the challenge is that the shell has to handle file open errors properlly. Lastly, I think we should implement append redirection (>>) where it adds output to the end of an existing file. The challenge for this is ensuring thread safety and avoiding issues like multiple threads trying to write to a file at the same time. 

- You should have also learned about "pipes". Redirection and piping both involve controlling input and output in the shell, but they serve different purposes. Explain the key differences between redirection and piping.

    > **Answer**: Redirection connects processes with files, but pipes connect processes with other processes. Essentially, pipes create a communication channel between processes which allows for data flow. Redirection  involved filesystem operations, however, pipes operate in memory. 

- STDERR is often used for error messages, while STDOUT is for regular output. Why is it important to keep these separate in a shell?

    > **Answer**: It is important to keep STDERR seperate from STDOUT because error messages need to be visable to the user even if the ouput is redirected. To add, programs can detect and handle errors differently from regular output. In general, users should be able to distinguish between normal program output and error conditions. 

- How should our custom shell handle errors from commands that fail? Consider cases where a command outputs both STDOUT and STDERR. Should we provide a way to merge them, and if so, how?

    > **Answer**: For handling command errors in the chell, we should handle errors by ensuring that command failures output appropriate error messages to STDERR, while regular output goes to STDOUT. In addition, we should provide an option to merge both streams (STDOUT and STDERR) into a single output. This is possible by using a shell construct to redirect STDERR to the same location as STDOUT. This is helpful for logging or debugging. 