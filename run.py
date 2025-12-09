import subprocess
import os
import sys

CHUCK_FILE = "ultimate_harmonizer.ck"


MIDI_DEVICE_ID = "1" 

os.environ['CHUCK_MIDI_IN_DEVICE'] = MIDI_DEVICE_ID

command = ["chuck", "-r", CHUCK_FILE]

print("="*40)
print(f"[{os.path.basename(__file__)}]: Starting ChucK VM")
print(f"Running command: {' '.join(command)}")
print(f"Using Environment Variable CHUCK_MIDI_IN_DEVICE={MIDI_DEVICE_ID}")
print("="*40)

try:
    process = subprocess.Popen(command)
    process.wait()

except FileNotFoundError:
    print("\n[ERROR] cannot find 'chuck.exe'")
    print("해결: Install ChucK, and check whether 'chuck.exe'is in the system path.")
except Exception as e:
    print(f"\n[ERROR] Unexpected error: {e}")

print("\n--- ChucK Process ending ---")