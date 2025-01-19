#include <stdio.h>
#include <string.h>
#include <stdlib.h>


#define BUFFER_SZ 50

//prototypes
void usage(char *);
void print_buff(char *, int);
int  setup_buff(char *, char *, int);

//prototypes for functions to handle required functionality
int  count_words(char *, int, int);

//add additional prototypes here
void reverse_string(char *, int); 
void word_print(char *, int);

int setup_buff(char *buff, char *user_str, int len){
    //TODO: #4:  Implement the setup buff as per the directions
    int str_len = strlen(user_str);

    if (str_len >= len) {
        strncpy(buff, user_str, len - 1);
        buff[len - 1] = '\0'; 
        return len - 1;
    }

    strcpy(buff, user_str);
    return str_len;
}

void print_buff(char *buff, int len){
    printf("Buffer:  ");
    for (int i=0; i<len; i++){
        putchar(*(buff+i));
    }
    putchar('\n');
}

void usage(char *exename){
    printf("usage: %s [-h|c|r|w|x] \"string\" [other args]\n", exename);

}

int count_words(char *buff, int len, int str_len){
    //YOU MUST IMPLEMENT
        int word_count = 0;
    int in_word = 0;
    for (int i = 0; i < str_len; i++) {
        if (buff[i] != ' ' && buff[i] != '\0') {
            if (!in_word) {
                in_word = 1;
                word_count++;
            }
        } else {
            in_word = 0;
        }
    }
    return word_count;
}

//ADD OTHER HELPER FUNCTIONS HERE FOR OTHER REQUIRED PROGRAM OPTIONS

void reverse_string(char *buff, int len) {
    int start = 0;
    int end = len - 1;
    char temp;
    while (start < end) {
        temp = buff[start];
        buff[start] = buff[end];
        buff[end] = temp;
        start++;
        end--;
    }
}

void word_print(char *buff, int len) {
    int i = 0;
    while (i < len && buff[i] != '\0') {
        if (buff[i] == ' ') {
            putchar('\n');
        } else {
            putchar(buff[i]);
        }
        i++;
    }
    putchar('\n');
}

int main(int argc, char *argv[]){

    char *buff;             //placehoder for the internal buffer
    char *input_string;     //holds the string provided by the user on cmd line
    char opt;               //used to capture user option from cmd line
    int  rc;                //used for return codes
    int  user_str_len;      //length of user supplied string

    //TODO:  #1. WHY IS THIS SAFE, aka what if argv[1] does not exist?
    /*      This is safe because the conditional statement
            ensure that the program has recieved at least 2 arguments 
            and that the first argument after the program name starts 
            with a valid option flag ('-'). If argv[1] does not exist, 
            attempting to dereference it (*argv[1]) would result in undefined behavior 
            which is why the argc < 2 check ensures safe access.
    */
    if ((argc < 2) || (*argv[1] != '-')){
        usage(argv[0]);
        exit(1);
    }

    opt = (char)*(argv[1]+1);   //get the option flag

    //handle the help flag and then exit normally
    if (opt == 'h'){
        usage(argv[0]);
        exit(0);
    }

    //WE NOW WILL HANDLE THE REQUIRED OPERATIONS

    //TODO:  #2 Document the purpose of the if statement below
    /*      The purpose of the if statement below is to ensure that 
            has provided the proper string input after the option flag. 
            When argc is less than 3, that means there aren't enough
            provided arguments. 
    */
    if (argc < 3){
        usage(argv[0]);
        exit(1);
    }

    input_string = argv[2]; //capture the user input string

    //TODO:  #3 Allocate space for the buffer using malloc and
    //          handle error if malloc fails by exiting with a 
    //          return code of 99
    // CODE GOES HERE FOR #3
    buff = (char *)malloc(BUFFER_SZ * sizeof(char));
    if (buff == NULL){
        fprintf(stderr, "Error: Failed to allocate memory.\n");
        exit(99);
    }

    user_str_len = setup_buff(buff, input_string, BUFFER_SZ);     //see todos
    if (user_str_len < 0){
        printf("Error setting up buffer, error = %d", user_str_len);
        exit(2);
    }

    switch (opt){
        case 'c':
            rc = count_words(buff, BUFFER_SZ, user_str_len);  //you need to implement
            if (rc < 0){
                printf("Error counting words, rc = %d", rc);
                exit(2);
            }
            printf("Word Count: %d\n", rc);
            break;

        //TODO:  #5 Implement the other cases for 'r' and 'w' by extending
        //       the case statement options

        case 'r':
            reverse_string(buff, user_str_len);
            printf("Reversed String: ");
            print_buff(buff, user_str_len);
            break;

        case 'w':
            word_print(buff, user_str_len); 
            break;

        default:
            usage(argv[0]);
            exit(1);
    }

    //TODO:  #6 Dont forget to free your buffer before exiting
    print_buff(buff,BUFFER_SZ);

    free(buff);

    exit(0);
}

//TODO:  #7  Notice all of the helper functions provided in the 
//          starter take both the buffer as well as the length.  Why
//          do you think providing both the pointer and the length
//          is a good practice, after all we know from main() that 
//          the buff variable will have exactly 50 bytes?
//  
//          Providing both the buffer and the length is good practice since it makes 
//          gaurentees both flexibility and safety in my program. Even though the buffer is 
//          allocated with a fixed size, the string itself can vary in length. So, by passing the 
//          length explicitly, each function can handle the valid portion of the buffer, 
//          prevent buffer overflows, and maintain flexibility for different scenarios. 
//          Overall, it ensures that the helper functions work with the data. 

