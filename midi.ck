SinOsc osc => dac;
0.0 => osc.gain; 

MidiIn midi;
MidiMsg msg;
1 => int device;

if( me.args() ) me.arg(0) => Std.atoi => device;
if ( !midi.open( device ) )
{
    <<< "Error: Could not open MIDI device:", device >>>;
    me.exit();
}
<<< "MIDI device opened:", midi.num(), " -> ", midi.name() >>>;


while (true) 
{
    midi => now;
    while (midi.recv(msg)) {<<<msg.data1, msg.data2, msg.data3>>>;}
}