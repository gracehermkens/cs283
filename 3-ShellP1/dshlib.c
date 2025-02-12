#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "dshlib.h"

/*
 *  build_cmd_list
 *    cmd_line:     the command line from the user
 *    clist *:      pointer to clist structure to be populated
 *
 *  This function builds the command_list_t structure passed by the caller
 *  It does this by first splitting the cmd_line into commands by spltting
 *  the string based on any pipe characters '|'.  It then traverses each
 *  command.  For each command (a substring of cmd_line), it then parses
 *  that command by taking the first token as the executable name, and
 *  then the remaining tokens as the arguments.
 *
 *  NOTE your implementation should be able to handle properly removing
 *  leading and trailing spaces!
 *
 *  errors returned:
 *
 *    OK:                      No Error
 *    ERR_TOO_MANY_COMMANDS:   There is a limit of CMD_MAX (see dshlib.h)
 *                             commands.
 *    ERR_CMD_OR_ARGS_TOO_BIG: One of the commands provided by the user
 *                             was larger than allowed, either the
 *                             executable name, or the arg string.
 *
 *  Standard Library Functions You Might Want To Consider Using
 *      memset(), strcmp(), strcpy(), strtok(), strlen(), strchr()
 */
int build_cmd_list(char *cmd_line, command_list_t *clist)
{
    clist->num = 0;
    memset(clist->commands, 0, sizeof(command_t) * CMD_MAX);

    if (strlen(cmd_line) == 0) {
        return WARN_NO_CMDS;
    }

    char cmd_copy[SH_CMD_MAX];
    strncpy(cmd_copy, cmd_line, SH_CMD_MAX - 1);
    cmd_copy[SH_CMD_MAX - 1] = '\0';

    char *saveptr1;
    char *command = strtok_r(cmd_copy, "|", &saveptr1);
    
    while (command != NULL) {
        if (clist->num >= CMD_MAX) {
            return ERR_TOO_MANY_COMMANDS;
        }

        while (isspace(*command)) command++;
        char *end = command + strlen(command) - 1;
        while (end > command && isspace(*end)) end--;
        *(end + 1) = '\0';

        if (strlen(command) == 0) {
            command = strtok_r(NULL, "|", &saveptr1);
            continue;
        }

        char *saveptr2;
        char *token = strtok_r(command, " ", &saveptr2);
        
        if (token == NULL) {
            return WARN_NO_CMDS;
        }

        if (strlen(token) >= EXE_MAX) {
            return ERR_CMD_OR_ARGS_TOO_BIG;
        }
        strcpy(clist->commands[clist->num].exe, token);

        char args_buffer[ARG_MAX] = "";
        token = strtok_r(NULL, " ", &saveptr2);
        while (token != NULL) {
            if (strlen(args_buffer) + strlen(token) + 2 >= ARG_MAX) {
                return ERR_CMD_OR_ARGS_TOO_BIG;
            }
            
            if (strlen(args_buffer) > 0) {
                strcat(args_buffer, " ");
            }
            strcat(args_buffer, token);
            
            token = strtok_r(NULL, " ", &saveptr2);
        }

        if (strlen(args_buffer) > 0) {
            strcpy(clist->commands[clist->num].args, args_buffer);
        } else {
            clist->commands[clist->num].args[0] = '\0';
        }

        clist->num++;
        command = strtok_r(NULL, "|", &saveptr1);
    }

    if (clist->num == 0) {
        return WARN_NO_CMDS;
    }

    return OK;
}