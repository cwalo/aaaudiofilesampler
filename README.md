##AAAudioFileSampler

I originally wrote this class for a Drum Machine app for iPad, but it could be utilized for any number of applications. 

It could be used for OS X by simply replacing:

```
outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
```
with
```
outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
```

In use:

* Declare an instance of AAAudioFileSampler
* Call ```loadAudioURLS```
* Call ```loadAUFilePlayers```
* Play a sample by calling ```playSample```
* When finished, call ```stopAndClosePlayers```
* To stop all audio, but keep everything in place call ```stopPlayers```

