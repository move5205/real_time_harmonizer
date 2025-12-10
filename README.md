# real_time_harmonizer


This project presents an 8-voice Formant Harmonizer implemented in the ChucK programming language. It performs real-time pitch tracking on microphone input and generates complex harmonies controlled via MIDI.  
  
***Real-time Pitch Tracking***: Uses FFT (Fast Fourier Transform) and Parabolic Interpolation to accurately track the fundamental frequency (F_0) of the input voice.  
***8-Voice Polyphony***: Simultaneously generates up to eight voices for complex harmony (Root, 3rd, 4th, 5th, Octave, and their inversions)  
***Harmony Modes for Musical Control***:  
1. Chromatic Mode: Fixed semitone intervals (Parallel Harmony)
2. Diatonic Mode: The resulting pitch snapped to the nearest note within the current scale. Harmonic voices are also restricted to notes in the current scale.
# Instructions  
This code is aimed for 'MPK mini 3 1' midi controller.  
  
If you use another one, run midi.ck to print out the control numbers of your midi controller and apply them on ultimate_harmonizer.ck.  
  
You need chuck language in your local PC to run the code.  

You need a midi controller with at least 8 knobs, 12 keys, and 4 buttons that are mappable.  

If it doesn't read your midi controller, try changing the int value of MY_MIDI_DEVICE.
  

# References

1. chant.ck  
https://chuck.stanford.edu/doc/examples/deep/chant.ck

2. pitch-seventh.ck  
https://chuck.stanford.edu/doc/examples/analysis/tracking/pitch-seventh.ck
