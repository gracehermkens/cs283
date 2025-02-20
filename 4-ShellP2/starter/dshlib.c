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

int build_cmd_buff(char *cmd_line, cmd_buff_t *cmd_buff) {
    clear_cmd_buff(cmd_buff);
    
    cmd_buff->_cmd_buffer = strdup(cmd_line);
    if (cmd_buff->_cmd_buffer == NULL) {
        return ERR_MEMORY;
    }
    
    int argc = 0;
    char *ptr = cmd_buff->_cmd_buffer;
    
    while (*ptr != '\0') {
        while (*ptr == ' ') {
            ptr++;
        }
        if (*ptr == '\0')
            break;
        
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
            while (*ptr != '\0' && *ptr != ' ') {
                ptr++;
            }
            if (*ptr != '\0') {
                *ptr = '\0';
                ptr++;
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

Built_In_Cmds match_command(const char *input) {
    if (strcmp(input, EXIT_CMD) == 0)
        return BI_CMD_EXIT;
    else if (strcmp(input, "dragon") == 0)
        return BI_CMD_DRAGON;
    else if (strcmp(input, "cd") == 0)
        return BI_CMD_CD;
    else if (strcmp(input, "rc") == 0)
        return BI_RC;
    else
        return BI_NOT_BI;
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
            } else if (cmd->argc == 2) {
                if (chdir(cmd->argv[1]) != 0) {
                    perror("cd");
                }
            } else {
                fprintf(stderr, "cd: too many arguments\n");
            }
            break;
        case BI_RC:
            printf("%d\n", last_exit_code);
            break;
        default:
            break;
    }
    return type;
}

int exec_cmd(cmd_buff_t *cmd) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return ERR_EXEC_CMD;
    }
    if (pid == 0) {
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
int exec_local_cmd_loop()
{
    char line[SH_CMD_MAX];
    int rc = OK;
    cmd_buff_t cmd;
    cmd._cmd_buffer = NULL;

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
    
	rc = build_cmd_buff(line, &cmd);
        if (rc != OK) {
            fprintf(stderr, "Error parsing command.\n");
            clear_cmd_buff(&cmd);
            continue;
        }

	Built_In_Cmds bi = match_command(cmd.argv[0]);
        if (bi != BI_NOT_BI) {
            exec_built_in_cmd(&cmd);
            clear_cmd_buff(&cmd);
            continue;
        }
    
	rc = exec_cmd(&cmd);
        last_exit_code = rc;
        if (rc != 0) {
            fprintf(stderr, CMD_ERR_EXECUTE);
        }
        clear_cmd_buff(&cmd);
    }
    return last_exit_code;
}