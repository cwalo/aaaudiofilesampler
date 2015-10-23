//
//  CWAudioFileSampler.m
//  CWCore
//
//  Created by Corey Walo on 4/26/15.
//  Copyright (c) 2015 Corey Walo. All rights reserved.
//

#import "CWAudioFileSampler.h"

@implementation CWAudioFileSampler

-(BOOL)loadAudioURLS:(NSArray*)fileURLArray
{
    //TODO: error checking and handling of filepaths and size of array
    
    audioResourceURLS = fileURLArray;
    
    numSamples = audioResourceURLS.count;
    
    return TRUE;
}

#pragma mark - audio unit setup -

-(void)loadAUFilePlayers
{
    //allocate memory for our File Players
    players = (AUGraphPlayer *) malloc(numSamples*sizeof(AUGraphPlayer));
    graphStarted = (BOOL *) malloc(numSamples*sizeof(BOOL));
    
    //load file for every AUFilePlayer
    for(int i = 0; i < numSamples; i++)
    {
        CheckError(AudioFileOpenURL((__bridge CFURLRef _Nonnull)([NSURL fileURLWithPath:[audioResourceURLS objectAtIndex:i]]), kAudioFileReadPermission, 0, &players[i].inputFile), "AudioFileOpenURL failed");
        UInt32 propSize = sizeof(players[i].inputFormat);
        CheckError(AudioFileGetProperty(players[i].inputFile, kAudioFilePropertyDataFormat,
                                        &propSize, &players[i].inputFormat),
                   "couldn't get file's data format");
        
        //create the graph for every player
        CreateMyAUGraph(&players[i]);
        graphStarted[i] = NO;
    }
}

-(void)playSample:(NSUInteger)sampleInArray
{
    //if it's playing, stop it first
    [self stopSample:sampleInArray];
    
    //prepare the file player
    PrepareFileAU(&players[sampleInArray]);
    
    //start playing
    CheckError(AUGraphStart(players[sampleInArray].graph),
               "AUGraphStart failed");
    graphStarted[sampleInArray] = YES;
    
}

-(void)stopSample:(NSUInteger)sampleInArray
{
    if(graphStarted[sampleInArray] == YES)
    {
        AUGraphStop(players[sampleInArray].graph);
    }
}

-(void)stopAndClosePlayers
{
    for(int i = 0; i < numSamples; i++)
    {
        AUGraphStop (players[i].graph);
        AUGraphUninitialize (players[i].graph);
        AUGraphClose(players[i].graph);
        AudioFileClose(players[i].inputFile);
    }
    
    audioResourceURLS = nil;
    
    if(players != NULL)
    {
        free(players);
        players = NULL;
    }
    
    if(graphStarted != NULL)
    {
        free(graphStarted);
        graphStarted = NULL;
    }
}

-(void)stopPlayers
{
    for(int i = 0; i < numSamples; i++)
    {
        AUGraphStop (players[i].graph);
    }
}

void CreateMyAUGraph(AUGraphPlayer *player)
{
    // create a new AUGraph
    CheckError(NewAUGraph(&player->graph),
               "NewAUGraph failed");
    
    // genereate description that will match out output device (speakers)
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // adds a node with above description to the graph
    AUNode outputNode;
    CheckError(AUGraphAddNode(player->graph, &outputcd, &outputNode),
               "AUGraphAddNode[kAudioUnitSubType_DefaultOutput] failed");
    
    // generate description that will match a generator AU of type: audio file player
    AudioComponentDescription fileplayercd = {0};
    fileplayercd.componentType = kAudioUnitType_Generator;
    fileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    fileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // adds a node with above description to the graph
    AUNode fileNode;
    CheckError(AUGraphAddNode(player->graph, &fileplayercd, &fileNode),
               "AUGraphAddNode[kAudioUnitSubType_AudioFilePlayer] failed");
    
    // opening the graph opens all contained audio units but does not allocate any resources yet
    CheckError(AUGraphOpen(player->graph),
               "AUGraphOpen failed");
    
    // get the reference to the AudioUnit object for the file player graph node
    CheckError(AUGraphNodeInfo(player->graph, fileNode, NULL, &player->fileAU),
               "AUGraphNodeInfo failed");
    
    // connect the output source of the file player AU to the input source of the output node
    CheckError(AUGraphConnectNodeInput(player->graph, fileNode, 0, outputNode, 0),
               "AUGraphConnectNodeInput");
    
    // now initialize the graph (causes resources to be allocated)
    CheckError(AUGraphInitialize(player->graph),
               "AUGraphInitialize failed");
}

double PrepareFileAU(AUGraphPlayer *player)
{
    // tell the file player unit to load the file we want to play
    CheckError(AudioUnitSetProperty(player->fileAU, kAudioUnitProperty_ScheduledFileIDs,
                                    kAudioUnitScope_Global, 0, &player->inputFile, sizeof(player->inputFile)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs] failed");
    
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    CheckError(AudioFileGetProperty(player->inputFile, kAudioFilePropertyAudioDataPacketCount,
                                    &propsize, &nPackets),
               "AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount] failed");
    
    // tell the file player AU to play the entire file
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = player->inputFile;
    rgn.mLoopCount = 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = nPackets * player->inputFormat.mFramesPerPacket;
    
    CheckError(AudioUnitSetProperty(player->fileAU, kAudioUnitProperty_ScheduledFileRegion,
                                    kAudioUnitScope_Global, 0,&rgn, sizeof(rgn)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed");
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    CheckError(AudioUnitSetProperty(player->fileAU, kAudioUnitProperty_ScheduledFilePrime,
                                    kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime] failed");
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(player->fileAU, kAudioUnitProperty_ScheduleStartTimeStamp,
                                    kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");
    
    // file duration
    return (nPackets * player->inputFormat.mFramesPerPacket) / player->inputFormat.mSampleRate;
    
}

//adamson's error handler: wrap core audio functions with it
static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}
@end