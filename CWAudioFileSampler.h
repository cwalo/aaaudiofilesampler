//
//  CWAudioFileSampler.h
//  CWCore
//
//  Created by Corey Walo on 4/26/15.
//  Copyright (c) 2015 Corey Walo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef struct AUGraphPlayer
{
    AudioStreamBasicDescription inputFormat; // input file's data stream description
    AudioFileID					inputFile; // reference to your input file
    
    AUGraph graph;
    AudioUnit fileAU;
    
} AUGraphPlayer;

@interface CWAudioFileSampler : NSObject
{
    NSArray *audioResourceURLS;
    NSUInteger numSamples;
    AUGraphPlayer *players;
    BOOL *graphStarted;
}

-(BOOL)loadAudioURLS:(NSArray*)fileURLArray;
-(void)loadAUFilePlayers;
-(void)playSample:(NSUInteger)sampleInArray;
-(void)stopSample:(NSUInteger)sampleInArray;
-(void)stopPlayers;
-(void)stopAndClosePlayers;

@end
