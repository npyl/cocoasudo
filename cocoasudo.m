//
//  cocoasudo.m
//
//  Created by Aaron Kardell on 10/19/2009.
//  Copyright 2009 Performant Design, LLC. All rights reserved.
//
//  Ported to new authentication APIs by npyl.
//  Copyright 2019 npyl. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <unistd.h>
#import <sys/stat.h>
#import <Cocoa/Cocoa.h>
#import <NPTask/NSAuthenticatedTask.h>

void printData(NSFileHandle *fh)
{
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        /* if data is found, re-register for more data (and print) */
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        printf("%s", str.UTF8String);
    }
};

char *addFileToPath(const char *path, const char *filename) {
    char *outbuf;
    char *lc;
    
    lc = (char *)path + strlen(path) - 1;
    if (lc < path || *lc != '/') {
        lc = NULL;
    }
    
    while (*filename == '/') {
        filename++;
    }
    
    outbuf = malloc(strlen(path) + strlen(filename) + 1 + (lc == NULL ? 1 : 0));
    
    sprintf(outbuf, "%s%s%s", path, (lc == NULL) ? "/" : "", filename);
    
    return outbuf;
}

int isExecFile(const char *name) {
	struct stat s;

	return (!access(name, X_OK) && !stat(name, &s) && S_ISREG(s.st_mode));
}

char *which(const char *filename)
{
    char *path, *p, *n;
    
    path = getenv("PATH");
    
    if (!path) {
        return NULL;
    }
    
    p = path = strdup(path);
    
    while (p) {
        n = strchr(p, ':');
        
        if (n) {
            *n++ = '\0';
        }
        
        if (*p != '\0') {
            p = addFileToPath(p, filename);
            
            if (isExecFile(p)) {
                free(path);
                
                return p;
            }
            
            free(p);
        }
        
        p = n;
    }
    
    free(path);
    
    return NULL;
}

/* use our own API which is up-to-date */
int npylSudo(char *executable, char *commandArgs[], int len, char *icon, char *prompt, NSASession sessionID) {
    int argumentsCount = 0;
    NSString *_executable = [NSString stringWithUTF8String:executable];
    NSMutableArray *args = [NSMutableArray array];
    
    for (int i = 0; i < len; i++)
    {
        /* everytime we get an string-end increment argumentsCount */
        if (*(commandArgs + i) == '\0')
            argumentsCount++;
    }
    
    if (argumentsCount > 0)
        for (int i = 0; i < argumentsCount; i++)
        {
            [args addObject:[NSString stringWithUTF8String:commandArgs[i]]];
        }
    
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    if (icon) task.icon = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:icon]];
    if (prompt) task.text = [NSString stringWithUTF8String:prompt];
    task.launchPath = _executable;
    task.arguments = args;
    task.currentDirectoryPath = NSHomeDirectory();
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];

    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle * _Nonnull fh) {
        printData(fh);
    }];
    [[task.standardError fileHandleForReading] setReadabilityHandler:^(NSFileHandle * _Nonnull fh) {
        printData(fh);
    }];
    
    [task launchAuthorizedWithSession:sessionID];
    [task waitUntilExit];
    
    return task.terminationStatus;
}

void usage(char *appNameFull) {
    char *appName = strrchr(appNameFull, '/');
    
    if (appName == NULL) {
        appName = appNameFull;
    }
    else {
        appName++;
    }
    
    fprintf(stderr, "usage: %s [--icon=icon.tiff] [--prompt=prompt...] [--sessid=session_idnum] command\n  --icon=[filename]: optional argument to specify a custom icon\n  --prompt=[prompt]: optional argument to specify a custom prompt\n  --sessid=[sessid]: optional argument to specify the already-authenticated SESSION ID (a number) to which we should bind this cocoasudo call.\n", appName);
}

int main(int argc, char *argv[]) {
    int retVal = 1;
    int programArgsStartAt = 1;
    char *icon = NULL;
    char *prompt = NULL;
    NSASession sessionID = NSA_SESSION_NEW; /* new session (If nothing is passed default to that.) */
    
    for (; programArgsStartAt < argc; programArgsStartAt++) {
        if (!strncmp("--icon=", argv[programArgsStartAt], 7)) {
            icon = argv[programArgsStartAt] + 7;
        }
        else if (!strncmp("--prompt=", argv[programArgsStartAt], 9)) {
            prompt = argv[programArgsStartAt] + 9;
            
            size_t promptLen = strlen(prompt);
            char *newPrompt = malloc(sizeof(char) * (promptLen + 2));
            
            strcpy(newPrompt, prompt);
            
            newPrompt[promptLen] = '\n';
            newPrompt[promptLen + 1] = '\n';
            newPrompt[promptLen + 2] = '\0';
            
            prompt = newPrompt;
        }
        else if (!strncmp("--sessid=", argv[programArgsStartAt], 9))
        {
            sscanf(argv[programArgsStartAt], "--sessid=%li", &sessionID);
        }
        else {
            break;
        }
    }
    
    if (programArgsStartAt >= argc) {
        usage(argv[0]);
    }
    else {
        char *executable;
        
        if (strchr(argv[programArgsStartAt], '/')) {
            executable = isExecFile(argv[programArgsStartAt]) ? strdup(argv[programArgsStartAt]) : NULL;
        }
        else {
            executable = which(argv[programArgsStartAt]);
        }
        
        if (executable) {
            char **commandArgs = malloc((argc - programArgsStartAt) * sizeof(char**));
            
            memcpy(commandArgs, argv + programArgsStartAt + 1, (argc - programArgsStartAt - 1) * sizeof(char**));
            
            commandArgs[argc - programArgsStartAt - 1] = NULL;
            
            int len = (argc - programArgsStartAt);
            retVal = npylSudo(executable, commandArgs, len, icon, prompt, sessionID);
            
            free(commandArgs);
            free(executable);
        }
        else {
            fprintf(stderr, "Unable to find %s\n", argv[programArgsStartAt]);
            
            usage(argv[0]);
        }
    }
    
    if (prompt) {
        free(prompt);
    }
    
    /*
     * After every cocoasudo execution return SessionID;
     * it should be read by a caller in order to be used
     * later in another cocoasudo call.
     */
    printf("SessionID = %li\n", sessionID);
    
    return retVal;
}
