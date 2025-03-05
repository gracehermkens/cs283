1. Your shell forks multiple child processes when executing piped commands. How does your implementation ensure that all child processes complete before the shell continues accepting user input? What would happen if you forgot to call waitpid() on all child processes?

My shell implementation colleges the child process IDs into an array and then calls `waitpid()` on each one in a loop. This ensures that the parent process blocks until each child has terminated, stopping the shell from proceeding until the entire pipleline completes. If you forgot to call `waitpid()` on all child processes, they become "zombie" processes, leading to resource leaks and unpredictable behavior. 

2. The dup2() function is used to redirect input and output file descriptors. Explain why it is necessary to close unused pipe ends after calling dup2(). What could go wrong if you leave pipes open?

After using `dup2()` to redirect file descriptors, the original file descriptors associated with the pipes remains open. It is essential to close these unused pipe ends to ensure that the processes correctly recieve an EOF signal when the writing end of the pipe is finished. Failing to close the unused ends can caue processes to hang, waiting for more data that will never come, and may also lead to resource leaks.

3. Your shell recognizes built-in commands (cd, exit, dragon). Unlike external commands, built-in commands do not require execvp(). Why is cd implemented as a built-in rather than an external command? What challenges would arise if cd were implemented as an external process?

The `cd` command is made as a built-in because it needs to change the current working directory of the shell process itself. If `cs` were executed as an external command in a child process, the directory change would only affect that child, and the parent shell's working directory directory would remain unchanged, defeating the purpose of the command. By making `cd` built-in, the shell can directly update its own state. 

4. Currently, your shell supports a fixed number of piped commands (CMD_MAX). How would you modify your implementation to allow an arbitrary number of piped commands while still handling memory allocation efficiently? What trade-offs would you need to consider?

To handle an arbitrary number of piped commands, we can replace the fixed-size array with a dynamically allocated data structure, such as a resiable array (`realloc()`) or a linked list. This allows the shell to allocate memory only as needed, making it flexible to any number commands. But, there can be an increased complexity in memory management, potential performance overhead from dynamic allocation, and the risk of memory leaks if not managed carefully. 
