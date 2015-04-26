//
//  AAAudioFileSampler.h
//  AACore
//
//  Created by Corey Walo on 4/26/15.
//  Copyright (c) 2015 Corey Walo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

static const int kNumSamples = 16;

typedef struct AUGraphPlayer
{
    AudioStreamBasicDescription inputFormat; // input file's data stream description
    AudioFileID					inputFile; // reference to your input file
    
    AUGraph graph;
    AudioUnit fileAU;
    
} AUGraphPlayer;

@interface AAAudioFileSampler : NSObject
{
    NSArray *audioResourceURLS;
    AUGraphPlayer players[kNumSamples];
    BOOL graphStarted[kNumSamples];
}

-(BOOL)loadAudioURLS:(NSArray*)fileURLArray;
-(void)loadAUFilePlayers;
-(void)playSample:(int)sampleInArray;
-(void)stopPlayers;
-(void)stopAndClosePlayers;

@end
