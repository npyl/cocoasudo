//
//  cocoasudo.m
//
//  Created by Aaron Kardell on 10/19/2009.
//  Copyright 2009 Performant Design, LLC. All rights reserved.
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

#import <Cocoa/Cocoa.h>

#include <sys/stat.h>
#include <unistd.h>
#include <Security/Authorization.h>
#include <Security/AuthorizationTags.h>

#include <NPTask/NPTask.h>

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

int cocoaSudo(char *executable, char *commandArgs[], char *icon, char *prompt) {
	int retVal = 1;
	OSStatus status;
	AuthorizationRef authRef;
	
	AuthorizationItem right = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights rightSet = {1, &right};
	
	AuthorizationEnvironment myAuthorizationEnvironment;
	AuthorizationItem kAuthEnv[2];
	myAuthorizationEnvironment.items = kAuthEnv;

	AuthorizationFlags flags = kAuthorizationFlagDefaults;
	
	
	if (prompt && icon) {
		kAuthEnv[0].name = kAuthorizationEnvironmentPrompt;
		kAuthEnv[0].valueLength = strlen(prompt);
		kAuthEnv[0].value = prompt;
		kAuthEnv[0].flags = 0;
		
		kAuthEnv[1].name = kAuthorizationEnvironmentIcon;
		kAuthEnv[1].valueLength = strlen(icon);
		kAuthEnv[1].value = icon;
		kAuthEnv[1].flags = 0;
		
		myAuthorizationEnvironment.count = 2;
	}
	else if (prompt) {
		kAuthEnv[0].name = kAuthorizationEnvironmentPrompt;
		kAuthEnv[0].valueLength = strlen(prompt);
		kAuthEnv[0].value = prompt;
		kAuthEnv[0].flags = 0;
		
		myAuthorizationEnvironment.count = 1;
	}
	else if (icon) {
		kAuthEnv[0].name = kAuthorizationEnvironmentIcon;
		kAuthEnv[0].valueLength = strlen(icon);
		kAuthEnv[0].value = icon;
		kAuthEnv[0].flags = 0;
		
		myAuthorizationEnvironment.count = 1;
	}
	else {
		myAuthorizationEnvironment.count = 0;
	}
	
	status = AuthorizationCreate(NULL, &myAuthorizationEnvironment, flags, &authRef);
	
	if (status != errAuthorizationSuccess) {
		NSLog(@"Could not create authorization reference object.");
		status = errAuthorizationBadAddress;
	}
	else {
		flags = kAuthorizationFlagDefaults |
			kAuthorizationFlagInteractionAllowed |
			kAuthorizationFlagPreAuthorize |
			kAuthorizationFlagExtendRights;

		status = AuthorizationCopyRights(authRef, &rightSet, &myAuthorizationEnvironment, flags, NULL);
	}

	if (status == errAuthorizationSuccess) {
		FILE *ioPipe;
		char buffer[1024];
		int bytesRead;

		flags = kAuthorizationFlagDefaults;
		status = AuthorizationExecuteWithPrivileges(authRef, executable, flags, commandArgs, &ioPipe);

		/* Just pipe processes' stdout to our stdout for now; hopefully can add stdin pipe later as well */
		
        	for (;;) {
			bytesRead = (int)fread(buffer, sizeof(char), 1024, ioPipe);
			
            		if (bytesRead < 1) {
                		break;
            		}
			
            		write(STDOUT_FILENO, buffer, bytesRead * sizeof(char));
		}
		
		pid_t pid;
		int pidStatus;
        
		do {
			pid = wait(&pidStatus);
		} 
        	while (pid != -1);
		
        	if (status == errAuthorizationSuccess) {
			retVal = 0;
		}
	}
	else {
		AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
		authRef = NULL;
		
        	if (status != errAuthorizationCanceled) {
			// pre-auth failed
			NSLog(@"Pre-auth failed");
		}
	}
	
	return retVal;
}

/* use our own API which is up-to-date */
int npylSudo(char *executable, char *commandArgs[], int len, char *icon, char *prompt) {
    int argumentsCount = 0;
    NSMutableArray *args = [NSMutableArray array];
    
    for (int i = 0; i < len; i++)
    {
        /* everytime we get an string-end increment argumentsCount */
        if (*(commandArgs + i) == '\0')
            argumentsCount++;
    }
    
    for (int i = 0; i < argumentsCount; i++)
    {
        [args addObject:[NSString stringWithUTF8String:commandArgs[i]]];
    }
    
    NSLog(@"%s", executable);
    NSLog(@"%@", args);
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [NSString stringWithUTF8String:executable];
    task.arguments = args;
    //task.currentDirectoryPath = NSHomeDirectory();
    
    [task launchAuthenticated];
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
    
	fprintf(stderr, "usage: %s [--icon=icon.tiff] [--prompt=prompt...] command\n  --icon=[filename]: optional argument to specify a custom icon\n  --prompt=[prompt]: optional argument to specify a custom prompt\n", appName);
}

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	int retVal = 1;
	int programArgsStartAt = 1;
	char *icon = NULL;
	char *prompt = NULL;

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
			
            //retVal = cocoaSudo(executable, commandArgs, icon, prompt);
            int len = (argc - programArgsStartAt);
            retVal = npylSudo(executable, commandArgs, len, icon, prompt);
			
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
	
	[pool release];
    
	return retVal;
}
