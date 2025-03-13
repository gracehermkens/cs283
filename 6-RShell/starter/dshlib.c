#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>

#include "dshlib.h"
#include <errno.h>

static int last_exit_code = 0;

int clear_cmd_buff(cmd_buff_t *cmd_buff) {
    if (cmd_buff->_cmd_buffer != NULL) {
        free(cmd_buff->_cmd_buffer); 
        cmd_buff->_cmd_buffer = NULL;
    }
    cmd_buff->argc = 0;
    for (int i = 0; i < CMD_ARGV_MAX; i++) {
        cmd_buff->argv[i] = NULL;   
    }
    return OK;
}

int clear_command_list(command_list_t *cmd_list) {
    if (cmd_list == NULL) {
        return ERR_MEMORY;
    }
    
    for (int i = 0; i < CMD_MAX; i++) {
        clear_cmd_buff(&cmd_list->commands[i]);
    }
    
    cmd_list->num = 0;
    return OK;
}

int build_cmd_buff(char *cmd_line, cmd_buff_t *cmd_buff) {
    clear_cmd_buff(cmd_buff);
    
    cmd_buff->_cmd_buffer = strdup(cmd_line);
    if (cmd_buff->_cmd_buffer == NULL) {
        return ERR_MEMORY;
    }
    
    int argc = 0;
    char *ptr = cmd_buff->_cmd_buffer;
    
    cmd_buff->input_file = NULL;
    cmd_buff->output_file = NULL;
    cmd_buff->append_mode = false;
    
    while (*ptr != '\0') {
        while (*ptr == ' ') {
            ptr++;
        }
        if (*ptr == '\0') {
            break;
        }
        
        if (*ptr == '<') {
            ptr++;
            while (*ptr == ' ') ptr++; 
            if (*ptr == '\0') break;
            
            cmd_buff->input_file = ptr;
            
            while (*ptr != '\0' && *ptr != ' ' && *ptr != '<' && *ptr != '>') {
                ptr++;
            }
            if (*ptr != '\0') {
                char temp = *ptr;
                *ptr = '\0';
                ptr++;
                if (temp != ' ') {
                    ptr--;
                }
            }
            continue;
        } else if (*ptr == '>') {
            ptr++;
            bool append = false;
            
            if (*ptr == '>') {
                append = true;
                ptr++;
            }
            
            while (*ptr == ' ') ptr++; 
            if (*ptr == '\0') break;

            cmd_buff->output_file = ptr;
            cmd_buff->append_mode = append;

            while (*ptr != '\0' && *ptr != ' ' && *ptr != '<' && *ptr != '>') {
                ptr++;
            }
            if (*ptr != '\0') {
                char temp = *ptr;
                *ptr = '\0';
                ptr++;
                if (temp != ' ') {
                    ptr--;
                }
            }
            continue;
        }
        
        char *token = NULL;
        if (*ptr == '\"') {
            ptr++;
            token = ptr;
            char *end_quote = strchr(ptr, '\"');
            if (end_quote == NULL) {
                end_quote = ptr + strlen(ptr);
            }
            *end_quote = '\0';
            ptr = end_quote + 1;
        } else {
            token = ptr;
            while (*ptr != '\0' && *ptr != ' ' && *ptr != '<' && *ptr != '>') {
                ptr++;
            }
            if (*ptr != '\0') {
                char temp = *ptr;
                *ptr = '\0';
                ptr++;
                if (temp != ' ') {
                    ptr--;
                }
            }
        }
        if (argc < CMD_ARGV_MAX) {
            cmd_buff->argv[argc] = token;
            argc++;
        } else {
            return ERR_CMD_OR_ARGS_TOO_BIG;
        }
    }
    cmd_buff->argc = argc;
    return OK;
}

int build_cmd_list(char *line, command_list_t *cmd_list) {
    clear_command_list(cmd_list);
    
    char *token = strtok(line, "|");
    int cmd_count = 0;
    
    while (token != NULL && cmd_count < CMD_MAX) {
        while (*token == ' ') {
            token++;
        }
        
        if (*token != '\0') {
            int rc = build_cmd_buff(token, &cmd_list->commands[cmd_count]);
            if (rc != OK) {
                clear_command_list(cmd_list);
                return rc;
            }

            if (cmd_list->commands[cmd_count].argc == 0) {
                clear_cmd_buff(&cmd_list->commands[cmd_count]);
            } else {
                cmd_count++;
            }
        }
        
        token = strtok(NULL, "|");
    }

    if (token != NULL) {
        clear_command_list(cmd_list);
        return ERR_TOO_MANY_COMMANDS;
    }
    
    cmd_list->num = cmd_count;
    
    if (cmd_count == 0) {
        return WARN_NO_CMDS;
    }
    
    return OK;
}

Built_In_Cmds match_command(const char *input) {
    if (strcmp(input, EXIT_CMD) == 0) {
        return BI_CMD_EXIT;
    }

    else if (strcmp(input, "dragon") == 0) {
        return BI_CMD_DRAGON;
    }

    else if (strcmp(input, "cd") == 0) {
        return BI_CMD_CD;
    }

    else if (strcmp(input, "rc") == 0) {
        return BI_CMD_RC;
    }

    else {
        return BI_NOT_BI;
    }
}

Built_In_Cmds exec_built_in_cmd(cmd_buff_t *cmd) {
    Built_In_Cmds type = match_command(cmd->argv[0]);
    switch (type) {
        case BI_CMD_EXIT:
            exit(0);
            break;

        case BI_CMD_DRAGON:
            print_dragon();
            break;

        case BI_CMD_CD:
            if (cmd->argc == 1) {
                char *home = getenv("HOME");
                if (home != NULL) {
                    if (chdir(home) != 0) {
                        perror("cd");
                    }
                }
            } else if (cmd->argc == 2) {
                if (chdir(cmd->argv[1]) != 0) {
                    perror("cd");
                }
            } else {
                fprintf(stderr, "cd: too many arguments\n");
            }
            break;

        case BI_CMD_RC:
            printf("%d\n", last_exit_code);
            break;

        default:
            break;
    }
    return type;
}

int execute_pipeline(command_list_t *cmd_list) {
    int num = cmd_list->num;
    int pipes[CMD_MAX][2];
    pid_t child_pids[CMD_MAX];

    for (int i = 0; i < num - 1; i++) {
        if (pipe(pipes[i]) < 0) {
            perror("pipe");
            return ERR_EXEC_CMD;
        }
    }

    for (int i = 0; i < num; i++) {
        cmd_buff_t *cmd = &cmd_list->commands[i];

        if (cmd->argc == 0) {
            continue; 
        }

        pid_t pid = fork();
        if (pid < 0) {
            perror("fork");

            for (int j = 0; j < num - 1; j++) {
                close(pipes[j][0]);
                close(pipes[j][1]);
            }

            return ERR_EXEC_CMD;
        }

        if (pid == 0) { 
            if (i > 0) {
                dup2(pipes[i - 1][0], STDIN_FILENO);
            } 
            
            else if (cmd->input_file != NULL) {
                int fd = open(cmd->input_file, O_RDONLY);
                
                if (fd < 0) {
                    perror("open input");
                    exit(errno);
                }
                dup2(fd, STDIN_FILENO);
                close(fd);
            }

            if (i < num - 1) {
                dup2(pipes[i][1], STDOUT_FILENO);
            } else if (cmd->output_file != NULL) {
                int flags = O_WRONLY | O_CREAT;
                flags |= cmd->append_mode ? O_APPEND : O_TRUNC;
                int fd = open(cmd->output_file, flags, 0644);
                if (fd < 0) {
                    perror("open output");
                    exit(errno);
                }
                dup2(fd, STDOUT_FILENO);
                close(fd);
            }

            for (int j = 0; j < num - 1; j++) {
                close(pipes[j][0]);
                close(pipes[j][1]);
            }

            execvp(cmd->argv[0], cmd->argv);
            perror("execvp");
            exit(errno);
        } else {
            child_pids[i] = pid;
        }
    }

    for (int i = 0; i < num - 1; i++) {
        close(pipes[i][0]);
        close(pipes[i][1]);
    }

    int last_status = 0;
    for (int i = 0; i < num; i++) {
        int status;
        if (waitpid(child_pids[i], &status, 0) < 0) {
            perror("waitpid");
            return ERR_EXEC_CMD;
        }
        if (WIFEXITED(status)) {
            last_status = WEXITSTATUS(status);
        } else {
            last_status = ERR_EXEC_CMD;
        }
    }

    return last_status;
}

int exec_cmd(cmd_buff_t *cmd) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return ERR_EXEC_CMD;
    }
    if (pid == 0) {
        if (cmd->input_file != NULL) {
            int fd = open(cmd->input_file, O_RDONLY);
            if (fd < 0) {
                perror("open input");
                exit(errno);
            }
            dup2(fd, STDIN_FILENO);
            close(fd);
        }

        if (cmd->output_file != NULL) {
            int flags = O_WRONLY | O_CREAT;
            flags |= cmd->append_mode ? O_APPEND : O_TRUNC;
            
            int fd = open(cmd->output_file, flags, 0644);
            if (fd < 0) {
                perror("open output");
                exit(errno);
            }
            dup2(fd, STDOUT_FILENO);
            close(fd);
        }
        
        execvp(cmd->argv[0], cmd->argv);
        perror("execvp");
        exit(errno);
    } else {
        int status;
        if (waitpid(pid, &status, 0) < 0) {
            perror("waitpid");
            return ERR_EXEC_CMD;
        }
        if (WIFEXITED(status)) {
            return WEXITSTATUS(status);
        } else {
            return ERR_EXEC_CMD;
        }
    }
    return ERR_EXEC_CMD;
}

int free_cmd_list(command_list_t *clist) {
    for (int i = 0; i < clist->num; i++) {
        clear_cmd_buff(&clist->commands[i]);
    }
    clist->num = 0;
    return OK;
}

/**** 
 **** FOR REMOTE SHELL USE YOUR SOLUTION FROM SHELL PART 3 HERE
 **** THE MAIN FUNCTION CALLS THIS ONE AS ITS ENTRY POINT TO
 **** EXECUTE THE SHELL LOCALLY
 ****
 */

/*
 * Implement your exec_local_cmd_loop function by building a loop that prompts the 
 * user for input.  Use the SH_PROMPT constant from dshlib.h and then
 * use fgets to accept user input.
 * 
 *      while(1){
 *        printf("%s", SH_PROMPT);
 *        if (fgets(cmd_buff, ARG_MAX, stdin) == NULL){
 *           printf("\n");
 *           break;
 *        }
 *        //remove the trailing \n from cmd_buff
 *        cmd_buff[strcspn(cmd_buff,"\n")] = '\0';
 * 
 *        //IMPLEMENT THE REST OF THE REQUIREMENTS
 *      }
 * 
 *   Also, use the constants in the dshlib.h in this code.  
 *      SH_CMD_MAX              maximum buffer size for user input
 *      EXIT_CMD                constant that terminates the dsh program
 *      SH_PROMPT               the shell prompt
 *      OK                      the command was parsed properly
 *      WARN_NO_CMDS            the user command was empty
 *      ERR_TOO_MANY_COMMANDS   too many pipes used
 *      ERR_MEMORY              dynamic memory management failure
 * 
 *   errors returned
 *      OK                     No error
 *      ERR_MEMORY             Dynamic memory management failure
 *      WARN_NO_CMDS           No commands parsed
 *      ERR_TOO_MANY_COMMANDS  too many pipes used
 *   
 *   console messages
 *      CMD_WARN_NO_CMD        print on WARN_NO_CMDS
 *      CMD_ERR_PIPE_LIMIT     print on ERR_TOO_MANY_COMMANDS
 *      CMD_ERR_EXECUTE        print on execution failure of external command
 * 
 *  Standard Library Functions You Might Want To Consider Using (assignment 1+)
 *      malloc(), free(), strlen(), fgets(), strcspn(), printf()
 * 
 *  Standard Library Functions You Might Want To Consider Using (assignment 2+)
 *      fork(), execvp(), exit(), chdir()
 */
int exec_local_cmd_loop() {
    char line[SH_CMD_MAX];
    int rc = OK;
    command_list_t cmd_list = {0};;

    cmd_list.num = 0;
    
    while (1) {
        printf("%s", SH_PROMPT);

        if (fgets(line, SH_CMD_MAX, stdin) == NULL) {
            printf("\n");
            break;
        }

        line[strcspn(line, "\n")] = '\0';
        
        if (strlen(line) == 0) {
            printf(CMD_WARN_NO_CMD);
            continue;
        }

        char line_copy[SH_CMD_MAX];
        strcpy(line_copy, line);

        rc = build_cmd_list(line_copy, &cmd_list);
        
        if (rc == WARN_NO_CMDS) {
            printf(CMD_WARN_NO_CMD);
            continue;
        } 
        
        else if (rc == ERR_TOO_MANY_COMMANDS) {
            fprintf(stderr, CMD_ERR_PIPE_LIMIT, CMD_MAX);
            continue;
        } 
        
        else if (rc != OK) {
            fprintf(stderr, "Error parsing command.\n");
            continue;
        }

        if (cmd_list.num == 1 && 
            strcmp(cmd_list.commands[0].argv[0], EXIT_CMD) == 0) {
            printf("exiting...\n");
            clear_command_list(&cmd_list);
            break;
        }

        if (cmd_list.num == 1) {
            Built_In_Cmds bi = match_command(cmd_list.commands[0].argv[0]);
            if (bi != BI_NOT_BI) {
                exec_built_in_cmd(&cmd_list.commands[0]);
                clear_command_list(&cmd_list);
                continue;
            }
        }

        rc = execute_pipeline(&cmd_list);
        last_exit_code = rc;
        
        if (rc != 0) {
            fprintf(stderr, CMD_ERR_EXECUTE);
        }

        clear_command_list(&cmd_list);
    }
    
    return last_exit_code;
}
