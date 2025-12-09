//--------------------------------------------------------------------
// 8-Voice Harmonizer with 3 Modes (Chromatic / Strict / Very Strict)
//--------------------------------------------------------------------

// ====================================================================
// 1. MIDI CONFIGURATION & GLOBALS
// ====================================================================

1 => int MY_MIDI_DEVICE; 

// Knobs
[70, 71, 72, 73, 74, 75, 76, 77] @=> int CC_VOICE_KNOBS[];

// Buttons
0 => int CC_OCTAVE_BTN;
1 => int CC_VOWEL_BTN;
2 => int CC_MODE_BTN;
3 => int CC_RESET_BTN;

// ====================================================================
// 2. GLOBAL STATE VARIABLES
// ====================================================================

0.0 => global float g_target_freq;
0.0 => global float g_target_gain;

// volumes of 8 voices
[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] @=> global float g_voice_vol[]; 
[ 
    "- Octave", // 0
    "- 5th",  // 1
    "- 4th",  // 2
    "Root",// 3
    "+ 3rd",   // 4
    "+ 4th",// 5
    "+ 5th",// 6
    "+ Octave" // 7
] @=> string g_voice_name[];

// states
0 => global int g_octave_state; 
0 => global int g_vowel_idx;    
0 => global int g_strict_mode;  // 0:Chromatic, 1:Diatonic
0 => global int g_key_root;

["A","E","I","O","U"] @=> string g_vowel_name[];
["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string g_key_name[];
[ 
  [730.0, 1090.0, 2440.0], // A
  [530.0, 1840.0, 2480.0], // E
  [270.0, 2290.0, 3010.0], // I
  [570.0,  840.0, 2410.0], // O
  [300.0,  870.0, 2240.0]  // U
] @=> float VOWEL_DATA[][];

// ====================================================================
// 3. AUDIO
// ====================================================================
adc => PoleZero dcblock => FFT fft => blackhole;
1024 => fft.size;
Windowing.hamming(fft.size()) => fft.window;
0.99 => dcblock.blockZero;

JCRev r => LPF post_lpf => Dyno lim => dac;
0.1 => r.mix;

4000.0 => post_lpf.freq;
1.0 => post_lpf.Q;

lim.limit();
0.8 => lim.thresh;
0.0 => lim.slopeAbove;
0.01::second => lim.attackTime;
0.1::second  => lim.releaseTime;

// ====================================================================
// 4. HELPER FUNCTIONS
// ====================================================================
[0, 2, 4, 5, 7, 9, 11] @=> int MAJOR_SCALE[];

// For strict mode
fun int quantizeToScale(float midi_note, int key_root) {
    Math.round(midi_note) $ int => int note_int;
    note_int % 12 => int chroma; 
    (chroma - key_root + 12) % 12 => int relative_chroma;
    
    100 => int closest_dist;
    0 => int closest_offset;
    for (0 => int i; i < MAJOR_SCALE.size(); i++) {
        Math.abs(relative_chroma - MAJOR_SCALE[i]) => int dist;
        if (dist < closest_dist) {
            dist => closest_dist;
            MAJOR_SCALE[i] - relative_chroma => closest_offset;
        }
    }
    return note_int + closest_offset;
}

// Get the nearest pitch in chromatic mode and diatonic mode
fun float getTargetPitch(float input_freq, int voice_type) {
    if (input_freq < 50) return 0.0;
    
    Std.ftom(input_freq) => float input_midi;
    
    float oct_offset_semitones;
    if (g_octave_state == 0) 0.0 => oct_offset_semitones;
    else if (g_octave_state == 1) 12.0 => oct_offset_semitones;
    else if (g_octave_state == 2) 24.0 => oct_offset_semitones;
    else -12.0 => oct_offset_semitones;

    float chromatic_shift;
    int scale_degree_shift;
    
    if (voice_type == 0) { -12.0 => chromatic_shift; -7 => scale_degree_shift; }      
    else if (voice_type == 1) { -7.0 => chromatic_shift; -4 => scale_degree_shift; } 
    else if (voice_type == 2) { -5.0 => chromatic_shift; -3 => scale_degree_shift; } 
    else if (voice_type == 3) { 0.0 => chromatic_shift; 0 => scale_degree_shift; } 
    else if (voice_type == 4) { 4.0 => chromatic_shift; 2 => scale_degree_shift; }  
    else if (voice_type == 5) { 5.0 => chromatic_shift; 3 => scale_degree_shift; } 
    else if (voice_type == 6) { 7.0 => chromatic_shift; 4 => scale_degree_shift; } 
    else if (voice_type == 7) { 12.0 => chromatic_shift; 7 => scale_degree_shift; } 

    float final_midi;

    // Mode 1: diatonic
    if (g_strict_mode == 1) {
        Math.round(input_midi) + chromatic_shift => float temp_midi;
        quantizeToScale(temp_midi, g_key_root) $ float => final_midi;
    }
    // Mode 0: chromatic
    else {
        Math.round(input_midi) + chromatic_shift => final_midi;
    }
    
    return Std.mtof(final_midi + oct_offset_semitones);
}

// ====================================================================
// 5. VOICE SHRED
// ====================================================================
fun void voiceShred(int voice_idx) {
    Impulse i => TwoZero t => TwoZero t2 => OnePole p;
    p => TwoPole f1 => Gain g1;
    p => TwoPole f2 => g1;
    p => TwoPole f3 => g1;
    g1 => r; 
    
    1.0 => t.b0; 0.0 => t.b1; -0.95 => t.b2; 
    0.995 => f1.radius => f2.radius => f3.radius;
    1.0 => f1.gain => f2.gain => f3.gain;
    
    0.0 => float curr_period;
    0.0 => float modphase;
    0.1 => float slew;
    Math.random2f(0.0, 6.28) => float vib_phase;
    
    while(true) {
        if (g_voice_vol[voice_idx] <= 0.0) {
            0.0 => i.next;
            10::ms => now;
            continue;
        }
        
        VOWEL_DATA[g_vowel_idx][0] => f1.freq;
        VOWEL_DATA[g_vowel_idx][1] => f2.freq;
        VOWEL_DATA[g_vowel_idx][2] => f3.freq;
        
        getTargetPitch(g_target_freq, voice_idx) => float target_p;
        
        if (target_p > 50) {
            1.0 / target_p => float target_per;
            (target_per - curr_period) * slew + curr_period => curr_period;

            0.15 * g_target_gain * g_voice_vol[voice_idx] => i.next;
            
            modphase + curr_period => modphase;
            (curr_period + (curr_period * 0.005 * Math.sin(vib_phase)))::second => now;
            vib_phase + 0.1 => vib_phase;
        } else {
            0.0 => i.next;
            10::ms => now;
        }
    }
}

// ====================================================================
// 6. MIDI HANDLER
// ====================================================================
fun void midiHandler() {
    MidiIn min;
    MidiMsg msg;
    
    if( !min.open( MY_MIDI_DEVICE ) ) {
        <<< "Error: Could not open MIDI device:", MY_MIDI_DEVICE >>>;
        me.exit();
    }
    <<< "MIDI device opened:", min.name() >>>;
    <<< "Key: C" >>>;
    <<< "Vowel: A" >>>;
    <<< "Harmonizer Mode: Chromatic" >>>;
    
    while( true ) {
        min => now;
        while( min.recv(msg) ) {
            
            // 1. Voices volumes
            if (msg.data1 == 176 && msg.data2 >= CC_VOICE_KNOBS[0] && msg.data2 <= CC_VOICE_KNOBS[7]){
                (msg.data2 - CC_VOICE_KNOBS[0]) => int idx;
                msg.data3 / 127.0 => g_voice_vol[idx];
                <<< "Voice", g_voice_name[idx], "Volume:", g_voice_vol[idx] >>>;
            }

            // 2. Set key
            if (msg.data1 == 144 && msg.data3 > 0 && msg.data2 >= 60 && msg.data2 <= 71) 
            {
                (msg.data2 % 12) => int new_key;
                if (new_key != g_key_root) {
                    new_key => g_key_root;
                    <<< "Key Set via MIDI Key:", g_key_name[g_key_root] >>>;
                }
            }
            
            // 3. Octave switch (Cycle: 0 -> 1 -> 2 -> 3(-1) -> 0)
            if (msg.data1 == 201 && msg.data2 == CC_OCTAVE_BTN) {
                (g_octave_state + 1) % 4 => g_octave_state;
                string s;
                if(g_octave_state==3) "-1" => s; else Std.itoa(g_octave_state) => s;; 
                <<< "Octave Shift:", s >>>;
            }
            
            // 4. Vowel switch (Cycle: 0~4)
            if (msg.data1 == 201 && msg.data2 == CC_VOWEL_BTN) {
                (g_vowel_idx + 1) % 5 => g_vowel_idx;
                <<< "Vowel Changed:", g_vowel_name[g_vowel_idx] >>>;
            }
            
            // 5. Mode switch (Chromatic / Diatonic)
            if (msg.data1 == 201 && msg.data2 == CC_MODE_BTN) {
                if (g_strict_mode == 0) 1 => g_strict_mode;
                else 0 => g_strict_mode;
                string m; if(g_strict_mode) "Diatonic" => m; else "Chromatic" => m;
                <<< "Harmonizer Mode:", m >>>;
            }
            
            // 6. Reset
            if (msg.data1 == 201 && msg.data2 == CC_RESET_BTN) {
                [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] @=> g_voice_vol;
                <<<"Cleared">>>;
            }
        }
    }
}

// ====================================================================
// 7. MAIN EXECUTION
// ====================================================================

spork ~ midiHandler();

for (0 => int i; i < 8; i++) {
    spork ~ voiceShred(i);
}

// 3. Main FFT Loop
while( true ) {
    fft.upchuck() @=> UAnaBlob blob;
    
    0.0 => float max; int where;
    for( int i; i < blob.fvals().size(); i++ ) {
        if (i < 3) continue;
        if( blob.fvals()[i] > max ) {
            blob.fvals()[i] => max;
            i => where;
        }
    }
    
    float exact_where;
    if (where > 0 && where < blob.fvals().size()-1) {
        blob.fvals()[where-1] => float y1;
        blob.fvals()[where] => float y2;
        blob.fvals()[where+1] => float y3;
        (y1 - y3) / (2.0 * (y1 - 2.0 * y2 + y3)) => float offset;
        where + offset => exact_where;
    } else {
        where => exact_where;
    }
    
    (exact_where / fft.size() * 44100.0) => g_target_freq; 

    max * 50.0 => g_target_gain; 
    
    (fft.size()/8)::samp => now;
}