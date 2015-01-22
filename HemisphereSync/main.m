//
//  main.m
//  HemisphereSync
//
//  Created by Joseph Benden on 1/22/15.
//  Copyright (c) 2015 Joseph Benden. All rights reserved.
//
//  LICENSE: BSD
//
//  Classified Under Class Level 1.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSException.h>
#import <AudioUnit/AudioUnit.h>

double theta = 0.0, theta_right = (2.0 * M_PI * 11 / 16000) * 2;
AudioComponentInstance toneUnit;

void createToneUnit();

OSStatus RenderTone(
                    void *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData)

{
    // Fixed amplitude is good enough for our purposes
    const double amplitude = 0.25;
    
    // Get the tone parameters out of the view controller
    double theta_increment = 2.0 * M_PI * 11 / 16000;
    double theta_increment_right = (2.0 * M_PI * 11 / 16000);
    
    // This is a mono tone generator so we only need the first buffer
    const int channel = 0;
    Float32 *buffer = (Float32 *)ioData->mBuffers[channel].mData;
    Float32 *buffer_right = (Float32 *)ioData->mBuffers[1].mData;
    
    // Generate the samples
    for (UInt32 frame = 0; frame < inNumberFrames; frame++)
    {
        buffer[frame] = sin(theta) * amplitude;
        //NSLog(@"%f", buffer[frame]);
        buffer_right[frame] = sin(theta_right) * amplitude;
        
        theta += theta_increment;
        if (theta > 2.0 * M_PI)
        {
            theta -= 2.0 * M_PI;
        }
        theta_right += theta_increment_right;
        if (theta_right > 2.0 * M_PI) {
            theta_right -= 2.0 * M_PI;
        }
    }
    
    return noErr;
}

void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
    NSLog(@"Stop");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        if (toneUnit)
        {
            AudioOutputUnitStop(toneUnit);
            AudioUnitUninitialize(toneUnit);
            AudioComponentInstanceDispose(toneUnit);
            toneUnit = nil;
            
            //[selectedButton setTitle:NSLocalizedString(@"Play", nil) forState:0];
        }
        else
        {
            createToneUnit();
            
            // Stop changing parameters on the unit
            OSErr err = AudioUnitInitialize(toneUnit);
            NSCAssert1(err == noErr, @"Error initializing unit: %ld", err);
            
            // Start playback
            err = AudioOutputUnitStart(toneUnit);
            NSCAssert1(err == noErr, @"Error starting unit: %ld", err);
            
            //[selectedButton setTitle:NSLocalizedString(@"Stop", nil) forState:0];
        }
        for(;;) {
            sleep(10);
        }
    }
    return 0;
}

void createToneUnit() {
    // Configure the search parameters to find the default playback output unit
    // (called the kAudioUnitSubType_RemoteIO on iOS but
    // kAudioUnitSubType_DefaultOutput on Mac OS X)
    AudioComponentDescription defaultOutputDescription;
    defaultOutputDescription.componentType = kAudioUnitType_Output;
    defaultOutputDescription.componentSubType = kAudioUnitSubType_DefaultOutput;// kAudioUnitSubType_RemoteIO;
    defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    defaultOutputDescription.componentFlags = 0;
    defaultOutputDescription.componentFlagsMask = 0;
    
    // Get the default playback output unit
    AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
    NSCAssert(defaultOutput, @"Can't find default output");
    
    // Create a new unit based on this that we'll use for output
    OSErr err = AudioComponentInstanceNew(defaultOutput, &toneUnit);
    NSCAssert1(toneUnit, @"Error creating unit: %ld", err);
    
    // Set our tone rendering function on the unit
    AURenderCallbackStruct input;
    input.inputProc = RenderTone;
    input.inputProcRefCon = nil;
    err = AudioUnitSetProperty(toneUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &input,
                               sizeof(input));
    NSCAssert1(err == noErr, @"Error setting callback: %ld", err);
    
    // Set the format to 32 bit, single channel, floating point, linear PCM
    const int four_bytes_per_float = 4;
    const int eight_bits_per_byte = 8;
    AudioStreamBasicDescription streamFormat;
    streamFormat.mSampleRate = 16000;
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags =
    kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    streamFormat.mBytesPerPacket = four_bytes_per_float;
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mBytesPerFrame = four_bytes_per_float;
    streamFormat.mChannelsPerFrame = 2;
    streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
    err = AudioUnitSetProperty (toneUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &streamFormat,
                                sizeof(AudioStreamBasicDescription));
    NSCAssert1(err == noErr, @"Error setting stream format: %ld", err);
}
