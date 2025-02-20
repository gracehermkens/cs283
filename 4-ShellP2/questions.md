1. Can you think of why we use `fork/execvp` instead of just calling `execvp` directly? What value do you think the `fork` provides?

    > **Answer**: We use `fork` to make a new child process so when `execvp` is called it only replaces the child's process image rather than the shell's process. This allows the shell to stay running and continues to accept new commands after the external command finished. Overall, `fork` provides process isolation and guarantees that executing a command doesn't stop the shell itself.

2. What happens if the fork() system call fails? How does your implementation handle this scenario?

    > **Answer**: If the `fork()` system call fails, it will return a negative value. In my implementation, when `fork()` returns a negative value, we use `perror()` to print an error message and return an error code so that the failure is handled properly and the shell doesn't attempt to execute the command further. 

3. How does execvp() find the command to execute? What system environment variable plays a role in this process?

    > **Answer**: The `execvp()` searches for the executable in the directories listed in the `PATH` environment variable. If the command entered isn't an absolute or relative path, `execvp()` iterates over each directory to locate the binary. Therefore, the `PATH` environment variable is critical in figuring out which executable is run.

4. What is the purpose of calling wait() in the parent process after forking? What would happen if we didn’t call it?

    > **Answer**: The purpose of calling `wait()` in the parent process is to suspend its execution until the child process completes. This allows the parent to retrieve the exit status of the child and prevents the creation of zombie processes (when the child finishes, but its status hasn't been collected). Without calling `wait()`, the shell might continue to launch new commands while leaving terminated child processes in the table. 

5. In the referenced demo code we used WEXITSTATUS(). What information does this provide, and why is it important?

    > **Answer**: The `WEXITSTATUS()` macro extracts the exit code from the status returned by `wait()`. This exit code tells us whether the child process ended successfully or an error had occurred. This is important because it lets the shell report the outcome of the command execution and allows for error handling based on specific failures. 

6. Describe how your implementation of build_cmd_buff() handles quoted arguments. Why is this necessary?

    > **Answer**: My implementation of `build_cmd_buff()`, it manually iterates over the input command string. When a double quote is encountered, the parser collects all characters until the next double quote into a single token (preserving the spaces inside). This is essential because arguments that include spaces (like `"hello cs283"`) must be treated as one argument rather than it being split into multiple tokens. 

7. What changes did you make to your parsing logic compared to the previous assignment? Were there any unexpected challenges in refactoring your old code?

    > **Answer**: A change I made from the previous assignment was replacing `strtok()` (it splits on whitespace) with a manual parsing loop that recognizes and preserves substring within quotes. An unexpected challenge was correctly handling edge cases like unmatched quotes or extra whitespace, ensuring that the tokens are properly terminated without losing the important characters.  

8. For this quesiton, you need to do some research on Linux signals. You can use [this google search](https://www.google.com/search?q=Linux+signals+overview+site%3Aman7.org+OR+site%3Alinux.die.net+OR+site%3Atldp.org&oq=Linux+signals+overview+site%3Aman7.org+OR+site%3Alinux.die.net+OR+site%3Atldp.org&gs_lcrp=EgZjaHJvbWUyBggAEEUYOdIBBzc2MGowajeoAgCwAgA&sourceid=chrome&ie=UTF-8) to get started.

- What is the purpose of signals in a Linux system, and how do they differ from other forms of interprocess communication (IPC)?

    > **Answer**: Signals in Linux are used as an asynchronous notification mecahnism to inform a process that a specific event has happened. They are different from other forms of interprocess communication because signals are limited to conveying a small amount of information and are mainly used for control purposes rather than data exchange. 

- Find and describe three commonly used signals (e.g., SIGKILL, SIGTERM, SIGINT). What are their typical use cases?

    > **Answer**: `SIGKILL` - immediately stops a process and can't be caught or ignored. It is used when a process must be stopped (forced). `SIGTERM` - requests a process to stop gracefully, giving it a chance to clean up. `SIGINT` - usually sent when a user enters `Ctrl+C` in the terminal, and it interrupts a process and allows it to perform any essential cleanup before terminating. 

- What happens when a process receives SIGSTOP? Can it be caught or ignored like SIGINT? Why or why not?

    > **Answer**:  When a process receives `SIGSTOP`, it is paused by the operating system. Unlike `SIGINT`, `SIGSTOP` cannot be caught, blocked, or ignored since it is made to be a reliable way to suspend any process regardless of the internal signal handlers. This ensures that system administrators or debugging tools can always pause a process when necessary. 
