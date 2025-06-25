import serial

ser = serial.Serial('/dev/ttyUSB0', 115200)
count = 0;
while True:
    mask = 0b1110_1000
    pattern = 0b0000_1000
    a = ser.read()
    if (a == b'\xaa'):
        msb = ser.read(1)[0]
        lsb = ser.read(1)[0]
        word = (msb << 8 | lsb)
        if (word & mask) == pattern:
            print(f"New data: {word:#06x} \n")
            count = 0
        else:
            count += 1
            print(f"{count} - {word:#06x} \n")
